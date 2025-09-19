# 付録：よく使うコマンドリファレンス

## システム変数の確認
```sql
-- 重要な設定値
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
SHOW VARIABLES LIKE 'max_connections';
SHOW VARIABLES LIKE 'query_cache_%';
SHOW VARIABLES LIKE 'slow_query%';
```

## ステータス確認
```sql
-- 実行統計
SHOW GLOBAL STATUS LIKE 'Threads_connected';
SHOW GLOBAL STATUS LIKE 'Questions';
SHOW GLOBAL STATUS LIKE 'Slow_queries';
SHOW GLOBAL STATUS LIKE 'Table_locks_waited';
```

## プロセス管理
```sql
-- 実行中のクエリ確認
SHOW FULL PROCESSLIST;

-- 特定のクエリを強制終了
KILL [process_id];
```

## バックアップとリストア
```bash
# バックアップ
mysqldump -u root -p training_db > backup.sql

# リストア
mysql -u root -p training_db < backup.sql

# 特定テーブルのみ
mysqldump -u root -p training_db users orders > partial_backup.sql
```