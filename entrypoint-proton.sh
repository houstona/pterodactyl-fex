#!/bin/bash
cd /home/container || exit 1

# --- 1. FEX-Emu Setup ---
export FEX_ROOTFS="/opt/fex-emu/share/RootFS/Ubuntu_24_04"
mkdir -p $HOME/.fex-emu/
echo "{\"Config\": {\"RootFS\": \"$FEX_ROOTFS\"}}" > $HOME/.fex-emu/Config.json

# --- 2. Proton & Library Pathing ---
export PROTON_PATH="/opt/proton-ge/files"
export PATH="${PROTON_PATH}/bin:${PATH}"
export WINELOADER="${PROTON_PATH}/bin/wine"
export WINESERVER="${PROTON_PATH}/bin/wineserver"

# Point to the x86_64-unix drivers explicitly
export PROTON_UNIX_LIB="${PROTON_PATH}/lib64/wine/x86_64-unix"
export LD_LIBRARY_PATH="${PROTON_UNIX_LIB}:${PROTON_PATH}/lib64:${PROTON_PATH}/lib:${LD_LIBRARY_PATH}"

# --- 3. Display ---
rm -f /tmp/.X99-lock
Xvfb :99 -screen 0 1024x768x16 &
export DISPLAY=:99

# --- 4. Execution ---
echo "Starting Server via FEX..."

# Disable Mono/Gecko popups and force built-in DirectX handlers
export WINEDLLOVERRIDES="mscoree,mshtml=b;wine-mono=d;wine-gecko=d"

MODIFIED_STARTUP=$(echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

eval ${MODIFIED_STARTUP}
