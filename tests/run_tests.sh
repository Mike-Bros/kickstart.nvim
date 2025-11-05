#!/bin/bash
# Test runner for gravity.nvim

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "Running gravity.nvim tests..."
echo "================================"

nvim --headless --noplugin \
  -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/gravity { minimal_init = 'tests/minimal_init.lua' }"

echo ""
echo "================================"
echo "Tests complete!"
