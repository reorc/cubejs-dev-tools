-- Insert orders data
INSERT INTO orders (id, amount, status, created_at)
VALUES
    (1, 100, 'new', '2023-01-15'),
    (2, 200, 'new', '2023-01-28'),
    (3, 300, 'processed', '2023-02-05'),
    (4, 500, 'processed', '2023-02-17'),
    (5, 600, 'shipped', '2023-03-03'),
    (6, 750, 'new', '2023-03-22'),
    (7, 420, 'processed', '2023-04-08'),
    (8, 890, 'shipped', '2023-04-19'),
    (9, 340, 'new', '2023-05-02'),
    (10, 1200, 'processed', '2023-05-17'),
    (11, 950, 'shipped', '2023-06-05'),
    (12, 480, 'new', '2023-06-22'),
    (13, 720, 'processed', '2023-07-10'),
    (14, 830, 'shipped', '2023-07-28'),
    (15, 550, 'new', '2023-08-09'),
    (16, 670, 'processed', '2023-08-24'),
    (17, 920, 'shipped', '2023-09-07'),
    (18, 430, 'new', '2023-09-19'),
    (19, 780, 'processed', '2023-10-03'),
    (20, 1100, 'shipped', '2023-10-21'),
    (21, 650, 'new', '2023-11-05'),
    (22, 840, 'processed', '2023-11-18'),
    (23, 990, 'shipped', '2023-12-02'),
    (24, 520, 'new', '2023-12-15'),
    (25, 760, 'processed', '2023-12-28')
ON DUPLICATE KEY UPDATE
    amount = VALUES(amount),
    status = VALUES(status),
    created_at = VALUES(created_at); 