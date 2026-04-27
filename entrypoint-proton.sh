#!/bin/bash
cd /home/container || exit 1

# --- 1. FEX-Emu User Override ---
export FEX_ROOTFS="/opt/fex-emu/share/RootFS/Ubuntu_24_04"

# Create the user-level config folder
mkdir -p $HOME/.fex-emu/

# Create a local Config.json that EXPLICITLY sets the RootFS
echo "{
  \"Config\": {
    \"RootFS\": \"$FEX_ROOTFS\"
  }
}" > $HOME/.fex-emu/Config.json


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
ls -d /opt/fex-emu/share/RootFS/Ubuntu_24_04
cat $HOME/.fex-emu/Config.json

# Force Wine to use the built-in version of .NET and HTML components
export WINEDLLOVERRIDES="mscoree,mshtml=b"

# Disable the install popups that can hang headless servers
export WINEDLLOVERRIDES="$WINEDLLOVERRIDES; wine-mono=disabled; wine-gecko=disabled"

MODIFIED_STARTUP=$(echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"
eval ${MODIFIED_STARTUP}
