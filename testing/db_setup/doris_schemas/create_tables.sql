-- Create tables for DorisDB

-- Products table
CREATE TABLE IF NOT EXISTS products (
    id INT,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(255) NOT NULL,
    base_price DECIMAL(10, 2) NOT NULL,
    added_date DATE NOT NULL
)
DISTRIBUTED BY HASH(id) BUCKETS 1
PROPERTIES(
    'replication_num' = '1'
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id INT,
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at DATE NOT NULL
)
DISTRIBUTED BY HASH(id) BUCKETS 1
PROPERTIES(
    'replication_num' = '1'
);

-- Order items table
CREATE TABLE IF NOT EXISTS order_items (
    id INT,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL
)
DISTRIBUTED BY HASH(id) BUCKETS 1
PROPERTIES(
    'replication_num' = '1'
); 