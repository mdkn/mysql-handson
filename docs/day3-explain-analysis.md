# Day 3: EXPLAINの読み方

## 目標
- EXPLAIN出力の各項目を理解する
- 実行計画から問題を発見できる
- クエリの改善ポイントを特定できる

## 1. EXPLAINの基本

### 基本的な使い方
```sql
-- 通常のEXPLAIN
EXPLAIN SELECT * FROM users WHERE id = 1000;

-- JSON形式で詳細表示
EXPLAIN FORMAT=JSON SELECT * FROM users WHERE id = 1000;

-- 実際に実行して統計情報も表示（MySQL 8.0.18以降）
EXPLAIN ANALYZE SELECT * FROM users WHERE id = 1000;
```

## 2. EXPLAIN出力の見方

### 主要なカラムの意味
```sql
EXPLAIN SELECT u.name, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at >= '2024-01-01'
GROUP BY u.id;
```

**出力項目の解説：**
- `id`: SELECTの識別子
- `select_type`: クエリのタイプ（SIMPLE, PRIMARY, SUBQUERY等）
- `table`: アクセスするテーブル
- `type`: アクセスタイプ（後述）
- `possible_keys`: 使用可能なインデックス
- `key`: 実際に使用されたインデックス
- `key_len`: 使用されたインデックスの長さ
- `ref`: インデックスと比較される値
- `rows`: 調査される行数の見積もり
- `filtered`: WHERE条件でフィルタされる割合
- `Extra`: 追加情報

## 3. typeカラムの重要性

性能順（良い→悪い）：

### system / const
```sql
-- PRIMARY KEYまたはUNIQUE INDEXでの検索
EXPLAIN SELECT * FROM users WHERE id = 1000;
-- type: const
```

### eq_ref
```sql
-- JOINで一意な行を取得
EXPLAIN SELECT * FROM orders o
INNER JOIN users u ON o.user_id = u.id
WHERE o.id = 1000;
-- type: eq_ref (usersテーブル)
```

### ref
```sql
-- インデックスを使った検索
EXPLAIN SELECT * FROM orders WHERE user_id = 1000;
-- type: ref
```

### range
```sql
-- インデックスを使った範囲検索
EXPLAIN SELECT * FROM orders
WHERE ordered_at BETWEEN '2024-01-01' AND '2024-12-31';
-- type: range
```

### index
```sql
-- インデックスのフルスキャン
EXPLAIN SELECT user_id FROM orders;
-- type: index
```

### ALL
```sql
-- テーブルのフルスキャン（最も遅い）
EXPLAIN SELECT * FROM orders WHERE total_amount > 1000;
-- type: ALL（インデックスがない場合）
```

## 4. Extra カラムの警告サイン

### Using filesort（要注意）
```sql
-- ソートにインデックスが使えない
EXPLAIN SELECT * FROM orders
ORDER BY total_amount DESC;
-- Extra: Using filesort
```

### Using temporary（要注意）
```sql
-- 一時テーブルが必要
EXPLAIN SELECT status, COUNT(*)
FROM orders
GROUP BY status;
-- Extra: Using temporary
```

### Using index（良い）
```sql
-- カバリングインデックスが使われている
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
EXPLAIN SELECT user_id, status FROM orders WHERE user_id = 1000;
-- Extra: Using index
```

## 5. 実践的な分析

### 悪いクエリの例
```sql
EXPLAIN SELECT
    u.name,
    p.name as product_name,
    SUM(oi.quantity) as total_quantity
FROM users u
CROSS JOIN products p
LEFT JOIN orders o ON u.id = o.user_id
LEFT JOIN order_items oi ON o.id = oi.order_id AND oi.product_id = p.id
GROUP BY u.id, p.id
HAVING total_quantity > 0;
```

**問題点：**
- CROSS JOINによる大量の組み合わせ
- type: ALLのテーブルが複数
- Using temporary; Using filesort

### 改善後のクエリ
```sql
EXPLAIN SELECT
    u.name,
    p.name as product_name,
    SUM(oi.quantity) as total_quantity
FROM order_items oi
INNER JOIN orders o ON oi.order_id = o.id
INNER JOIN users u ON o.user_id = u.id
INNER JOIN products p ON oi.product_id = p.id
GROUP BY u.id, p.id;
```

## 6. EXPLAIN ANALYZEの活用

```sql
-- 実際の実行時間も含めて分析（MySQL 8.0.18以降）
EXPLAIN ANALYZE
SELECT
    DATE_FORMAT(ordered_at, '%Y-%m') as month,
    COUNT(*) as order_count,
    SUM(total_amount) as revenue
FROM orders
WHERE status = 'completed'
    AND ordered_at >= '2024-01-01'
GROUP BY month;
```

## 7. 実践演習

### 演習1: 実行計画の改善
```sql
-- 以下のクエリの問題点を特定し、改善案を提示
EXPLAIN SELECT DISTINCT
    u.name,
    (SELECT COUNT(*) FROM orders WHERE user_id = u.id) as order_count,
    (SELECT SUM(total_amount) FROM orders WHERE user_id = u.id) as total_spent
FROM users u
WHERE u.created_at >= '2024-01-01';

-- 改善案
EXPLAIN SELECT
    u.name,
    COUNT(o.id) as order_count,
    SUM(o.total_amount) as total_spent
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at >= '2024-01-01'
GROUP BY u.id;
```

## 確認課題
1. 自社の遅いクエリをEXPLAINで分析
2. type: ALLになっているテーブルを特定
3. Using filesort/temporaryを解消する方法を検討