-- Insert order_items data
INSERT INTO order_items (id, order_id, product_id, quantity, price)
VALUES
    (1, 1, 1, 2, 50),
    (2, 1, 2, 1, 50),
    (3, 2, 1, 4, 50),
    (4, 3, 3, 1, 300),
    (5, 4, 2, 5, 100),
    (6, 5, 3, 2, 300),
    (7, 6, 4, 3, 150),
    (8, 6, 5, 2, 200),
    (9, 7, 1, 1, 50),
    (10, 7, 5, 3, 200),
    (11, 8, 2, 2, 100),
    (12, 8, 4, 4, 150),
    (13, 9, 3, 1, 300),
    (14, 10, 1, 6, 50),
    (15, 10, 2, 3, 100),
    (16, 11, 5, 4, 200),
    (17, 12, 3, 1, 300),
    (18, 12, 4, 1, 150),
    (19, 13, 2, 4, 100),
    (20, 13, 5, 2, 200),
    (21, 14, 1, 3, 50),
    (22, 14, 3, 2, 300),
    (23, 15, 4, 3, 150),
    (24, 16, 2, 2, 100),
    (25, 16, 5, 3, 200),
    (26, 17, 1, 4, 50),
    (27, 17, 3, 2, 300),
    (28, 18, 4, 2, 150),
    (29, 19, 2, 3, 100),
    (30, 19, 5, 2, 200),
    (31, 20, 1, 5, 50),
    (32, 20, 3, 2, 300),
    (33, 21, 4, 3, 150),
    (34, 22, 2, 4, 100),
    (35, 22, 5, 2, 200),
    (36, 23, 1, 3, 50),
    (37, 23, 3, 2, 300),
    (38, 24, 4, 2, 150),
    (39, 24, 5, 1, 200),
    (40, 25, 2, 3, 100),
    (41, 25, 3, 1, 300)
ON DUPLICATE KEY UPDATE
    order_id = VALUES(order_id),
    product_id = VALUES(product_id),
    quantity = VALUES(quantity),
    price = VALUES(price); 