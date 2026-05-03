#!/usr/bin/bash
source /root/.venv/bin/activate
source /common/scripts/super_echo
gecho "LAUNCH BUILD: ${ROS_DOMAIN_ID}"
cd /root/ros2_ws
source /opt/ros/$ROS_DISTRO/setup.bash

VENV_PATH="/root/.venv"
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
VENV_SITE_PACKAGES="$VENV_PATH/lib/python$PYTHON_VERSION/site-packages"
export PYTHONPATH="$VENV_SITE_PACKAGES:$PYTHONPATH"
echo "====================================="
which python3
which colcon
pip show setuptools packaging
echo "++++++++++++++++++++++++++++++++++++++"

if [ $# -ge 1 ]; then
  echo " colcon build --symlink-install --packages-select $@ --parallel-workers $(($(nproc) - 1))"
  python3 -m colcon build --symlink-install --packages-select $@ --parallel-workers $(($(nproc) - 1))
else
  echo " colcon build --symlink-install --parallel-workers $(($(nproc) - 1))"
  python3 -m colcon build --symlink-install --parallel-workers $(($(nproc) - 1))
fi
source install/setup.bash
