#!/usr/bin/env bash
# Terminal 2: clock bridge + ArduPilot SITL + MAVROS (what the original repo script started).
# Start this after the Gazebo window from 1_gazebo.sh is up. Ctrl+C stops all three.
# First run on a new machine: WIPE_EEPROM=1 bash 2_flight_stack.sh
set -eo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

LOG_DIR="$STANDALONE_DIR/logs"
mkdir -p "$LOG_DIR"
pids=()
cleanup() {
  for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
}
trap cleanup EXIT INT TERM

# Wait for Gazebo to publish its clock (up to 60 s).
echo "Waiting for Gazebo /clock ..."
ok=0
for _ in $(seq 1 60); do
  if gz topic -l 2>/dev/null | grep -q "^/clock$"; then ok=1; break; fi
  sleep 1
done
if [ "$ok" = "0" ]; then
  echo "WARNING: no /clock topic seen from Gazebo; continuing anyway (see README, 'Clock')." >&2
fi

# Gazebo clock -> ROS /clock, needed because the nodes run with use_sim_time:=true.
ros2 run ros_gz_bridge parameter_bridge "/clock@rosgraph_msgs/msg/Clock[gz.msgs.Clock" \
  >"$LOG_DIR/clock_bridge.log" 2>&1 &
pids+=("$!")
sleep 2

# ArduPilot SITL: same arguments and default-parameter files as the original script.
WIPE_ARG=""
if [ "${WIPE_EEPROM:-0}" = "1" ]; then WIPE_ARG="-w"; fi
DEFAULTS="Tools/autotest/default_params/copter.parm"
DEFAULTS="$DEFAULTS,Tools/autotest/default_params/gazebo-iris.parm"
DEFAULTS="$DEFAULTS,$STANDALONE_DIR/params/vision_mavros_guided.parm"
DEFAULTS="$DEFAULTS,$STANDALONE_DIR/params/iris_roll_stability.parm"

(
  cd "$ARDUPILOT_DIR"
  # shellcheck disable=SC2086
  exec build/sitl/bin/arducopter -S $WIPE_ARG --model JSON --speedup 1 --slave 0 \
    --defaults "$DEFAULTS" --sim-address=127.0.0.1 -I0
) >"$LOG_DIR/sitl.log" 2>&1 &
pids+=("$!")
echo "SITL started (log: $LOG_DIR/sitl.log)"
sleep 5

# MAVROS with the same three parameter files as the original script.
ros2 run mavros mavros_node --ros-args \
  -p use_sim_time:=true \
  --params-file /opt/ros/humble/share/mavros/launch/apm_config.yaml \
  --params-file "$STANDALONE_DIR/config/mavros_validation_pluginlists.yaml" \
  --params-file "$STANDALONE_DIR/config/mavros_apm_rgbd.yaml" \
  >"$LOG_DIR/mavros.log" 2>&1 &
pids+=("$!")

echo "Waiting for MAVROS to connect to the flight controller ..."
connected=0
for _ in $(seq 1 40); do
  if grep -q 'CON: Got HEARTBEAT, connected' "$LOG_DIR/mavros.log" 2>/dev/null; then
    echo "MAVROS connected."
    connected=1
    break
  fi
  sleep 1
done

# ArduPilot only sends position/attitude data if it is asked to. Without this request
# /mavros/local_position/odom stays silent and RTAB-Map never gets odometry.
# (Same as: ros2 service call /mavros/set_stream_rate mavros_msgs/srv/StreamRate
#  "{stream_id: 0, message_rate: 10, on_off: true}")
if [ "$connected" = "1" ]; then
  echo "Requesting data streams from the flight controller ..."
  odom_ok=0
  for _ in $(seq 1 30); do
    timeout 15 ros2 service call /mavros/set_stream_rate mavros_msgs/srv/StreamRate \
      "{stream_id: 0, message_rate: 10, on_off: true}" >>"$LOG_DIR/stream_rate.log" 2>&1 || true
    if timeout 10 ros2 topic echo --once /mavros/local_position/odom \
         --field header.frame_id >/dev/null 2>&1; then
      odom_ok=1
      break
    fi
    sleep 5
  done
  if [ "$odom_ok" = "1" ]; then
    echo "Odometry is flowing. Flight stack is up (Ctrl+C here stops it)."
  else
    echo "WARNING: /mavros/local_position/odom is still silent. See $LOG_DIR/stream_rate.log and sitl.log;" >&2
    echo "         the drone may still be waiting for its GPS position estimate." >&2
  fi
else
  echo "WARNING: MAVROS did not connect within 40 s; see $LOG_DIR/mavros.log and sitl.log." >&2
fi

wait
