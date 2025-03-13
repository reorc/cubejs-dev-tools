#!/bin/bash

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Starting Cube.js Debugging Environment ===${NC}"

# Function to kill processes by port
kill_process_by_port() {
  local port=$1
  local pid=$(lsof -i :$port | grep LISTEN | awk '{print $2}')
  if [ ! -z "$pid" ]; then
    echo -e "${RED}Killing process on port $port (PID: $pid)${NC}"
    kill -9 $pid 2>/dev/null || true
  else
    echo -e "${GREEN}No process found on port $port${NC}"
  fi
}

# Function to kill processes by name
kill_process_by_name() {
  local name=$1
  local pids=$(pgrep -f "$name" || true)
  if [ ! -z "$pids" ]; then
    echo -e "${RED}Killing processes matching '$name' (PIDs: $pids)${NC}"
    pkill -f "$name" 2>/dev/null || true
  else
    echo -e "${GREEN}No processes found matching '$name'${NC}"
  fi
}

# Function to link a package
link_package() {
  local package_path=$1
  local package_name=$2
  
  echo -e "${YELLOW}Linking package: ${package_name}${NC}"
  
  # Register the package globally
  cd ${package_path}
  yarn link 2>/dev/null || true
  
  # Link the package in the test project
  cd ${TEST_PROJECT_PATH}
  yarn link ${package_name} 2>/dev/null || true
}

# Define paths
CUBE_REPO_PATH=~/projects/cube/branches/develop
CUBESQL_PATH=${CUBE_REPO_PATH}/rust/cubesql
TEST_PROJECT_PATH=~/projects/cubejs-test-project
CUBESQL_EXECUTABLE=${CUBESQL_PATH}/target/debug/cubesqld

echo -e "${BLUE}Cleaning up existing processes...${NC}"

# Kill any existing Node.js processes on port 9229 (debugger)
kill_process_by_port 9229

# Kill any existing Cube.js server processes on port 4000
kill_process_by_port 4000

# Kill any existing CubeSQL processes on port 15432
kill_process_by_port 15432

# Kill any existing TypeScript compiler processes
kill_process_by_name "yarn tsc:watch"

# Kill any existing CubeSQL processes
kill_process_by_name "cubesql"
kill_process_by_name "cubesqld"

# Additional cleanup for any stray processes
kill_process_by_name "cubejs-server"

# Wait a moment to ensure all processes are terminated
echo -e "${BLUE}Waiting for processes to terminate...${NC}"
sleep 2

# Ensure all key packages are properly linked
echo -e "${BLUE}Ensuring packages are properly linked...${NC}"

# Core packages for API and query processing
link_package "${CUBE_REPO_PATH}/packages/cubejs-api-gateway" "@cubejs-backend/api-gateway"
link_package "${CUBE_REPO_PATH}/packages/cubejs-schema-compiler" "@cubejs-backend/schema-compiler"
link_package "${CUBE_REPO_PATH}/packages/cubejs-query-orchestrator" "@cubejs-backend/query-orchestrator"
link_package "${CUBE_REPO_PATH}/packages/cubejs-server-core" "@cubejs-backend/server-core"

# Additional packages that might be involved in rolling window functionality
link_package "${CUBE_REPO_PATH}/packages/cubejs-backend-shared" "@cubejs-backend/shared"
link_package "${CUBE_REPO_PATH}/packages/cubejs-base-driver" "@cubejs-backend/base-driver"

echo -e "${GREEN}Package linking complete!${NC}"

# Start TypeScript compiler in watch mode
echo -e "${BLUE}Starting TypeScript compiler in watch mode...${NC}"
cd ${CUBE_REPO_PATH}
yarn tsc:watch > typescript-watch.log 2>&1 &
TSC_PID=$!
echo -e "${GREEN}TypeScript compiler started with PID: $TSC_PID${NC}"

# Wait for TypeScript compiler to initialize
echo -e "${BLUE}Waiting for TypeScript compiler to initialize...${NC}"
sleep 5

# Build CubeSQL with debug symbols
echo -e "${BLUE}Building CubeSQL with debug symbols...${NC}"
cd ${CUBESQL_PATH}
cargo build

# Verify the CubeSQL executable exists
if [ ! -f "${CUBESQL_EXECUTABLE}" ]; then
  echo -e "${RED}CubeSQL executable not found at ${CUBESQL_EXECUTABLE}${NC}"
  echo -e "${RED}Please check the path and build process${NC}"
  exit 1
fi

# Start CubeSQL with debugging enabled
echo -e "${BLUE}Starting CubeSQL in the background...${NC}"
cd ${CUBESQL_PATH}
RUST_BACKTRACE=1 RUST_LOG=trace ${CUBESQL_EXECUTABLE} &
CUBESQL_PID=$!
echo -e "${GREEN}CubeSQL started with PID: $CUBESQL_PID${NC}"

# Start Cube.js with debugging enabled
echo -e "${BLUE}Starting Cube.js with debugging enabled...${NC}"
cd ${TEST_PROJECT_PATH}
echo -e "${GREEN}Attaching debugger to port 9229. Please set your breakpoints now.${NC}"
echo -e "${GREEN}Recommended breakpoints:${NC}"
echo -e "${GREEN}1. ${CUBE_REPO_PATH}/packages/cubejs-api-gateway/src/gateway.ts - Look for the load() method around line 1785${NC}"
echo -e "${GREEN}2. ${CUBE_REPO_PATH}/packages/cubejs-schema-compiler/src/adapter/BaseQuery.js - Look for methods with 'rollingWindow' in their name${NC}"
echo -e "${GREEN}3. ${CUBE_REPO_PATH}/packages/cubejs-schema-compiler/src/adapter/BaseTimeDimension.ts - Contains time dimension handling logic${NC}"
echo -e "${GREEN}4. ${CUBE_REPO_PATH}/packages/cubejs-query-orchestrator/src/orchestrator/QueryOrchestrator.ts - For query execution${NC}"

# Print debugging instructions
echo -e "${YELLOW}=== Debugging Instructions ===${NC}"
echo -e "${YELLOW}1. Open VSCode and go to the Run and Debug view (Ctrl+Shift+D)${NC}"
echo -e "${YELLOW}2. Select 'Attach to Cube.js Server' from the dropdown${NC}"
echo -e "${YELLOW}3. Click the green play button to attach the debugger${NC}"
echo -e "${YELLOW}4. Set breakpoints in the files mentioned above${NC}"
echo -e "${YELLOW}5. Run a query using the debug-rolling-window.sh script in another terminal${NC}"
echo -e "${YELLOW}6. The debugger will pause at your breakpoints${NC}"

NODE_OPTIONS="--inspect-brk=0.0.0.0:9229" CUBEJS_DEV_MODE=true CUBEJS_LOG_LEVEL=trace yarn dev

# Cleanup on exit
trap "echo -e '${RED}Cleaning up processes...${NC}'; kill $CUBESQL_PID $TSC_PID 2>/dev/null || true" EXIT 