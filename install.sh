#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="/usr/local/bin"
SCRIPT_FILE="del-doot-inator.sh"
BIN_NAME="del-doot-inator"
SOURCE="$(cd "$(dirname "$0")" && pwd)/$SCRIPT_FILE"

if [ ! -f "$SOURCE" ]; then
    echo -e "${RED}Error: $SCRIPT_FILE not found in $(dirname "$0")${NC}"
    exit 1
fi

echo "Installing $BIN_NAME to $INSTALL_DIR..."

if [ -w "$INSTALL_DIR" ]; then
    install -m 0755 "$SOURCE" "$INSTALL_DIR/$BIN_NAME"
else
    sudo install -m 0755 "$SOURCE" "$INSTALL_DIR/$BIN_NAME"
fi

echo -e "${GREEN}✔ Installed! Run '$BIN_NAME --help' to get started 🗑️💀${NC}"
