#!/bin/bash
cd /home/container || exit 1

# --- 1. FEX-Emu RootFS Setup ---
# We must point FEX to the exact location of the RootFS files
export FEX_ROOTFS="/opt/fex-emu/share/RootFS/Ubuntu_24_04"

# --- 2. Proton Environment ---
export PROTON_PATH="/opt/proton-ge/files"
export PATH="${PROTON_PATH}/bin:${PATH}"
export LD_LIBRARY_PATH="${PROTON_PATH}/lib64:${PROTON_PATH}/lib:${LD_LIBRARY_PATH:-}"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="/home/container"
export STEAM_COMPAT_DATA_PATH="/home/container"

# --- 3. Display ---
rm -f /tmp/.X99-lock
Xvfb :99 -screen 0 1024x768x16 &
export DISPLAY=:99

# --- 4. System Info (Fixed Syntax) ---
echo "--- System Info ---"
FEXInterpreter --version
FEXInterpreter ${PROTON_PATH}/bin/wine --version

mkdir -p /home/container/.steam/sdk64
ln -sf /home/container/steamclient.so /home/container/.steam/sdk64/steamclient.so

# --- 5. Execution ---
echo "Starting Server via FEX..."
# We use FEXInterpreter to run the Proton version of Wine
eval "FEXInterpreter ${PROTON_PATH}/bin/wine {{STARTUP}}"
