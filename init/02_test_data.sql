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