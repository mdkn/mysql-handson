# Day 6: クエリ最適化のパターン

## 目標
- よくあるアンチパターンを認識できる
- クエリの書き換えによる最適化ができる
- 状況に応じた最適な手法を選択できる

## 1. サブクエリ vs JOIN

### 相関サブクエリ（遅い）
```sql
-- 各ユーザーの最新注文を取得（N+1問題）
SELECT
    u.id,
    u.name,
    (SELECT MAX(ordered_at)
     FROM orders o
     WHERE o.user_id = u.id) as last_order_date,
    (SELECT COUNT(*)
     FROM orders o
     WHERE o.user_id = u.id) as total_orders
FROM users u
WHERE u.created_at >= '2024-01-01';

-- 実行計画確認
EXPLAIN [上記クエリ];
```

### JOINに書き換え（速い）
```sql
-- GROUP BYとJOINで最適化
SELECT
    u.id,
    u.name,
    MAX(o.ordered_at) as last_order_date,
    COUNT(o.id) as total_orders
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at >= '2024-01-01'
GROUP BY u.id;

-- 実行計画比較
EXPLAIN [上記クエリ];
```

## 2. EXISTS vs IN

### IN句（リストが大きい場合は遅い）
```sql
-- 注文のあるユーザー
SELECT * FROM users
WHERE id IN (
    SELECT DISTINCT user_id
    FROM orders
    WHERE status = 'completed'
);
```

### EXISTS（一般的に高速）
```sql
-- EXISTSで書き換え
SELECT * FROM users u
WHERE EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.user_id = u.id
      AND o.status = 'completed'
);
```

### セミジョイン（MySQL 5.6以降で最適化）
```sql
-- JOINで書き換え
SELECT DISTINCT u.*
FROM users u
INNER JOIN orders o ON u.id = o.user_id
WHERE o.status = 'completed';
```

## 3. ページネーションの最適化

### OFFSET/LIMIT（ページが深くなると遅い）
```sql
-- 10万件目からのデータ取得（遅い）
SELECT * FROM orders
ORDER BY id
LIMIT 20 OFFSET 100000;

-- 実行時間測定
SET @start = NOW(6);
[上記クエリ];
SET @end = NOW(6);
SELECT TIMEDIFF(@end, @start);
```

### シークメソッド（高速）
```sql
-- 前ページの最後のIDを使用
SELECT * FROM orders
WHERE id > 100000  -- 前ページの最後のID
ORDER BY id
LIMIT 20;
```

### キー付きページネーション
```sql
-- 複合条件でのページネーション
SELECT * FROM orders
WHERE (ordered_at, id) > ('2024-01-15', 100000)
ORDER BY ordered_at, id
LIMIT 20;
```

## 4. GROUP BY の最適化

### 非効率なGROUP BY
```sql
-- 全カラムを取得してからグループ化（遅い）
SELECT
    category_id,
    COUNT(*) as product_count,
    AVG(price) as avg_price
FROM (
    SELECT * FROM products
    WHERE stock_quantity > 0
) as t
GROUP BY category_id;
```

### 効率的なGROUP BY
```sql
-- 必要なカラムのみ選択（速い）
SELECT
    category_id,
    COUNT(*) as product_count,
    AVG(price) as avg_price
FROM products
WHERE stock_quantity > 0
GROUP BY category_id;

-- インデックスも活用
CREATE INDEX idx_products_groupby
ON products(category_id, stock_quantity, price);
```

## 5. UNION vs UNION ALL

### UNION（重複除去あり、遅い）
```sql
SELECT user_id FROM orders WHERE status = 'pending'
UNION
SELECT user_id FROM orders WHERE status = 'processing';
```

### UNION ALL（重複許可、速い）
```sql
-- 重複を気にしない場合
SELECT user_id FROM orders WHERE status = 'pending'
UNION ALL
SELECT user_id FROM orders WHERE status = 'processing';

-- または IN句で書き換え
SELECT user_id FROM orders
WHERE status IN ('pending', 'processing');
```

## 6. 集計の最適化

### ウィンドウ関数の活用
```sql
-- 各ユーザーの累積購入額（古い方法）
SELECT
    o1.id,
    o1.user_id,
    o1.total_amount,
    (SELECT SUM(o2.total_amount)
     FROM orders o2
     WHERE o2.user_id = o1.user_id
       AND o2.ordered_at <= o1.ordered_at) as cumulative_amount
FROM orders o1
WHERE o1.user_id = 1000;

-- ウィンドウ関数使用（MySQL 8.0以降）
SELECT
    id,
    user_id,
    total_amount,
    SUM(total_amount) OVER (
        PARTITION BY user_id
        ORDER BY ordered_at
    ) as cumulative_amount
FROM orders
WHERE user_id = 1000;
```

## 7. バッチ処理の最適化

### 一括INSERT
```sql
-- 悪い例：1行ずつINSERT
INSERT INTO products (name, price) VALUES ('Product A', 100);
INSERT INTO products (name, price) VALUES ('Product B', 200);
INSERT INTO products (name, price) VALUES ('Product C', 300);

-- 良い例：複数行を一度にINSERT
INSERT INTO products (name, price) VALUES
    ('Product A', 100),
    ('Product B', 200),
    ('Product C', 300);
```

### 一括UPDATE
```sql
-- CASE文を使った一括UPDATE
UPDATE products
SET price = CASE id
    WHEN 1 THEN 110
    WHEN 2 THEN 220
    WHEN 3 THEN 330
    ELSE price
END
WHERE id IN (1, 2, 3);
```

## 8. 実践演習

### 演習1: 複雑な集計の最適化
```sql
-- 最適化前：カテゴリ別の売上ランキング
SELECT
    p.category_id,
    p.name,
    SUM(oi.quantity * oi.price) as revenue
FROM products p
INNER JOIN order_items oi ON p.id = oi.product_id
INNER JOIN orders o ON oi.order_id = o.id
WHERE o.status = 'completed'
  AND o.ordered_at >= '2024-01-01'
GROUP BY p.id
ORDER BY p.category_id, revenue DESC;

-- 最適化案を考える
-- ヒント：インデックス、サマリーテーブル、クエリ分割
```

### 演習2: N+1問題の解消
```sql
-- アプリケーション側で以下のようなループ処理
-- foreach ($users as $user) {
--     $orders = query("SELECT * FROM orders WHERE user_id = ?", $user->id);
-- }

-- 一括取得に書き換え
SELECT
    u.*,
    o.*
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.id IN (1, 2, 3, ...)
ORDER BY u.id, o.ordered_at DESC;
```

## 確認課題
1. 相関サブクエリを含むクエリをJOINに書き換え
2. OFFSET/LIMITのページネーションを最適化
3. GROUP BYクエリにインデックスを適用