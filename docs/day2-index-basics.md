# Day 2: インデックスの基本

## 目標
- インデックスの仕組みを理解する
- 適切なインデックスを設計できる
- インデックスの効果を測定できる

## 1. インデックスの基礎知識

### インデックスなしでの検索
```sql
-- 実行時間を測定
SET profiling = 1;

-- インデックスなしで検索
SELECT * FROM users WHERE email = 'user500000@example.com';

-- 実行時間確認
SHOW PROFILES;
```

### インデックス作成と効果測定
```sql
-- インデックス作成
CREATE INDEX idx_users_email ON users(email);

-- 同じクエリを再実行
SELECT * FROM users WHERE email = 'user500000@example.com';

-- 実行時間を比較
SHOW PROFILES;

-- インデックス使用状況確認
SHOW INDEX FROM users;
```

## 2. インデックスの種類

### PRIMARY KEY
```sql
-- 自動的にインデックスが作成される
ALTER TABLE products ADD PRIMARY KEY (id);
```

### UNIQUE INDEX
```sql
-- 重複を許さないインデックス
CREATE UNIQUE INDEX idx_users_email_unique ON users(email);
```

### 複合インデックス
```sql
-- 複数カラムのインデックス（順序が重要）
CREATE INDEX idx_orders_user_status ON orders(user_id, status);

-- このインデックスが効く例
SELECT * FROM orders WHERE user_id = 1000;
SELECT * FROM orders WHERE user_id = 1000 AND status = 'completed';

-- このインデックスが効かない例
SELECT * FROM orders WHERE status = 'completed';  -- user_idがないため
```

## 3. インデックス設計の実践

### カーディナリティを考慮
```sql
-- カーディナリティ（値の種類）を確認
SELECT
    COUNT(DISTINCT status) as status_cardinality,
    COUNT(DISTINCT user_id) as user_id_cardinality,
    COUNT(*) as total_rows
FROM orders;

-- カーディナリティが高いカラムを先に
CREATE INDEX idx_orders_user_status_ordered
ON orders(user_id, status, ordered_at);
```

### カバリングインデックス
```sql
-- クエリに必要な全カラムをインデックスに含める
CREATE INDEX idx_orders_covering
ON orders(user_id, status, total_amount, ordered_at);

-- インデックスのみで結果を返せる（高速）
SELECT user_id, status, total_amount
FROM orders
WHERE user_id = 1000 AND status = 'completed';
```

## 4. インデックスの効果測定

### EXPLAIN使用前
```sql
-- インデックスなしの実行計画
EXPLAIN SELECT * FROM orders WHERE total_amount > 10000;
```

### インデックス追加後
```sql
-- インデックス作成
CREATE INDEX idx_orders_total_amount ON orders(total_amount);

-- 再度EXPLAIN実行
EXPLAIN SELECT * FROM orders WHERE total_amount > 10000;
```

## 5. インデックスのメンテナンス

### 未使用インデックスの確認
```sql
-- インデックスの使用状況確認
SELECT
    table_name,
    index_name,
    stat_value as cardinality
FROM mysql.innodb_index_stats
WHERE database_name = 'training_db'
    AND stat_name = 'n_diff_pfx01'
ORDER BY table_name, index_name;
```

### インデックスの削除
```sql
-- 不要なインデックスを削除
DROP INDEX idx_orders_total_amount ON orders;
```

## 6. 実践演習

### 演習1: 適切なインデックスの選定
```sql
-- このクエリを高速化するインデックスを設計
SELECT
    u.name,
    COUNT(o.id) as order_count
FROM users u
INNER JOIN orders o ON u.id = o.user_id
WHERE o.ordered_at >= '2024-01-01'
    AND o.status = 'completed'
GROUP BY u.id;

-- 解答例
CREATE INDEX idx_orders_optimization
ON orders(status, ordered_at, user_id);
```

### 演習2: 複合インデックスの順序
```sql
-- 以下のクエリ群に最適な複合インデックスを設計
-- Query A: WHERE product_id = 100
-- Query B: WHERE product_id = 100 AND order_id = 200
-- Query C: WHERE order_id = 200

-- 解答例
-- Query A, Bには効く
CREATE INDEX idx_orderitems_product_order
ON order_items(product_id, order_id);

-- Query Cには別途必要
CREATE INDEX idx_orderitems_order
ON order_items(order_id);
```

## 確認課題
1. users テーブルの検索を高速化するインデックスを設計
2. 月次レポートクエリ用の最適なインデックスを作成
3. インデックス追加前後でのパフォーマンス差を測定