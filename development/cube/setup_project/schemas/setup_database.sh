#!/bin/bash

# Read database connection details from .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Set default values if not found in .env
DB_HOST=${CUBEJS_DB_HOST:-localhost}
DB_PORT=${CUBEJS_DB_PORT:-5432}
DB_NAME=${CUBEJS_DB_NAME:-postgres}
DB_USER=${CUBEJS_DB_USER:-postgres}
DB_PASS=${CUBEJS_DB_PASS:-postgres}

echo "Creating tables..."
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f model/schema/create_tables.sql

echo "Inserting products data..."
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f model/schema/insert_products.sql

echo "Inserting orders data..."
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f model/schema/insert_orders.sql

echo "Inserting order items data..."
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f model/schema/insert_order_items.sql

echo "Database setup complete!" 