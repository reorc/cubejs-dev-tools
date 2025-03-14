#!/bin/bash

# Read database connection details from .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Set default values if not found in .env
DB_HOST=${CUBEJS_DB_HOST:-"127.0.0.1"}
DB_PORT=${CUBEJS_DB_PORT:-"5432"}
DB_NAME=${CUBEJS_DB_NAME:-"test"}
DB_USER=${CUBEJS_DB_USER:-"postgres"}
DB_PASS=${CUBEJS_DB_PASS:-"postgres"}

# Function to execute SQL files
execute_sql_file() {
    local file=$1
    echo "Executing $file..."
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$file"
}

# Create database if it doesn't exist
echo "Creating database if it doesn't exist..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "postgres" -c "CREATE DATABASE $DB_NAME;"

# Execute SQL files in order
echo "Creating tables..."
execute_sql_file "create_tables.sql"

echo "Inserting products data..."
execute_sql_file "insert_products.sql"

echo "Inserting orders data..."
execute_sql_file "insert_orders.sql"

echo "Inserting order items data..."
execute_sql_file "insert_order_items.sql"

echo "Database setup complete!" 