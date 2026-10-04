#!/usr/bin/env bash
# Terminal 3: RGB-D camera bridge (Gazebo camera -> ROS image, depth, camera_info and TF).
# Uses the d435i_rgbd_bridge_cpp package copied into ws/ by collect_from_repo.sh.
# One-time build:  cd ws && source /opt/ros/humble/setup.bash && colcon build --symlink-install
set -eo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

if [ ! -f "$STANDALONE_DIR/ws/install/setup.bash" ]; then
  echo "The camera bridge is not built yet. Run:" >&2
  echo "  cd $STANDALONE_DIR/ws && source /opt/ros/humble/setup.bash && colcon build --symlink-install" >&2
  exit 1
fi

exec ros2 run d435i_rgbd_bridge_cpp d435i_rgbd_bridge --ros-args \
  -p use_sim_time:=true -p gz_prefix:=/front/d435i/gz -p ros_prefix:=/front/d435i \
  -p camera_link_frame:=d435i_link -p depth_encoding:=16UC1 \
  -p min_depth_m:=0.105 -p max_depth_m:=10.0 -p sync_queue_depth:=2 \
  -p qos_depth:=1 -p qos_reliability:=best_effort -p enable_pointcloud:=false
