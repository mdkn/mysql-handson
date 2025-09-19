# Day 4: スロークエリログの活用

## 目標
- スロークエリログの設定と確認ができる
- ログから問題のあるクエリを特定できる
- 定期的な監視体制を構築できる

## 1. スロークエリログの設定

### 動的に設定変更
```sql
-- 現在の設定確認
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';

-- スロークエリログを有効化
SET GLOBAL slow_query_log = 1;
SET GLOBAL slow_query_log_file = '/var/log/mysql/slow.log';
SET GLOBAL long_query_time = 1;  -- 1秒以上のクエリを記録

-- インデックスを使わないクエリも記録
SET GLOBAL log_queries_not_using_indexes = 1;
```

### my.cnfでの永続的な設定
```ini
[mysqld]
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1
log_queries_not_using_indexes = 1
```

## 2. スロークエリの発生と確認

### テスト用の遅いクエリ実行
```sql
-- インデックスのないカラムで大量データを検索
SELECT * FROM orders
WHERE total_amount BETWEEN 10000 AND 20000
ORDER BY ordered_at DESC;

-- 非効率なJOIN
SELECT
    u.name,
    COUNT(DISTINCT o.id) as orders,
    COUNT(DISTINCT oi.id) as items
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
LEFT JOIN order_items oi ON o.id = oi.order_id
GROUP BY u.id;
```

### ログの確認
```bash
# Dockerコンテナ内でログ確認
docker exec -it mysql-training tail -f /var/log/mysql/slow.log

# またはホストから
docker exec -it mysql-training cat /var/log/mysql/slow.log
```

## 3. スロークエリログの読み方

```
# Time: 2024-01-15T10:30:45.123456Z
# User@Host: trainee[trainee] @ localhost []
# Query_time: 2.456789  Lock_time: 0.000123 Rows_sent: 100  Rows_examined: 500000
SET timestamp=1705316445;
SELECT u.name, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id;
```

**重要な項目：**
- `Query_time`: クエリの実行時間
- `Lock_time`: ロック待機時間
- `Rows_sent`: クライアントに送信された行数
- `Rows_examined`: 調査された行数（効率の指標）

## 4. mysqldumpslowによる集計

```bash
# スロークエリの集計
docker exec -it mysql-training mysqldumpslow -s t /var/log/mysql/slow.log

# オプション説明
# -s t: 合計時間でソート
# -s c: 実行回数でソート
# -s at: 平均実行時間でソート
# -t 10: TOP10のみ表示
```

## 5. パフォーマンススキーマの活用

```sql
-- パフォーマンススキーマ有効化確認
SHOW VARIABLES LIKE 'performance_schema';

-- 最も時間のかかったクエリTOP10
SELECT
    DIGEST_TEXT as query,
    COUNT_STAR as exec_count,
    SUM_TIMER_WAIT/1000000000000 as total_time_sec,
    AVG_TIMER_WAIT/1000000000000 as avg_time_sec,
    SUM_ROWS_EXAMINED as total_rows_examined,
    SUM_ROWS_SENT as total_rows_sent
FROM performance_schema.events_statements_summary_by_digest
ORDER BY total_time_sec DESC
LIMIT 10;
```

## 6. 実践的な分析フロー

### ステップ1: 定期的な確認
```sql
-- 日次でスロークエリ数を確認
SELECT
    DATE(query_time) as date,
    COUNT(*) as slow_query_count,
    AVG(query_time) as avg_query_time
FROM mysql.slow_log
WHERE query_time > 1
GROUP BY DATE(query_time)
ORDER BY date DESC;
```

### ステップ2: 問題クエリの特定
```bash
# 実行時間が長いクエリTOP5
docker exec -it mysql-training \
    mysqldumpslow -s t -t 5 /var/log/mysql/slow.log
```

### ステップ3: クエリの改善
```sql
-- 特定したクエリをEXPLAINで分析
EXPLAIN [問題のクエリ];

-- インデックス追加やクエリ書き換えで改善
```

## 7. 監視の自動化

### 簡易監視スクリプト
```bash
#!/bin/bash
# check_slow_queries.sh

THRESHOLD=10
COUNT=$(docker exec mysql-training \
    mysql -uroot -prootpassword -e \
    "SELECT COUNT(*) FROM mysql.slow_log \
     WHERE query_time > 1 AND command_type = 'Query' \
     AND start_time > DATE_SUB(NOW(), INTERVAL 1 HOUR)" \
    -s -N)

if [ $COUNT -gt $THRESHOLD ]; then
    echo "Alert: $COUNT slow queries in the last hour"
    # メール通知やSlack通知を追加
fi
```

## 8. 実践演習

### 演習1: スロークエリの改善
```sql
-- わざと遅いクエリを実行
SELECT
    p.name,
    p.price,
    (SELECT COUNT(*) FROM order_items WHERE product_id = p.id) as sold_count,
    (SELECT AVG(quantity) FROM order_items WHERE product_id = p.id) as avg_quantity
FROM products p
WHERE p.category_id IN (1,2,3,4,5)
ORDER BY sold_count DESC
LIMIT 100;

-- ログから特定して改善
-- 改善案：JOINとGROUP BYを使用
SELECT
    p.name,
    p.price,
    COUNT(oi.id) as sold_count,
    AVG(oi.quantity) as avg_quantity
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
WHERE p.category_id IN (1,2,3,4,5)
GROUP BY p.id
ORDER BY sold_count DESC
LIMIT 100;
```

## 確認課題
1. 過去24時間のスロークエリを集計
2. 最も頻繁に実行される遅いクエリを特定
3. Rows_examined / Rows_sent の比率が高いクエリを改善