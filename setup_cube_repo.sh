#!/bin/bash

# Set up base directories
BASE_DIR=~/projects/cube
BRANCHES_DIR=$BASE_DIR/branches
GIT_DIR=$BASE_DIR/git

# Create necessary directories
mkdir -p "$BRANCHES_DIR"

# Clone the repository with separate git directory
git clone --separate-git-dir="$GIT_DIR" https://github.com/reorc/cube.git "$BRANCHES_DIR/master"

# Change to the master branch directory
cd "$BRANCHES_DIR/master"

# Create worktree for reorc branch
git worktree add "$BRANCHES_DIR/reorc" reorc

echo "Repository setup complete!"
echo "Master branch is at: $BRANCHES_DIR/master"
echo "Reorc branch is at: $BRANCHES_DIR/reorc" 