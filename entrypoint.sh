#!/bin/bash
# Force FEX to look for its configuration
export HOME=/root
export XDG_DATA_HOME=/root/.local/share
export XDG_CONFIG_HOME=/root/.config

mkdir -p /home/container/.local/share/fex-emu
if [ ! -e "/home/container/.local/share/fex-emu/RootFS" ]; then
    ln -s /opt/fex-emu/share/RootFS /home/container/.local/share/fex-emu/RootFS
fi

# Now run your SteamCMD or install commands
cd /home/container

# Internal Pterodactyl variable replacement
MODIFIED_STARTUP=$(echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')

# 1. Export critical variables
export FEX_TSO=1
export FEX_PASS_THROUGH_USER=1
export USER=container
export HOME=/home/container

# 2. Check if we are already in FEXBash; if not, re-run this script inside it
# --- FEX Architecture Pivot ---
# Check if we are already in x86 mode.
if [ "$(uname -m)" != "x86_64" ]; then
    # Point to the EXACT location in the /opt Safe Zone
    export FEX_ROOTFS='/opt/fex-emu/share/RootFS/Ubuntu_24_04'
    
    echo "Pivoting to x86_64 environment using RootFS at $FEX_ROOTFS..."
    
    # Relaunch the script through FEXBash
    exec FEXBash "$0" "$@"
fi

# --- Everything below this line runs as x86_64 ---

# 3. Fix Open Files Limit
ulimit -n 65535

# 5. Run the startup command directly
# Since we are already in FEXBash, we don't need to call it again in the startup
echo ":/home/container$ ${MODIFIED_STARTUP}"
eval ${MODIFIED_STARTUP}
