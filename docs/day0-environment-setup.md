# Day 0: 環境構築

## 目標
- Docker環境でMySQLを構築
- サンプルデータベースと大量テストデータを準備

## 1. プロジェクトディレクトリ構造
```
mysql-training/
├── docker-compose.yml
├── init/
│   ├── 01_schema.sql
│   └── 02_test_data.sql
└── README.md
```

## 2. docker-compose.yml
```yaml
version: '3.8'
services:
  mysql:
    image: mysql:8.0
    container_name: mysql-training
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: training_db
      MYSQL_USER: trainee
      MYSQL_PASSWORD: traineepass
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./init:/docker-entrypoint-initdb.d
    command: >
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --slow_query_log=1
      --slow_query_log_file=/var/log/mysql/slow.log
      --long_query_time=1

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    container_name: phpmyadmin
    environment:
      PMA_HOST: mysql
      PMA_USER: root
      PMA_PASSWORD: rootpassword
    ports:
      - "8080:80"
    depends_on:
      - mysql

volumes:
  mysql_data:
```

## 3. 環境起動コマンド
```bash
# コンテナ起動
docker-compose up -d

# MySQL接続確認
docker exec -it mysql-training mysql -utrainee -ptraineepass training_db

# ログ確認
docker logs mysql-training

# phpMyAdmin アクセス
# http://localhost:8080
```

## 4. init/01_schema.sql
```sql
-- ECサイトのスキーマ定義
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE categories (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    parent_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES categories(id)
);

CREATE TABLE products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    category_id INT,
    stock_quantity INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

CREATE TABLE orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    ordered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE order_items (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);
```

## 5. init/02_test_data.sql
```sql
-- テストデータ生成プロシージャ
DELIMITER //

CREATE PROCEDURE generate_test_data()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE j INT DEFAULT 1;

    -- カテゴリーデータ（100件）
    WHILE i <= 100 DO
        INSERT INTO categories (name, parent_id)
        VALUES (CONCAT('Category ', i), NULL);
        SET i = i + 1;
    END WHILE;

    -- ユーザーデータ（100万件）
    SET i = 1;
    WHILE i <= 1000000 DO
        INSERT INTO users (email, name)
        VALUES (
            CONCAT('user', i, '@example.com'),
            CONCAT('User ', i)
        );

        -- 1000件ごとにコミット
        IF i % 1000 = 0 THEN
            COMMIT;
        END IF;

        SET i = i + 1;
    END WHILE;

    -- 商品データ（1万件）
    SET i = 1;
    WHILE i <= 10000 DO
        INSERT INTO products (name, price, category_id, stock_quantity)
        VALUES (
            CONCAT('Product ', i),
            ROUND(RAND() * 10000, 2),
            FLOOR(1 + RAND() * 100),
            FLOOR(RAND() * 1000)
        );
        SET i = i + 1;
    END WHILE;

    -- 注文データ（50万件）
    SET i = 1;
    WHILE i <= 500000 DO
        INSERT INTO orders (user_id, total_amount, status, ordered_at)
        VALUES (
            FLOOR(1 + RAND() * 1000000),
            ROUND(RAND() * 50000, 2),
            ELT(FLOOR(1 + RAND() * 4), 'pending', 'processing', 'completed', 'cancelled'),
            DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 365) DAY)
        );

        -- 注文明細（各注文に1-5個のアイテム）
        SET j = 1;
        WHILE j <= FLOOR(1 + RAND() * 5) DO
            INSERT INTO order_items (order_id, product_id, quantity, price)
            VALUES (
                i,
                FLOOR(1 + RAND() * 10000),
                FLOOR(1 + RAND() * 10),
                ROUND(RAND() * 10000, 2)
            );
            SET j = j + 1;
        END WHILE;

        -- 1000件ごとにコミット
        IF i % 1000 = 0 THEN
            COMMIT;
        END IF;

        SET i = i + 1;
    END WHILE;

    COMMIT;
END//

DELIMITER ;

-- プロシージャ実行
CALL generate_test_data();
```

## 確認課題
1. MySQLコンテナが正常に起動していることを確認
2. phpMyAdminでテーブル構造を確認
3. 各テーブルのレコード数を確認
```sql
SELECT
    'users' AS table_name, COUNT(*) AS record_count FROM users
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items;
```