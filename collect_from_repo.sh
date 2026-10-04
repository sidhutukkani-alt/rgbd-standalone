#!/usr/bin/env bash
# Run ONCE on the PC that has the working multi-slam-simulation repo.
# Copies every file the standalone setup needs out of the repo into this folder, so the
# folder can then be zipped and sent without the repo. Nothing in the repo is changed.
#   REPO=/other/path bash collect_from_repo.sh      (default: ~/projects/multi-slam-simulation)
set -eo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-$HOME/projects/multi-slam-simulation}"
PKG="$REPO/src/multi_slam_uav_sim"

if [ ! -d "$PKG" ]; then
  echo "Cannot find $PKG. Set REPO=/path/to/multi-slam-simulation" >&2
  exit 1
fi
for f in models/iris_apm_rgbd_only worlds/low_indoor_apm_rgbd_only.sdf \
         params/vision_mavros_guided.parm params/iris_roll_stability.parm \
         config/mavros_apm_rgbd.yaml config/mavros_validation_pluginlists.yaml; do
  if [ ! -e "$PKG/$f" ]; then
    echo "Missing in repo: $PKG/$f" >&2
    echo "(for the model/world, run setup_rgbd_only.sh / make_rgbd_only_model.py first)" >&2
    exit 1
  fi
done

mkdir -p "$HERE"/{worlds,models,params,config,logs,ws/src}

rm -rf "$HERE/models/iris_apm_rgbd_only"
cp -rL "$PKG/models/iris_apm_rgbd_only" "$HERE/models/"
cp -L "$PKG/worlds/low_indoor_apm_rgbd_only.sdf" "$HERE/worlds/"
cp -L "$PKG/params/vision_mavros_guided.parm" "$PKG/params/iris_roll_stability.parm" "$HERE/params/"
cp -L "$PKG/config/mavros_apm_rgbd.yaml" "$PKG/config/mavros_validation_pluginlists.yaml" "$HERE/config/"

BRIDGE="$(find -L "$REPO/src" -type d -name d435i_rgbd_bridge_cpp 2>/dev/null | head -n1)"
if [ -z "$BRIDGE" ]; then
  echo "Could not find the d435i_rgbd_bridge_cpp package source under $REPO/src" >&2
  exit 1
fi
rm -rf "$HERE/ws/src/d435i_rgbd_bridge_cpp"
cp -rL "$BRIDGE" "$HERE/ws/src/"
echo "Copied camera bridge package from: $BRIDGE"

echo
echo "== Does the camera bridge depend on other packages from the repo? =="
python3 - "$REPO/src" "$HERE/ws/src/d435i_rgbd_bridge_cpp/package.xml" <<'PY'
import os, re, sys
repo_src, bridge_xml = sys.argv[1], sys.argv[2]
names = set()
for root, _dirs, files in os.walk(repo_src, followlinks=True):
    if "package.xml" in files:
        txt = open(os.path.join(root, "package.xml"), encoding="utf-8", errors="ignore").read()
        m = re.search(r"<name>\s*([^<\s]+)\s*</name>", txt)
        if m:
            names.add(m.group(1))
txt = open(bridge_xml, encoding="utf-8", errors="ignore").read()
self_name = re.search(r"<name>\s*([^<\s]+)\s*</name>", txt).group(1)
deps = sorted(set(re.findall(r"<(?:depend|build_depend|exec_depend|buildtool_depend)>\s*([^<\s]+)\s*<", txt)))
print("package:", self_name)
print("dependencies:", ", ".join(deps) or "(none)")
internal = [d for d in deps if d in names and d != self_name]
if internal:
    print("WARNING: these dependencies are other packages from the repo and must ALSO be copied:")
    for d in internal:
        print("   -", d)
else:
    print("OK: no dependencies on other repo packages.")
PY

echo
echo "== Versions (tell the other laptop's owner to match these) =="
{
  echo "date: $(date -Is)"
  echo "ardupilot: $(git -C "${ARDUPILOT_DIR:-$HOME/ardupilot}" describe --tags --always 2>&1 | head -1)"
  echo "ardupilot_gazebo: $(git -C "${ARDUPILOT_GAZEBO_DIR:-$HOME/ardupilot_gazebo}" rev-parse --short HEAD 2>&1 | head -1)"
  echo "gazebo: $(gz sim --versions 2>&1 | head -1)"
  echo "ubuntu: $(lsb_release -ds 2>&1)"
  echo "ros: ${ROS_DISTRO:-not sourced}"
  echo "repo commit: $(git -C "$REPO" rev-parse --short HEAD 2>&1 | head -1)"
} | tee "$HERE/VERSIONS.txt"

echo
echo "== How the original script handles the Gazebo clock (paste this back if unsure) =="
grep -n -i "clock" "$PKG/scripts/run_apm_sensor_stack.sh" | head -20 || true

echo
echo "Done. Next: build the camera bridge:"
echo "  cd $HERE/ws && source /opt/ros/humble/setup.bash && colcon build --symlink-install"
