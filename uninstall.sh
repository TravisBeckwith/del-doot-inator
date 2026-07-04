#!/bin/bash

set -e

GREEN='\033[0;32m'
NC='\033[0m'

INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="del-doot-inator"

echo "Removing $SCRIPT_NAME from $INSTALL_DIR..."

if [ -w "$INSTALL_DIR" ]; then
    rm -f "$INSTALL_DIR/$SCRIPT_NAME"
else
    sudo rm -f "$INSTALL_DIR/$SCRIPT_NAME"
fi

echo -e "${GREEN}✔ Uninstalled. Farewell, del-doot-inator 🗑️${NC}"
