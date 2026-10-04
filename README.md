# RGB-D SLAM drone (standalone, no multi-slam-simulation repo needed)

A simulated quadcopter with an RGB-D camera in a Gazebo indoor room. RTAB-Map builds a
live 3D map while you fly the drone yourself. The files here were taken from the
multi-slam-simulation project, but this folder runs without that repo.

## Needs on the machine

- Ubuntu 22.04, ROS 2 Humble, Gazebo Harmonic (`gz sim --versions` shows 8.x)
- ArduPilot with SITL built: `~/ardupilot/build/sitl/bin/arducopter` must exist
- ardupilot_gazebo built (plugin in `~/ardupilot_gazebo/build`, models in
  `~/ardupilot_gazebo/models`, including `iris_with_standoffs`)
- ROS packages:

      sudo apt install ros-humble-mavros ros-humble-mavros-extras ros-humble-rtabmap-ros \
        ros-humble-ros-gz-bridge ros-humble-tf2-ros python3-colcon-common-extensions
      pip3 install --user MAVProxy pymavlink

  MAVROS also needs its GeographicLib data: `sudo /opt/ros/humble/lib/mavros/install_geographiclib_datasets.sh`

If ArduPilot or ardupilot_gazebo are not in your home folder, set `ARDUPILOT_DIR` and
`ARDUPILOT_GAZEBO_DIR` (see `env.sh`). `VERSIONS.txt` lists the versions the setup was
made with; matching them avoids surprises.

## One-time build of the camera bridge

    cd ws
    source /opt/ros/humble/setup.bash
    colcon build --symlink-install
    cd ..

If it complains about a missing library, install it with apt (the bridge talks to
Gazebo, so the Gazebo Harmonic development packages it uses may be needed:
`libgz-transport13-dev` and `libgz-msgs10-dev`).

## Run (one terminal each, in this order, each started from this folder)

    bash 1_gazebo.sh          # Gazebo window with the drone. Wait until it has loaded.
    bash 2_flight_stack.sh    # clock bridge, ArduPilot SITL, MAVROS
    bash 3_camera_bridge.sh   # camera topics under /front/d435i/
    bash 4_slam.sh            # RTAB-Map, rtabmap_viz and RViz

`2_flight_stack.sh` waits for MAVROS to connect and then asks the flight controller to send
its position data (the `set_stream_rate` request); without that, `/mavros/local_position/odom`
stays silent and RTAB-Map shows nothing. It prints "Odometry is flowing" when done. The drone
needs about a minute after start-up before it has a GPS position estimate.

First run on a new machine: `WIPE_EEPROM=1 bash 2_flight_stack.sh` (clears stored ArduPilot
parameters so the included defaults apply). `USE_NVIDIA=0` skips the NVIDIA render offload
on machines without an NVIDIA GPU. The map is saved to `~/rtabmap_maps/rtabmap.db` and
replaced at each start; `KEEP_DB=1 bash 4_slam.sh` keeps it.

Checks before flying (in a free terminal, after `source /opt/ros/humble/setup.bash`):

    ros2 topic hz /mavros/local_position/odom                    # about 10 Hz
    ros2 topic hz /front/d435i/aligned_depth_to_color/image_raw  # not empty
    ros2 run tf2_ros tf2_echo base_link d435i_link               # 0.2 0 0.02

## Fly the drone

ArduPilot allows one client per port and MAVROS uses one, so connect MAVProxy to a free one.
Try 5763, then 5762, then 5760:

    mavproxy.py --master=tcp:127.0.0.1:5763

At the MAVProxy prompt, one line at a time, waiting for the prompt each time:

    mode guided
    arm throttle
    takeoff 2
    velocity 1 0 0                          # 1 m/s towards north (world frame), stops after a few seconds
    long CONDITION_YAW 90 30 1 1 0 0 0      # turn 90 degrees clockwise at 30 deg/s
    mode land

`yaw` is not a MAVProxy command; use the `long CONDITION_YAW` line (use -1 for the first 1
to turn counter-clockwise). Fly and turn slowly and pause after each turn so the map keeps
up. Point the camera at objects and walls, not at plain floor or horizon.

## Troubleshooting

- Gazebo cannot find the model: check `echo $GZ_SIM_RESOURCE_PATH` in the terminal after
  `source env.sh`, and that `models/iris_apm_rgbd_only` exists.
- ArduPilot does not connect / drone does not respond: read `logs/sitl.log` and `logs/mavros.log`.
- Everything is stuck at "Waiting for /clock": the Gazebo clock may have a different name
  in your Gazebo version. Run `gz topic -l | grep -i clock`, then change the topic in
  `2_flight_stack.sh` (the `ros_gz_bridge` line) to match.
- Map stays empty: check the depth topic above and that terminals 1 to 4 are all running.
- Scripts are written for bash; if one fails with "unbound variable" while loading ROS,
  open it and make sure it says `set -eo pipefail` (not `-u`).

## Credits

The drone model, world, parameter files, MAVROS configuration files and the camera bridge
package (`ws/src/d435i_rgbd_bridge_cpp`) come from
https://github.com/Zhuyicheng-HIT/multi-slam-simulation (Apache-2.0, see `LICENSE`).
Changes made here: the lidar and optical-flow sensors were removed from the drone model and
world, and new run scripts were added.

## Credits

The drone model, world, parameter files, MAVROS configuration files and the camera bridge
package (`ws/src/d435i_rgbd_bridge_cpp`) come from
https://github.com/Zhuyicheng-HIT/multi-slam-simulation (Apache-2.0, see `LICENSE`).
Changes made here: the lidar and optical-flow sensors were removed from the drone model and
world, and new run scripts were added.
