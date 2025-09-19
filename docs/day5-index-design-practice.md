# Day 5: インデックス設計の実践

## 目標
- 実際のクエリパターンに基づいてインデックスを設計できる
- インデックスの効果を定量的に評価できる
- インデックスのトレードオフを理解する

## 1. インデックス戦略の立案

### クエリパターンの分析
```sql
-- アプリケーションで頻繁に使用されるクエリを収集
-- 例：ECサイトの主要機能

-- 1. 商品検索
SELECT * FROM products
WHERE category_id = ?
  AND price BETWEEN ? AND ?
  AND stock_quantity > 0
ORDER BY created_at DESC;

-- 2. ユーザーの注文履歴
SELECT * FROM orders
WHERE user_id = ?
  AND status IN ('completed', 'processing')
ORDER BY ordered_at DESC
LIMIT 20;

-- 3. 売上集計
SELECT
    DATE(ordered_at) as date,
    COUNT(*) as order_count,
    SUM(total_amount) as revenue
FROM orders
WHERE ordered_at BETWEEN ? AND ?
  AND status = 'completed'
GROUP BY DATE(ordered_at);
```

### 最適なインデックス設計
```sql
-- 1. 商品検索用インデックス
CREATE INDEX idx_products_search
ON products(category_id, stock_quantity, price, created_at);

-- 2. 注文履歴用インデックス
CREATE INDEX idx_orders_user_history
ON orders(user_id, status, ordered_at DESC);

-- 3. 売上集計用インデックス
CREATE INDEX idx_orders_reporting
ON orders(status, ordered_at, total_amount);
```

## 2. カーディナリティの重要性

```sql
-- カーディナリティ（選択性）の確認
SELECT
    'status' as column_name,
    COUNT(DISTINCT status) as distinct_values,
    COUNT(*) as total_rows,
    COUNT(DISTINCT status) / COUNT(*) * 100 as selectivity_percent
FROM orders
UNION ALL
SELECT
    'user_id',
    COUNT(DISTINCT user_id),
    COUNT(*),
    COUNT(DISTINCT user_id) / COUNT(*) * 100
FROM orders
UNION ALL
SELECT
    'ordered_at',
    COUNT(DISTINCT DATE(ordered_at)),
    COUNT(*),
    COUNT(DISTINCT DATE(ordered_at)) / COUNT(*) * 100
FROM orders;

-- 選択性が高い順にインデックスを構成
CREATE INDEX idx_orders_optimized
ON orders(user_id, ordered_at, status);  -- 高→低の順
```

## 3. カバリングインデックスの設計

```sql
-- 頻繁に実行される参照クエリ
SELECT user_id, status, total_amount
FROM orders
WHERE user_id = 12345
  AND status = 'completed';

-- カバリングインデックス（クエリに必要な全カラムを含む）
CREATE INDEX idx_orders_covering
ON orders(user_id, status, total_amount);

-- 効果確認
EXPLAIN SELECT user_id, status, total_amount
FROM orders
WHERE user_id = 12345
  AND status = 'completed';
-- Extra: Using index （テーブルアクセス不要）
```

## 4. インデックスのコスト

### 書き込みパフォーマンスへの影響測定
```sql
-- インデックスなしでの挿入時間測定
DROP INDEX idx_orders_user_history ON orders;
DROP INDEX idx_orders_reporting ON orders;

SET @start = NOW(6);
INSERT INTO orders (user_id, total_amount, status)
SELECT
    FLOOR(1 + RAND() * 1000000),
    ROUND(RAND() * 10000, 2),
    ELT(FLOOR(1 + RAND() * 3), 'pending', 'completed', 'cancelled')
FROM orders
LIMIT 10000;
SET @end = NOW(6);
SELECT TIMEDIFF(@end, @start) as insert_time_no_index;

-- インデックスありでの挿入時間測定
CREATE INDEX idx_orders_user_history ON orders(user_id, status, ordered_at);
CREATE INDEX idx_orders_reporting ON orders(status, ordered_at, total_amount);

SET @start = NOW(6);
INSERT INTO orders (user_id, total_amount, status)
SELECT
    FLOOR(1 + RAND() * 1000000),
    ROUND(RAND() * 10000, 2),
    ELT(FLOOR(1 + RAND() * 3), 'pending', 'completed', 'cancelled')
FROM orders
LIMIT 10000;
SET @end = NOW(6);
SELECT TIMEDIFF(@end, @start) as insert_time_with_index;
```

## 5. インデックスの監視と最適化

### 未使用インデックスの特定
```sql
-- インデックスの使用統計
SELECT
    object_schema,
    object_name,
    index_name,
    count_read,
    count_write,
    count_fetch,
    count_insert,
    count_update,
    count_delete
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE object_schema = 'training_db'
  AND index_name IS NOT NULL
ORDER BY count_read DESC;
```

### インデックスの断片化確認
```sql
-- インデックス統計の更新
ANALYZE TABLE orders;
ANALYZE TABLE order_items;
ANALYZE TABLE products;
ANALYZE TABLE users;

-- 断片化の確認（InnoDBの場合）
SELECT
    table_name,
    data_length / 1024 / 1024 as data_size_mb,
    index_length / 1024 / 1024 as index_size_mb,
    data_free / 1024 / 1024 as free_space_mb,
    (data_free / (data_length + index_length)) * 100 as fragmentation_percent
FROM information_schema.tables
WHERE table_schema = 'training_db'
  AND engine = 'InnoDB'
ORDER BY fragmentation_percent DESC;
```

## 6. 実践演習：複雑なインデックス設計

### 演習1: 複合条件の最適化
```sql
-- 以下のクエリ群に最適なインデックスを設計

-- Query A: カテゴリ別の在庫あり商品
SELECT * FROM products
WHERE category_id = 5 AND stock_quantity > 0;

-- Query B: 価格範囲検索
SELECT * FROM products
WHERE price BETWEEN 1000 AND 5000;

-- Query C: カテゴリ＋価格範囲＋在庫
SELECT * FROM products
WHERE category_id = 5
  AND price BETWEEN 1000 AND 5000
  AND stock_quantity > 0;

-- 解答例：
-- 複合インデックスで全てカバー
CREATE INDEX idx_products_composite
ON products(category_id, stock_quantity, price);

-- Query B用に追加
CREATE INDEX idx_products_price ON products(price);
```

### 演習2: JOINの最適化
```sql
-- 以下のJOINクエリを最適化

SELECT
    u.name,
    u.email,
    o.id as order_id,
    o.total_amount,
    oi.quantity,
    p.name as product_name
FROM users u
INNER JOIN orders o ON u.id = o.user_id
INNER JOIN order_items oi ON o.id = oi.order_id
INNER JOIN products p ON oi.product_id = p.id
WHERE u.created_at >= '2024-01-01'
  AND o.status = 'completed'
  AND p.category_id = 10;

-- 解答例：
CREATE INDEX idx_users_created ON users(created_at);
CREATE INDEX idx_orders_join ON orders(user_id, status);
CREATE INDEX idx_orderitems_join ON order_items(order_id, product_id);
CREATE INDEX idx_products_category ON products(category_id);
```

## 確認課題
1. 自社の主要なクエリパターンを5つ特定
2. 各クエリに最適なインデックスを設計
3. インデックス追加前後でパフォーマンスを比較