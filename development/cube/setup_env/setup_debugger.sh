#!/bin/bash
set -e

# Source the common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$PROJECT_ROOT/common/utils.sh"

# Define the target directory for the develop branch
CUBE_DEVELOP_DIR=~/projects/cube/branches/develop
VSCODE_DIR="${CUBE_DEVELOP_DIR}/.vscode"
LAUNCH_JSON="${VSCODE_DIR}/launch.json"

# Check if the directory exists
if [ ! -d "${CUBE_DEVELOP_DIR}" ]; then
  print_warning "Error: Cube.js develop branch directory not found at ${CUBE_DEVELOP_DIR}"
  print_warning "Please make sure setup_cube_repo.sh has been run successfully first."
  exit 1
fi

# Check if launch.json already exists
if [ -f "${LAUNCH_JSON}" ]; then
  print_warning "VSCode launch configuration already exists at ${LAUNCH_JSON}"
  read -p "Do you want to overwrite it? (y/n): " overwrite
  if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
    print_success "Keeping existing launch configuration."
    exit 0
  fi
  print_status "Overwriting existing launch configuration..."
else
  print_status "Creating VSCode launch configuration..."
fi

# Create .vscode directory if it doesn't exist
mkdir -p "${VSCODE_DIR}"

# Create launch.json
cat > "${LAUNCH_JSON}" << 'EOL'
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "attach",
      "name": "Attach to Cube.js Server",
      "port": 9229,
      "skipFiles": [
        "<node_internals>/**"
      ],
      "sourceMaps": true,
      "outFiles": [
        "${workspaceFolder}/packages/*/dist/**/*.js"
      ],
      "resolveSourceMapLocations": [
        "${workspaceFolder}/**",
        "!**/node_modules/**"
      ]
    },
    {
      "type": "node",
      "request": "launch",
      "name": "Launch Test Project",
      "program": "${workspaceFolder}/node_modules/.bin/cubejs-server",
      "args": [],
      "cwd": "${HOME}/projects/cubejs-test-project",
      "env": {
        "CUBEJS_DEV_MODE": "true",
        "CUBEJS_LOG_LEVEL": "trace"
      },
      "sourceMaps": true,
      "outFiles": [
        "${workspaceFolder}/packages/*/dist/**/*.js"
      ],
      "resolveSourceMapLocations": [
        "${workspaceFolder}/**",
        "!**/node_modules/**"
      ]
    },
    {
      "type": "lldb",
      "request": "launch",
      "name": "Debug CubeSQL",
      "program": "${workspaceFolder}/rust/cubesql/target/debug/cubesql",
      "args": [],
      "cwd": "${workspaceFolder}/rust/cubesql",
      "sourceLanguages": ["rust"],
      "sourceMap": {
        "/rustc/*": "${HOME}/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/src/rust"
      }
    },
    {
      "type": "lldb",
      "request": "attach",
      "name": "Attach to CubeSQL",
      "pid": "${command:pickProcess}",
      "sourceLanguages": ["rust"],
      "sourceMap": {
        "/rustc/*": "${HOME}/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/src/rust"
      }
    }
  ]
}
EOL

print_success "VSCode launch configuration has been set up successfully at ${LAUNCH_JSON}"
print_success "You can now debug Cube.js in the develop branch."
