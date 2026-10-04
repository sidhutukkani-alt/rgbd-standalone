#!/usr/bin/env bash
# Terminal 4: camera mount transform + RTAB-Map (with RViz and rtabmap_viz).
# Uses the flight controller's odometry, because RTAB-Map's own visual odometry lost
# tracking in this plain indoor scene.
set -eo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

# Where the map database is saved. Override: DB_PATH=/some/path/rtabmap.db
DB_PATH="${DB_PATH:-$HOME/rtabmap_maps/rtabmap.db}"
mkdir -p "$(dirname "$DB_PATH")"
# By default the old database is deleted at start. KEEP_DB=1 keeps it.
if [ "${KEEP_DB:-0}" = "1" ]; then RTAB_ARGS=""; else RTAB_ARGS="-d"; fi

# base_link -> d435i_link (camera mount from the model: 0.20 m forward, 0.02 m up)
ros2 run tf2_ros static_transform_publisher --x 0.20 --y 0.0 --z 0.02 \
  --roll 0 --pitch 0 --yaw 0 --frame-id base_link --child-frame-id d435i_link &
TF_PID=$!
trap 'kill $TF_PID 2>/dev/null || true' EXIT

ros2 launch rtabmap_launch rtabmap.launch.py \
  rgb_topic:=/front/d435i/color/image_raw \
  depth_topic:=/front/d435i/aligned_depth_to_color/image_raw \
  camera_info_topic:=/front/d435i/color/camera_info \
  frame_id:=base_link \
  visual_odometry:=false odom_topic:=/mavros/local_position/odom \
  map_frame_id:=rtabmap_map \
  use_sim_time:=true approx_sync:=true qos:=2 \
  rviz:=true rtabmap_viz:=true \
  database_path:="$DB_PATH" \
  args:="$RTAB_ARGS"
