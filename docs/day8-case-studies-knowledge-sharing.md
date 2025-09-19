# Day 8: ケーススタディと知識共有

## 目標
- 実際の障害事例から学ぶ
- チューニングのベストプラクティスを共有
- 継続的な改善プロセスを構築

## 1. 実際の障害事例

### ケース1: 突然のレスポンス悪化
```sql
-- 症状：朝9時になると急激に遅くなる
-- 原因調査

-- 1. スロークエリの確認
SELECT
    DATE_FORMAT(start_time, '%H:00') as hour,
    COUNT(*) as slow_queries,
    AVG(query_time) as avg_time
FROM mysql.slow_log
WHERE DATE(start_time) = CURDATE()
GROUP BY hour
ORDER BY hour;

-- 2. 該当時間のクエリ特定
SELECT
    sql_text,
    COUNT(*) as exec_count,
    AVG(query_time) as avg_time
FROM mysql.slow_log
WHERE DATE_FORMAT(start_time, '%H') = '09'
GROUP BY sql_text
ORDER BY exec_count * avg_time DESC;

-- 原因：バッチ処理との競合
-- 解決策：
-- 1. バッチ処理の時間変更
-- 2. リードレプリカへの分散
-- 3. インデックス追加で高速化
```

### ケース2: テーブルロックによる詰まり
```sql
-- 症状：特定の処理で全体が止まる
-- 調査方法

-- 1. 現在のロック状況確認
SHOW PROCESSLIST;

-- 2. InnoDBのロック情報
SELECT * FROM information_schema.innodb_locks;
SELECT * FROM information_schema.innodb_lock_waits;

-- 3. デッドロックの履歴
SHOW ENGINE INNODB STATUS\G

-- 原因：長時間トランザクション
-- 解決策：
-- 1. トランザクションの細分化
-- 2. SELECT ... FOR UPDATE の見直し
-- 3. 適切なアイソレーションレベル設定
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

## 2. チューニングのベストプラクティス

### 定期メンテナンス
```sql
-- 1. 統計情報の更新
ANALYZE TABLE users, products, orders, order_items;

-- 2. インデックスの再構築（断片化解消）
ALTER TABLE orders ENGINE=InnoDB;

-- 3. 不要データのアーカイブ
-- 古いデータを別テーブルへ移動
CREATE TABLE orders_archive LIKE orders;

INSERT INTO orders_archive
SELECT * FROM orders
WHERE ordered_at < DATE_SUB(NOW(), INTERVAL 2 YEAR);

DELETE FROM orders
WHERE ordered_at < DATE_SUB(NOW(), INTERVAL 2 YEAR);
```

### モニタリング設定
```sql
-- 重要メトリクスの監視
CREATE VIEW monitoring_metrics AS
SELECT
    'Slow Queries (1h)' as metric,
    COUNT(*) as value
FROM mysql.slow_log
WHERE start_time > DATE_SUB(NOW(), INTERVAL 1 HOUR)
UNION ALL
SELECT
    'Avg Query Time (1h)',
    AVG(query_time)
FROM mysql.slow_log
WHERE start_time > DATE_SUB(NOW(), INTERVAL 1 HOUR)
UNION ALL
SELECT
    'Table Lock Waits',
    SUM(count_star)
FROM performance_schema.table_lock_waits_summary_by_table
UNION ALL
SELECT
    'Buffer Pool Hit Rate',
    (1 - (Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests)) * 100
FROM (
    SELECT
        MAX(CASE WHEN variable_name = 'Innodb_buffer_pool_reads'
            THEN variable_value END) as Innodb_buffer_pool_reads,
        MAX(CASE WHEN variable_name = 'Innodb_buffer_pool_read_requests'
            THEN variable_value END) as Innodb_buffer_pool_read_requests
    FROM information_schema.global_status
) as t;
```

## 3. チェックリストとドキュメント

### 日次チェックリスト
```markdown
## 日次パフォーマンスチェック

### 1. スロークエリの確認
- [ ] 過去24時間のスロークエリ数確認
- [ ] 新規に発生した遅いクエリの特定
- [ ] TOP5の重いクエリの改善検討

### 2. システムリソース
- [ ] CPU使用率の確認（閾値：70%）
- [ ] メモリ使用率の確認（閾値：80%）
- [ ] ディスクI/Oの確認

### 3. インデックス効率
- [ ] 未使用インデックスの確認
- [ ] フルテーブルスキャンの発生確認
```

### トラブルシューティングガイド
```markdown
## クエリが遅い時の対処法

### 1. 原因特定
1. EXPLAIN実行
2. スロークエリログ確認
3. プロファイリング実行

### 2. 一般的な解決策
- インデックス追加
- クエリ書き換え
- データ量削減（古いデータのアーカイブ）
- キャッシュ活用

### 3. エスカレーション基準
- 5秒以上かかるクエリ
- CPU使用率90%以上が継続
- ユーザーからのクレーム発生
```

## 4. 継続的改善プロセス

### 週次レビュー会のアジェンダ
```sql
-- 1. 先週のパフォーマンス総括
SELECT
    DATE(start_time) as date,
    COUNT(*) as slow_queries,
    AVG(query_time) as avg_time,
    MAX(query_time) as max_time
FROM mysql.slow_log
WHERE start_time >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY DATE(start_time)
ORDER BY date DESC;

-- 2. 改善効果の測定
-- 改善施策リストと効果測定

-- 3. 新規課題の共有
-- 各メンバーが遭遇した問題と解決策

-- 4. 次週のアクションアイテム
-- 優先度の高い改善項目の決定
```

## 5. 学習リソース

### 推奨書籍・資料
- MySQL公式ドキュメント
- High Performance MySQL
- パフォーマンスチューニングのブログ記事

### 社内ナレッジベース構築
```sql
-- チューニング履歴テーブル
CREATE TABLE tuning_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    problem_description TEXT,
    root_cause TEXT,
    solution TEXT,
    before_performance VARCHAR(100),
    after_performance VARCHAR(100),
    implemented_date DATE,
    implemented_by VARCHAR(100),
    tags VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 事例の記録
INSERT INTO tuning_history
(problem_description, root_cause, solution, before_performance, after_performance, implemented_date, implemented_by, tags)
VALUES
('月次レポートが30秒以上かかる',
 '相関サブクエリとインデックス不足',
 'CTEへの書き換えと複合インデックス追加',
 '35秒',
 '2秒',
 '2024-01-20',
 'エンジニアA',
 'report,subquery,index');
```

## 6. 最終演習：総合問題

### 実践的なシナリオ
```sql
-- ECサイトのダッシュボード表示が遅い
-- 要件：
-- 1. リアルタイム売上
-- 2. 人気商品TOP10
-- 3. 在庫警告
-- 4. 新規ユーザー数
-- すべてを1秒以内に表示

-- 現状の遅いクエリ（10秒以上）
SELECT
    -- リアルタイム売上
    (SELECT SUM(total_amount)
     FROM orders
     WHERE DATE(ordered_at) = CURDATE()
       AND status = 'completed') as today_revenue,

    -- 人気商品
    (SELECT GROUP_CONCAT(
        CONCAT(p.name, ':', sold_count)
        ORDER BY sold_count DESC
        SEPARATOR ', '
     )
     FROM (
        SELECT product_id, SUM(quantity) as sold_count
        FROM order_items oi
        INNER JOIN orders o ON oi.order_id = o.id
        WHERE o.ordered_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY product_id
        ORDER BY sold_count DESC
        LIMIT 10
     ) t
     INNER JOIN products p ON t.product_id = p.id
    ) as top_products,

    -- 在庫警告
    (SELECT COUNT(*)
     FROM products
     WHERE stock_quantity < 10
       AND stock_quantity > 0) as low_stock_count,

    -- 新規ユーザー
    (SELECT COUNT(*)
     FROM users
     WHERE DATE(created_at) = CURDATE()) as new_users;

-- 改善案の実装
-- ヒント：
-- 1. マテリアライズドビューの活用
-- 2. 非正規化テーブルの作成
-- 3. RedisなどのキャッシュLayerの検討
-- 4. 集計の事前計算
```

## 7. 卒業課題

### 実務適用プラン作成
```markdown
## 自社システムへの適用計画

### 1. 現状分析（1週間）
- スロークエリTOP20の特定
- 主要テーブルのインデックス調査
- ピーク時のパフォーマンス測定

### 2. 改善計画（2週間）
- 優先度順の改善リスト作成
- 各改善の想定効果算出
- リスク評価とロールバックプラン

### 3. 実装とテスト（3週間）
- 開発環境での改善実施
- パフォーマンステスト
- 本番適用と効果測定

### 4. 定着化（継続）
- 監視体制の構築
- 定期レビューの実施
- ナレッジの蓄積と共有
```