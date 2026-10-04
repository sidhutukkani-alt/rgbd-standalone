#!/usr/bin/env bash
# Terminal 1: Gazebo with the RGB-D-only drone in the indoor world.
set -eo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

WORLD="$STANDALONE_DIR/worlds/low_indoor_apm_rgbd_only.sdf"
if [ ! -f "$WORLD" ]; then
  echo "World file missing: $WORLD  (run collect_from_repo.sh on the original PC first)" >&2
  exit 1
fi

# Laptop with NVIDIA + integrated GPU: render on the NVIDIA GPU. USE_NVIDIA=0 to skip.
if [ "${USE_NVIDIA:-1}" = "1" ]; then
  export __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only
fi

exec gz sim -r -v 2 --render-engine-gui ogre2 "$WORLD"
