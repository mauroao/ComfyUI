#!/bin/bash
# =============================================================================
# Script 1: Install CUDA Toolkit 12.8 on WSL Ubuntu
# Target: WSL Ubuntu 24.04 + RTX 4060 Ti (or any Ada/Ampere GPU)
# =============================================================================

set -euo pipefail
trap 'echo "ERROR: Command failed at line $LINENO with exit code $?" >&2; exit 1' ERR

CUDA_VERSION="12.8"
CUDA_PKG="cuda-toolkit-12-8"
CUDA_PATH="/usr/local/cuda-${CUDA_VERSION}"
KEYRING_DEB="cuda-keyring_1.1-1_all.deb"
KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/${KEYRING_DEB}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "============================================="
echo " CUDA Toolkit ${CUDA_VERSION} Installer (WSL)"
echo "============================================="
echo ""

# -----------------------------------------------------------------------------
# Step 1: Check if CUDA toolkit (nvcc) is already installed
# -----------------------------------------------------------------------------
echo ">>> Checking if CUDA toolkit is already installed..."

if command -v nvcc &> /dev/null; then
    INSTALLED_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | tr -d ',')
    echo -e "${YELLOW}[WARNING] CUDA toolkit already installed: ${INSTALLED_VERSION}${NC}"
    echo ""
    echo "If you want to reinstall or change versions, run:"
    echo "  sudo apt-get remove --purge ${CUDA_PKG}"
    echo "  sudo apt-get autoremove"
    echo ""
    echo "Exiting. No changes were made."
    exit 0
fi

echo -e "${GREEN}[OK] No existing CUDA toolkit found. Proceeding with installation.${NC}"
echo ""

# -----------------------------------------------------------------------------
# Step 2: Download and install CUDA keyring
# -----------------------------------------------------------------------------
echo ">>> Downloading CUDA keyring..."
wget -q --show-progress "${KEYRING_URL}" -O "/tmp/${KEYRING_DEB}"

echo ">>> Installing CUDA keyring..."
sudo dpkg -i "/tmp/${KEYRING_DEB}"

echo ">>> Updating apt package list..."
sudo apt-get update -q

# -----------------------------------------------------------------------------
# Step 3: Install CUDA Toolkit (no driver - WSL uses Windows driver)
# -----------------------------------------------------------------------------
echo ""
echo ">>> Installing ${CUDA_PKG} (this may take a few minutes)..."
sudo apt-get install -y "${CUDA_PKG}"

# -----------------------------------------------------------------------------
# Step 4: Update .bashrc with CUDA paths
# -----------------------------------------------------------------------------
echo ""
echo ">>> Updating ~/.bashrc with CUDA paths..."

BASHRC_EXPORT_PATH="export PATH=${CUDA_PATH}/bin:\$PATH"
BASHRC_EXPORT_LD="export LD_LIBRARY_PATH=${CUDA_PATH}/lib64:/usr/lib/wsl/lib:\$LD_LIBRARY_PATH"

# Avoid duplicate entries
if grep -qF "${CUDA_PATH}/bin" ~/.bashrc; then
    echo -e "${YELLOW}[SKIP] PATH already set in ~/.bashrc${NC}"
else
    echo "" >> ~/.bashrc
    echo "# CUDA Toolkit ${CUDA_VERSION}" >> ~/.bashrc
    echo "${BASHRC_EXPORT_PATH}" >> ~/.bashrc
    echo "${BASHRC_EXPORT_LD}" >> ~/.bashrc
    echo -e "${GREEN}[OK] ~/.bashrc updated.${NC}"
fi

# Apply to current session
export PATH="${CUDA_PATH}/bin:$PATH"
export LD_LIBRARY_PATH="${CUDA_PATH}/lib64:/usr/lib/wsl/lib:$LD_LIBRARY_PATH"

# -----------------------------------------------------------------------------
# Step 5: Test nvcc
# -----------------------------------------------------------------------------
echo ""
echo ">>> Testing nvcc..."

if command -v nvcc &> /dev/null; then
    nvcc --version
    echo -e "${GREEN}[OK] nvcc is working correctly.${NC}"
else
    echo -e "${RED}[ERROR] nvcc not found after installation. Check your PATH.${NC}"
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 6: Cleanup
# -----------------------------------------------------------------------------
echo ""
echo ">>> Cleaning up temporary files..."
rm -f "/tmp/${KEYRING_DEB}"
echo -e "${GREEN}[OK] Cleanup done.${NC}"

echo ""
echo "============================================="
echo -e "${GREEN} CUDA Toolkit ${CUDA_VERSION} installed successfully!${NC}"
echo "============================================="
echo ""
echo "IMPORTANT: Run the following to apply PATH changes in this session:"
echo "  source ~/.bashrc"
echo ""
