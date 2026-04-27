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
fex-emu --version
wine --version

# --- 5. Execution ---
# Replace {{LAUNCH_COMMAND}} with the startup string from Pterodactyl
# We use 'eval' so that environment variables passed from the panel are parsed correctly.

# Modified Launch Command to ensure it runs through the virtual display
MODIFIED_STARTUP=$(echo "{{STARTUP}}" | sed 's/{{/$\{/g' | sed 's/}}/}/g')

echo "Starting Server..."
eval "${MODIFIED_STARTUP}"

# --- 6. Cleanup ---
# Ensure Xvfb dies when the server stops
pkill Xvfb
