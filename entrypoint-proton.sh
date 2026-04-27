#!/bin/bash

# Navigate to the container home
cd /home/container || exit 1

# --- 1. FEX-Emu Environment Setup ---
# Ensure the RootFS is linked so FEX knows how to translate x86_64
if [ ! -d "$HOME/.local/share/fex-emu/RootFS" ]; then
    echo "Configuring FEX RootFS link..."
    mkdir -p "$HOME/.local/share/fex-emu"
    ln -s /opt/fex-emu/share/RootFS "$HOME/.local/share/fex-emu/RootFS"
fi

# --- 2. Proton / Steam Mimicry ---
# GE-Proton 9+ requires these to not exit immediately
export STEAM_COMPAT_CLIENT_INSTALL_PATH="/home/container"
export STEAM_COMPAT_DATA_PATH="/home/container"
export WINEPREFIX="/home/container/.wine"

# --- 3. Display Setup ---
# Clean up old locks and start Xvfb for headless Unreal Engine support
rm -f /tmp/.X99-lock
Xvfb :99 -screen 0 1024x768x16 &
export DISPLAY=:99

# --- 4. Print Version Info (For Troubleshooting) ---
echo "System Info:"
FEXInterpreter --version
FEXInterpreter ${PROTON_PATH}/bin/wine --version

# --- 5. Execution ---
# Define the internal GE-Proton paths explicitly
export PROTON_PATH="/opt/proton-ge/files"
export PATH="${PROTON_PATH}/bin:${PATH}"
export LD_LIBRARY_PATH="${PROTON_PATH}/lib64:${PROTON_PATH}/lib:${LD_LIBRARY_PATH:-}"

echo "Starting Windrose Server via FEX..."
# Use the full path to wine to be 100% certain
eval "FEXInterpreter ${PROTON_PATH}/bin/wine ${MODIFIED_STARTUP#wine }"

# --- 6. Cleanup ---
# Ensure Xvfb dies when the server stops
pkill Xvfb
