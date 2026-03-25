#!/bin/bash
# opencode-run.sh - Run opencode run with authentication environment variables
# This script passes the required OPENCODE_SERVER_USERNAME and OPENCODE_SERVER_PASSWORD
# to opencode run command, allowing docker applications to call it without being blocked by auth
#
# Usage: opencode-run.sh [arguments...]
# Example: opencode-run.sh 123

exec env OPENCODE_SERVER_USERNAME="${OPENCODE_SERVER_USERNAME}" OPENCODE_SERVER_PASSWORD="${OPENCODE_SERVER_PASSWORD}" /home/aiuser/.opencode/bin/opencode run "$@"
