#!/bin/bash
cd /home/container || exit 1

# --- 1. FEX-Emu RootFS Setup ---
export FEX_ROOTFS="/opt/fex-emu/share/RootFS/Ubuntu_24_04"

# --- 2. Proton Environment (CRITICAL) ---
export PROTON_PATH="/opt/proton-ge/files"
export PATH="${PROTON_PATH}/bin:${PATH}"
# Point Wine specifically to the GE-Proton libraries
export LD_LIBRARY_PATH="${PROTON_PATH}/lib64:${PROTON_PATH}/lib:${LD_LIBRARY_PATH:-}"

# Tell Wine/Proton exactly what binaries are managing the process
export WINELOADER="${PROTON_PATH}/bin/wine"
export WINESERVER="${PROTON_PATH}/bin/wineserver"

export STEAM_COMPAT_CLIENT_INSTALL_PATH="/home/container"
export STEAM_COMPAT_DATA_PATH="/home/container"
export SteamAppId=0

# --- 3. Display ---
rm -f /tmp/.X99-lock
Xvfb :99 -screen 0 1024x768x16 &
export DISPLAY=:99

# --- 4. Steam SDK Symlink (Fixed Source Path) ---
mkdir -p /home/container/.steam/sdk64
# Ensure we link from the actual SteamCMD install location
ln -sf /usr/lib/games/steamcmd/linux64/steamclient.so /home/container/.steam/sdk64/steamclient.so

# --- 5. Execution ---
echo "Starting Server via FEX..."

# Move to the binary directory so Wine doesn't have to resolve long paths
cd /home/container/R5/Binaries/Win64/ || exit 1

# Direct execution without 'eval' to prevent ShellExecute environment errors
FEXInterpreter "${WINELOADER}" ./WindroseServer-Win64-Shipping.exe -log -STDOUT -nullrhi -nosound -TickRate=10 -LANPLAY -OneThread -SleepCPUOnIdle -NoAsyncLoadingThread
