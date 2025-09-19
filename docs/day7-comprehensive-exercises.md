# Day 7: 総合演習

## 目標
- 実務で遭遇する問題を自力で解決できる
- 分析から改善まで一連の流れを実践できる
- チューニングの効果を定量的に評価できる

## 演習1: 月次レポート生成の高速化

### 問題のクエリ
```sql
-- 実行に30秒かかる月次レポートクエリ
SELECT
    DATE_FORMAT(o.ordered_at, '%Y-%m') as month,
    u.name as user_name,
    p.name as product_name,
    c.name as category_name,
    oi.quantity,
    oi.price,
    o.total_amount,
    (SELECT COUNT(*)
     FROM orders
     WHERE user_id = u.id
       AND DATE_FORMAT(ordered_at, '%Y-%m') = DATE_FORMAT(o.ordered_at, '%Y-%m')
    ) as user_monthly_orders,
    (SELECT SUM(total_amount)
     FROM orders
     WHERE user_id = u.id
       AND DATE_FORMAT(ordered_at, '%Y-%m') = DATE_FORMAT(o.ordered_at, '%Y-%m')
    ) as user_monthly_total
FROM orders o
INNER JOIN users u ON o.user_id = u.id
INNER JOIN order_items oi ON o.id = oi.order_id
INNER JOIN products p ON oi.product_id = p.id
INNER JOIN categories c ON p.category_id = c.id
WHERE o.ordered_at >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
  AND o.status = 'completed'
ORDER BY o.ordered_at DESC, u.name;
```

### ステップ1: 問題分析
```sql
-- EXPLAINで実行計画確認
EXPLAIN [上記クエリ];

-- 問題点の特定
-- 1. 相関サブクエリが各行で実行
-- 2. DATE_FORMAT関数でインデックスが効かない
-- 3. 大量のJOIN
```

### ステップ2: 改善案実装
```sql
-- 改善版クエリ
WITH monthly_user_stats AS (
    SELECT
        user_id,
        DATE_FORMAT(ordered_at, '%Y-%m') as month,
        COUNT(*) as monthly_orders,
        SUM(total_amount) as monthly_total
    FROM orders
    WHERE ordered_at >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
      AND status = 'completed'
    GROUP BY user_id, month
)
SELECT
    DATE_FORMAT(o.ordered_at, '%Y-%m') as month,
    u.name as user_name,
    p.name as product_name,
    c.name as category_name,
    oi.quantity,
    oi.price,
    o.total_amount,
    mus.monthly_orders as user_monthly_orders,
    mus.monthly_total as user_monthly_total
FROM orders o
INNER JOIN users u ON o.user_id = u.id
INNER JOIN order_items oi ON o.id = oi.order_id
INNER JOIN products p ON oi.product_id = p.id
INNER JOIN categories c ON p.category_id = c.id
LEFT JOIN monthly_user_stats mus
    ON mus.user_id = u.id
    AND mus.month = DATE_FORMAT(o.ordered_at, '%Y-%m')
WHERE o.ordered_at >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
  AND o.status = 'completed'
ORDER BY o.ordered_at DESC, u.name;

-- 必要なインデックス
CREATE INDEX idx_orders_report
ON orders(status, ordered_at, user_id, total_amount);
```

## 演習2: 商品検索の最適化

### 問題のクエリ
```sql
-- 商品検索が遅い（5秒以上）
SELECT DISTINCT
    p.*,
    c.name as category_name,
    (SELECT COUNT(*) FROM order_items WHERE product_id = p.id) as sold_count,
    (SELECT AVG(oi.price) FROM order_items oi WHERE oi.product_id = p.id) as avg_sold_price,
    CASE
        WHEN p.stock_quantity = 0 THEN 'out_of_stock'
        WHEN p.stock_quantity < 10 THEN 'low_stock'
        ELSE 'in_stock'
    END as stock_status
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
WHERE (p.name LIKE '%search_term%' OR c.name LIKE '%search_term%')
  AND p.price BETWEEN 100 AND 10000
ORDER BY sold_count DESC, p.created_at DESC
LIMIT 50;
```

### 改善実装
```sql
-- ステップ1: 売上統計を事前集計
CREATE TABLE product_stats (
    product_id INT PRIMARY KEY,
    sold_count INT DEFAULT 0,
    avg_sold_price DECIMAL(10,2),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_sold_count (sold_count DESC)
);

-- 統計データの更新（定期実行）
INSERT INTO product_stats (product_id, sold_count, avg_sold_price)
SELECT
    product_id,
    COUNT(*) as sold_count,
    AVG(price) as avg_sold_price
FROM order_items
GROUP BY product_id
ON DUPLICATE KEY UPDATE
    sold_count = VALUES(sold_count),
    avg_sold_price = VALUES(avg_sold_price);

-- ステップ2: 検索クエリの改善
SELECT
    p.*,
    c.name as category_name,
    COALESCE(ps.sold_count, 0) as sold_count,
    ps.avg_sold_price,
    CASE
        WHEN p.stock_quantity = 0 THEN 'out_of_stock'
        WHEN p.stock_quantity < 10 THEN 'low_stock'
        ELSE 'in_stock'
    END as stock_status
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN product_stats ps ON p.id = ps.product_id
WHERE p.price BETWEEN 100 AND 10000
  AND (p.name LIKE '%search_term%' OR c.name LIKE '%search_term%')
ORDER BY ps.sold_count DESC, p.created_at DESC
LIMIT 50;

-- 全文検索インデックスの活用
ALTER TABLE products ADD FULLTEXT(name);
ALTER TABLE categories ADD FULLTEXT(name);

-- MATCH AGAINSTを使った検索
SELECT
    p.*,
    c.name as category_name,
    COALESCE(ps.sold_count, 0) as sold_count,
    ps.avg_sold_price
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN product_stats ps ON p.id = ps.product_id
WHERE p.price BETWEEN 100 AND 10000
  AND (MATCH(p.name) AGAINST('search_term' IN BOOLEAN MODE)
       OR MATCH(c.name) AGAINST('search_term' IN BOOLEAN MODE))
ORDER BY ps.sold_count DESC
LIMIT 50;
```

## 演習3: 管理画面の一覧表示

### 問題のクエリ
```sql
-- 管理画面の注文一覧（ページングで遅い）
SELECT
    o.*,
    u.name as user_name,
    u.email as user_email,
    COUNT(oi.id) as item_count,
    GROUP_CONCAT(p.name) as product_names
FROM orders o
INNER JOIN users u ON o.user_id = u.id
LEFT JOIN order_items oi ON o.id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.id
GROUP BY o.id
ORDER BY o.ordered_at DESC
LIMIT 50 OFFSET 10000;  -- 深いページで特に遅い
```

### 改善実装
```sql
-- ステップ1: カーソルベースのページネーション
SELECT
    o.*,
    u.name as user_name,
    u.email as user_email
FROM orders o
INNER JOIN users u ON o.user_id = u.id
WHERE o.ordered_at < '2024-01-15 10:00:00'  -- 前ページの最後の値
ORDER BY o.ordered_at DESC
LIMIT 50;

-- ステップ2: 詳細情報は別クエリで取得
SELECT
    oi.order_id,
    COUNT(oi.id) as item_count,
    GROUP_CONCAT(p.name) as product_names
FROM order_items oi
INNER JOIN products p ON oi.product_id = p.id
WHERE oi.order_id IN (/* 上記で取得したorder_id */)
GROUP BY oi.order_id;

-- ステップ3: 複合インデックスの作成
CREATE INDEX idx_orders_list
ON orders(ordered_at DESC, user_id);

CREATE INDEX idx_orderitems_summary
ON order_items(order_id, product_id);
```

## パフォーマンス測定

### 改善効果の定量評価
```sql
-- クエリ実行時間の測定
SET profiling = 1;

-- 改善前のクエリ実行
[改善前のクエリ];

-- 改善後のクエリ実行
[改善後のクエリ];

-- 結果比較
SHOW PROFILES;

-- 詳細な実行統計
SELECT
    query_id,
    state,
    duration,
    cpu_user,
    cpu_system
FROM information_schema.profiling
WHERE query_id IN (1, 2)
ORDER BY query_id, seq;
```

## 確認課題
1. 各演習の改善前後で実行時間を比較
2. EXPLAINの変化を記録
3. さらなる改善案を検討