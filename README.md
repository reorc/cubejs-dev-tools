# Cube.js Development Tools

This repository contains a collection of scripts and utilities designed to streamline Cube.js development, testing, and production workflows. These tools help with setting up development environments, testing with various databases, and building production Docker images.

## Repository Structure

```
cubejs-dev-tools/
├── common/           # Shared utilities used across scripts
├── development/      # Scripts for development environments
├── production/       # Scripts for building production images
├── setup/            # Initial repository setup scripts
└── testing/          # Database setup scripts for testing
```

## Setup

### Repository Setup

The `setup/setup_cube_repo.sh` script helps you set up the Cube.js repository with multiple branches for development:

```bash
./setup/setup_cube_repo.sh
```

This script:
- Clones the Cube.js repository
- Sets up multiple branches in separate directories
- Creates a shared Git directory for efficient storage

## Development

### Debug Environment

The `development/cube/debug.sh` script sets up a Cube.js debugging environment:

```bash
./development/cube/debug.sh [options]
```

Features:
- Kills existing processes on relevant ports
- Sets up environment variables for debugging
- Starts Cube.js in development mode
- Provides options for customizing the debug environment

### Environment Setup Scripts

The `development/cube/setup_env/` directory contains scripts for setting up your development environment:

#### Install Dependencies

```bash
./development/cube/setup_env/install_dependencies.sh
```

Installs all necessary dependencies for Cube.js development:
- Node.js 20.x and Yarn
- Rust (required for some Cube.js components)
- Common system packages (curl, git, build-essential, etc.)
- VSCode extensions for debugging (if VSCode is installed)

#### Setup Debugger

```bash
./development/cube/setup_env/setup_debugger.sh
```

Configures VSCode for debugging Cube.js:
- Creates a `.vscode/launch.json` configuration
- Sets up Node.js debugging configurations
- Configures breakpoints and debugging settings

#### Setup Playground

```bash
./development/cube/setup_env/setup_playground.sh
```

Sets up the Cube.js Playground environment:
- Configures the Playground for local development
- Ensures all dependencies are installed
- Prepares the environment for interactive testing

### Test Project Setup

The `development/cube/setup_project/` directory contains scripts for setting up test projects:

#### Setup Test Project

```bash
./development/cube/setup_project/setup_test_project.sh
```

Creates a complete test project for Cube.js development:
- Sets up a new Cube.js project
- Configures database connections
- Creates sample schema files
- Loads test data into the database

#### Test Schemas

The `development/cube/setup_project/schemas/` directory contains SQL scripts for setting up test data:
- `create_tables.sql` - Creates sample tables for testing
- `insert_orders.sql` - Inserts sample order data
- `insert_order_items.sql` - Inserts sample order item data
- `insert_products.sql` - Inserts sample product data
- `setup_database.sh` - Script to run all SQL scripts and set up the test database

## Testing

### Database Setup Scripts

The testing directory contains scripts to set up various databases for testing Cube.js:

#### PostgreSQL

```bash
./testing/db_setup/setup_postgres.sh
```

Sets up a PostgreSQL database using Docker Compose with:
- PostgreSQL 16.1
- Default credentials (postgres/postgres)
- Exposed on port 5432

#### MySQL

```bash
./testing/db_setup/setup_mysql.sh
```

Sets up a MySQL database using Docker Compose with:
- MySQL 8.0
- Default credentials (root/mysql)
- Exposed on port 3306

#### DorisDB

```bash
./testing/db_setup/setup_dorisdb.sh
```

Sets up a DorisDB instance using Docker Compose with:
- Latest DorisDB version
- Default credentials
- Exposed on standard DorisDB ports

## Production

### Docker Image Building

The production directory contains scripts for building Docker images:

#### Base Image

```bash
./production/build_base_image.sh [--image-name NAME] [--image-tag TAG]
```

Builds a base Docker image for Cube.js with:
- Node.js and required dependencies
- Configurable image name and tag

#### Final Image

```bash
./production/build_final_image.sh [--image-name NAME] [--image-tag TAG]
```

Builds a production-ready Docker image with:
- Optimized for production use
- Minimal dependencies
- Configurable image name and tag

#### DorisDB Driver

```bash
./production/build_doris_driver.sh [options]
```

Builds the DorisDB driver for Cube.js:
- Compiles the driver from source
- Packages it for use with Cube.js

## Common Utilities

The `common/utils.sh` script provides shared functions used across all scripts:

- Color-coded output functions
- Command existence checks
- Error handling utilities
- Docker and system management functions

## Requirements

- Ubuntu 24.04 LTS (recommended)
- Docker and Docker Compose
- Git
- Node.js (for development)
- Bash shell

## Use Cases

### Setting Up a TypeScript/JavaScript Development Environment with Debugging

This use case walks through setting up a complete development environment for Cube.js with TypeScript/JavaScript support and step-by-step debugging capabilities.

#### Step 1: Initial Repository Setup

First, set up the Cube.js repository structure:

```bash
# Clone the cubejs-dev-tools repository if you haven't already
git clone https://github.com/your-org/cubejs-dev-tools.git
cd cubejs-dev-tools

# Set up the Cube.js repository with multiple branches
./setup/setup_cube_repo.sh
```

This creates a structured directory at `~/projects/cube` with the Cube.js codebase and multiple branches for development.

#### Step 2: Install Development Dependencies

Install all necessary dependencies for Cube.js development:

```bash
# Install Node.js, Yarn, Rust, and other dependencies
./development/cube/setup_env/install_dependencies.sh
```

This script ensures you have all the required tools and libraries for Cube.js development, including Node.js 20.x, Yarn, and Rust.

#### Step 3: Set Up a Test Database

Set up a PostgreSQL database for testing (you can choose MySQL or DorisDB instead if preferred):

```bash
# Set up PostgreSQL using Docker
./testing/db_setup/setup_postgres.sh
```

This creates a PostgreSQL database running in Docker, accessible on port 5432 with credentials `postgres/postgres`.

#### Step 4: Configure VSCode for Debugging

Set up VSCode with the proper debugging configurations:

```bash
# Configure VSCode for debugging Cube.js
./development/cube/setup_env/setup_debugger.sh
```

This creates a `.vscode/launch.json` file in the Cube.js repository with configurations for debugging both TypeScript and JavaScript code.

#### Step 5: Set Up the Playground

Configure the Cube.js Playground for interactive development:

```bash
# Set up the Cube.js Playground
./development/cube/setup_env/setup_playground.sh
```

This prepares the Playground environment for local development and testing.

#### Step 6: Create a Test Project

Set up a test project with sample data for development:

```bash
# Create a test project with sample data
./development/cube/setup_project/setup_test_project.sh
```

This creates a new Cube.js project at `~/projects/cubejs-test-project` with:
- Database connection to your PostgreSQL instance
- Sample schema files
- Test data loaded into the database

#### Step 7: Start Debugging Session

Start a debugging session with the debug script:

```bash
# Start a debugging session
./development/cube/debug.sh
```

This script:
1. Kills any existing processes on relevant ports
2. Sets up environment variables for debugging
3. Starts Cube.js in development mode with debugging enabled

#### Step 8: Debug in VSCode

1. Open VSCode and navigate to the Cube.js repository at `~/projects/cube/branches/develop`
2. Set breakpoints in the TypeScript/JavaScript code
3. Go to the "Run and Debug" panel in VSCode
4. Select the appropriate debug configuration from the dropdown
5. Click the green play button to start debugging
6. Access the Cube.js Playground at http://localhost:4000

You can now make changes to the Cube.js codebase, set breakpoints, and debug step-by-step through the code execution.

### Building a Custom Docker Image with Custom Code

This use case demonstrates how to build a custom Docker image that includes your own modifications to Cube.js from a specific branch (in this case, the `reorc` branch).

#### Step 1: Ensure Repository Setup

First, make sure you have the Cube.js repository set up with the necessary branches:

```bash
# Set up the Cube.js repository if you haven't already
./setup/setup_cube_repo.sh
```

This script should have already set up multiple branches, including the `reorc` branch with your custom code.

#### Step 2: Verify Your Custom Code

Ensure your custom code is properly committed to the `reorc` branch:

```bash
# Navigate to the reorc branch directory
cd ~/projects/cube/branches/reorc

# Check the status of your branch
git status

# Make sure all your changes are committed
git add .
git commit -m "Your custom changes for Docker image"
```

#### Step 3: Build the Base Image

Build the base Docker image using the `reorc` branch:

```bash
# Navigate back to the cubejs-dev-tools directory
cd ~/projects/cubejs-dev-tools

# Build the base image with the reorc branch
./production/build_base_image.sh --image-name your-org/cubejs-custom --image-tag latest --branch reorc
```

This script:
- Uses the code from the `reorc` branch
- Creates a base Docker image with all dependencies
- Tags the image with your specified name and tag

#### Step 4: Build Custom Drivers (If Needed)

If your custom code includes modifications to database drivers (e.g., DorisDB driver), build them:

```bash
# Build the DorisDB driver (if needed)
./production/build_doris_driver.sh --image-name your-org/cubejs-custom --image-tag latest --branch reorc
```

This step is crucial if you have custom driver code, as the final image will include these drivers.

#### Step 5: Build the Final Image

Build the production-ready Docker image:

```bash
# Build the final production image
./production/build_final_image.sh --image-name your-org/cubejs-custom --image-tag latest --branch reorc
```

This script:
- Takes the base image created in step 3
- Incorporates any custom drivers built in step 4
- Optimizes it for production use
- Creates a smaller, more efficient Docker image

#### Step 6: Test Your Custom Image

Test your custom Docker image to ensure it works as expected:

```bash
# Run the custom Docker image
docker run -d \
  --name cubejs-custom \
  -p 4000:4000 \
  -e CUBEJS_DEV_MODE=true \
  -e CUBEJS_DB_TYPE=postgres \
  -e CUBEJS_DB_HOST=host.docker.internal \
  -e CUBEJS_DB_NAME=postgres \
  -e CUBEJS_DB_USER=postgres \
  -e CUBEJS_DB_PASS=postgres \
  your-org/cubejs-custom:latest
```

#### Step 7: Push to Docker Registry (Optional)

Push your custom image to a Docker registry for deployment:

```bash
# Log in to your Docker registry
docker login your-registry.com

# Push the image
docker push your-org/cubejs-custom:latest
```

#### Step 8: Deploy Your Custom Image

Deploy your custom Cube.js image to your production environment using your standard deployment methods (Kubernetes, Docker Compose, etc.).

This custom image contains all your specific modifications from the `reorc` branch while maintaining compatibility with the official Cube.js release.

### Launching a Cube.js Instance with a Ready-to-Use Project

This use case demonstrates how to quickly launch a fully configured Cube.js instance with a sample project using Docker, complete with database setup, data models, and sample queries.

#### Step 1: Ensure Dependencies Are Installed

First, make sure you have the necessary dependencies installed:

```bash
# Install dependencies if you haven't already
./development/cube/setup_env/install_dependencies.sh
```

This ensures Docker, Node.js, and other required tools are available.

#### Step 2: Launch the Cube.js Project

Use the `launch_cubejs_project.sh` script to set up and launch a complete Cube.js project:

```bash
# Launch a Cube.js project with PostgreSQL
./testing/project_setup/launch_cubejs_project.sh --db-type postgres
```

This script performs the following actions:
- Sets up a PostgreSQL database (or MySQL/DorisDB if specified)
- Creates a project directory at `~/projects/cubejs-test-project`
- Populates the database with sample data (products, orders, order items)
- Creates Cube.js data models for the sample data
- Configures environment variables for Cube.js
- Launches Cube.js using Docker
- Creates sample queries for testing

#### Step 3: Customize the Project (Optional)

You can customize various aspects of the project by passing additional parameters:

```bash
# Launch with custom settings
./testing/project_setup/launch_cubejs_project.sh \
  --db-type mysql \
  --image your-org/cubejs-custom:latest \
  --project-name my-cubejs-project \
  --rest-port 4500 \
  --sql-port 15433
```

Available options include:
- `--db-type`: Database type (postgres, mysql, doris)
- `--image`: Cube.js Docker image to use
- `--project-name`: Custom project name
- `--project-dir`: Custom project directory
- `--rest-port`: Port for the REST API
- `--sql-port`: Port for the SQL API

#### Step 4: Access the Cube.js Playground

Once the script completes, you can access the Cube.js Playground:

1. Open your browser and navigate to http://localhost:4000 (or your custom port)
2. Explore the pre-built data models in the Playground
3. Run sample queries using the REST API or SQL API

#### Step 5: Run Sample Queries

The script creates sample query files that you can run:

```bash
# Run the sample REST API query
cd ~/projects/cubejs-test-project
node sample_query.js
```

For SQL queries:
```bash
# Connect to the SQL API
psql -h localhost -p 15432 -U cubesql
# Password: cubesql

# Then run queries from sample_sql_query.txt
```

#### Step 6: Stop the Cube.js Instance (When Finished)

When you're done, you can stop the Cube.js instance:

```bash
cd ~/projects/cubejs-test-project
docker-compose down
```

#### Step 7: Clean Up the Project (Optional)

The script also provides a convenient way to completely clean up the project when you're done with it:

```bash
# Clean up the project (remove Docker container and project directory)
./testing/project_setup/launch_cubejs_project.sh --project-name cubejs-test-project --cleanup
```

This cleanup operation:
- Stops and removes the Docker container
- Removes the project directory and all its contents
- Provides a clean slate for future testing

You can also specify a custom project name if you used one during setup:

```bash
# Clean up a custom project
./testing/project_setup/launch_cubejs_project.sh --project-name my-cubejs-project --cleanup
```

This use case provides a quick way to get a fully functional Cube.js environment for testing, demonstrations, or development without having to manually configure each component.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the terms of the MIT license.