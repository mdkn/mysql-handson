# Day 1: JOINの理解と実践

## 目標
- 各種JOINの違いを理解し、適切に使い分けられる
- 複数テーブルを結合した実務的なクエリが書ける

## 1. JOIN種類の理解

### INNER JOIN
```sql
-- ユーザーと注文を結合（注文のあるユーザーのみ）
SELECT
    u.id,
    u.name,
    COUNT(o.id) as order_count,
    SUM(o.total_amount) as total_spent
FROM users u
INNER JOIN orders o ON u.id = o.user_id
GROUP BY u.id
LIMIT 10;
```

### LEFT JOIN
```sql
-- 全ユーザーと注文を結合（注文がないユーザーも含む）
SELECT
    u.id,
    u.name,
    COUNT(o.id) as order_count,
    COALESCE(SUM(o.total_amount), 0) as total_spent
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id
HAVING order_count = 0
LIMIT 10;
```

### 複数テーブルのJOIN
```sql
-- ユーザー、注文、注文明細、商品を結合
SELECT
    u.name as user_name,
    o.id as order_id,
    o.ordered_at,
    p.name as product_name,
    oi.quantity,
    oi.price
FROM users u
INNER JOIN orders o ON u.id = o.user_id
INNER JOIN order_items oi ON o.id = oi.order_id
INNER JOIN products p ON oi.product_id = p.id
WHERE o.ordered_at >= '2024-01-01'
LIMIT 100;
```

## 2. パフォーマンスを意識したJOIN

### 悪い例：不要なJOIN
```sql
-- 全テーブルをJOINしてからフィルタ
SELECT COUNT(*)
FROM users u
INNER JOIN orders o ON u.id = o.user_id
INNER JOIN order_items oi ON o.id = oi.order_id
INNER JOIN products p ON oi.product_id = p.id
WHERE p.category_id = 5;
```

### 良い例：必要最小限のJOIN
```sql
-- 必要なテーブルのみJOIN
SELECT COUNT(*)
FROM order_items oi
INNER JOIN products p ON oi.product_id = p.id
WHERE p.category_id = 5;
```

## 3. 実践演習

### 演習1: 売上TOP10商品とその購入者
```sql
-- ステップ1: 売上TOP10商品を特定
WITH top_products AS (
    SELECT
        p.id,
        p.name,
        SUM(oi.quantity * oi.price) as revenue
    FROM products p
    INNER JOIN order_items oi ON p.id = oi.product_id
    GROUP BY p.id
    ORDER BY revenue DESC
    LIMIT 10
)
-- ステップ2: TOP10商品の購入者を取得
SELECT DISTINCT
    tp.name as product_name,
    tp.revenue,
    u.name as user_name,
    u.email
FROM top_products tp
INNER JOIN order_items oi ON tp.id = oi.product_id
INNER JOIN orders o ON oi.order_id = o.id
INNER JOIN users u ON o.user_id = u.id
ORDER BY tp.revenue DESC, u.name;
```

### 演習2: 月次売上レポート
```sql
SELECT
    DATE_FORMAT(o.ordered_at, '%Y-%m') as month,
    COUNT(DISTINCT o.user_id) as unique_customers,
    COUNT(o.id) as total_orders,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value
FROM orders o
WHERE o.status = 'completed'
    AND o.ordered_at >= DATE_SUB(NOW(), INTERVAL 12 MONTH)
GROUP BY month
ORDER BY month DESC;
```

## 4. JOINのアンチパターン

### N+1問題の例
```sql
-- 悪い例：アプリケーション側でループ処理
-- PHPなどで以下を繰り返す
SELECT * FROM users WHERE id = 1;
SELECT * FROM orders WHERE user_id = 1;
SELECT * FROM users WHERE id = 2;
SELECT * FROM orders WHERE user_id = 2;
-- ... 以下続く

-- 良い例：1回のクエリで取得
SELECT u.*, o.*
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.id IN (1, 2, 3, ...);
```

## 確認課題
1. 過去30日間で最も売れた商品TOP5を、カテゴリー名付きで取得
2. 一度も注文していないユーザー数をカウント
3. 各カテゴリーの売上合計を降順で表示