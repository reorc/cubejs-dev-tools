#!/bin/bash

# Read database connection details from .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Set default values if not found in .env
DB_HOST=${CUBEJS_DB_HOST:-"127.0.0.1"}
DB_PORT=${CUBEJS_DB_PORT:-"3306"}
DB_NAME=${CUBEJS_DB_NAME:-"test"}
DB_USER=${CUBEJS_DB_USER:-"root"}
DB_PASS=${CUBEJS_DB_PASS:-"password"}

# Function to execute SQL files
execute_sql_file() {
    local file=$1
    echo "Executing $file..."
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$SCRIPT_DIR/$file"
}

# Create database if it doesn't exist
echo "Creating database if it doesn't exist..."
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;" 2>/dev/null

# Use the database
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME;"

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