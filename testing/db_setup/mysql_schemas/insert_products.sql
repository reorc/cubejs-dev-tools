-- Insert products data
INSERT INTO products (id, name, category, base_price, added_date)
VALUES
    (1, 'Laptop Pro', 'Electronics', 1299.99, '2023-01-01'),
    (2, 'Smartphone X', 'Electronics', 899.99, '2023-01-05'),
    (3, 'Wireless Headphones', 'Electronics', 199.99, '2023-01-10'),
    (4, 'Coffee Maker', 'Home Appliances', 89.99, '2023-01-15'),
    (5, 'Blender', 'Home Appliances', 69.99, '2023-01-20'),
    (6, 'Running Shoes', 'Sports', 129.99, '2023-02-01'),
    (7, 'Yoga Mat', 'Sports', 39.99, '2023-02-05'),
    (8, 'Desk Lamp', 'Home Decor', 49.99, '2023-02-10'),
    (9, 'Backpack', 'Accessories', 59.99, '2023-02-15'),
    (10, 'Water Bottle', 'Accessories', 19.99, '2023-02-20'),
    (11, 'Fitness Tracker', 'Electronics', 149.99, '2023-03-01'),
    (12, 'Toaster', 'Home Appliances', 49.99, '2023-03-05'),
    (13, 'Bluetooth Speaker', 'Electronics', 79.99, '2023-03-10'),
    (14, 'Desk Chair', 'Furniture', 199.99, '2023-03-15'),
    (15, 'Sunglasses', 'Accessories', 89.99, '2023-03-20'),
    (16, 'Tablet', 'Electronics', 499.99, '2023-04-01'),
    (17, 'Microwave', 'Home Appliances', 129.99, '2023-04-05'),
    (18, 'Basketball', 'Sports', 29.99, '2023-04-10'),
    (19, 'Wall Clock', 'Home Decor', 39.99, '2023-04-15'),
    (20, 'Wallet', 'Accessories', 49.99, '2023-04-20'),
    (21, 'External Hard Drive', 'Electronics', 119.99, '2023-05-01'),
    (22, 'Air Purifier', 'Home Appliances', 179.99, '2023-05-05'),
    (23, 'Dumbbell Set', 'Sports', 149.99, '2023-05-10'),
    (24, 'Throw Pillow', 'Home Decor', 29.99, '2023-05-15'),
    (25, 'Umbrella', 'Accessories', 24.99, '2023-05-20')
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    category = VALUES(category),
    base_price = VALUES(base_price),
    added_date = VALUES(added_date); 