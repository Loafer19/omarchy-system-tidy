#!/usr/bin/env bash
# Run all tests. Nothing here touches the real system: the backend tests use
# stubbed pacman/expac/pkexec/systemctl/docker in a temp HOME.
set -euo pipefail
cd "$(dirname "$0")/.."
node tests/model.test.js
bash tests/backend.sh
