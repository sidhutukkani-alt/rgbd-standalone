#!/usr/bin/env bash
# Sourced by every run script. Sets up ROS, Gazebo search paths and ArduPilot locations.
# Override the two locations if yours are different:
#   export ARDUPILOT_DIR=/path/to/ardupilot
#   export ARDUPILOT_GAZEBO_DIR=/path/to/ardupilot_gazebo

STANDALONE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export STANDALONE_DIR
export ARDUPILOT_DIR="${ARDUPILOT_DIR:-$HOME/ardupilot}"
export ARDUPILOT_GAZEBO_DIR="${ARDUPILOT_GAZEBO_DIR:-$HOME/ardupilot_gazebo}"

source /opt/ros/humble/setup.bash
if [ -f "$STANDALONE_DIR/ws/install/setup.bash" ]; then
  source "$STANDALONE_DIR/ws/install/setup.bash"
fi

# Gazebo must find our model/world and the ArduPilot models (iris_with_standoffs lives there),
# and the ArduPilot plugin library.
export GZ_SIM_RESOURCE_PATH="$STANDALONE_DIR/worlds:$STANDALONE_DIR/models:$ARDUPILOT_GAZEBO_DIR/worlds:$ARDUPILOT_GAZEBO_DIR/models:${GZ_SIM_RESOURCE_PATH:-}"
export GZ_SIM_SYSTEM_PLUGIN_PATH="$ARDUPILOT_GAZEBO_DIR/build:${GZ_SIM_SYSTEM_PLUGIN_PATH:-}"

if [ ! -d "$ARDUPILOT_GAZEBO_DIR/models/iris_with_standoffs" ]; then
  echo "WARNING: $ARDUPILOT_GAZEBO_DIR/models/iris_with_standoffs not found (ardupilot_gazebo missing?)" >&2
fi
if [ ! -x "$ARDUPILOT_DIR/build/sitl/bin/arducopter" ]; then
  echo "WARNING: $ARDUPILOT_DIR/build/sitl/bin/arducopter not found (ArduPilot SITL not built?)" >&2
fi
