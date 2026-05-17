#!/bin/bash
set -euo pipefail

trap 'echo "ERROR: Command failed at line $LINENO with exit code $?" >&2; exit 1' ERR

GREEN='\033[0;32m'
NC='\033[0m'

SUDO=""
if command -v sudo &>/dev/null; then
    SUDO="sudo"
fi

NEEDS_UPDATE=false

if command -v aria2c &>/dev/null; then
    echo "aria2 is already installed. Skipping."
else
    NEEDS_UPDATE=true
fi

if command -v ffmpeg &>/dev/null; then
    echo "ffmpeg is already installed. Skipping."
else
    NEEDS_UPDATE=true
fi

if $NEEDS_UPDATE; then
    $SUDO apt update -y
fi

if ! command -v aria2c &>/dev/null; then
    $SUDO apt install -y aria2
fi

if ! command -v ffmpeg &>/dev/null; then
    $SUDO apt install -y ffmpeg
fi

echo -e "${GREEN}All commands executed successfully.${NC}"
exit 0
