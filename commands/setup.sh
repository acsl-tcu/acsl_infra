#! /usr/bin/bash +x

ACSL_WORK_DIR="$(pwd)"
ACSL_ROS2_DIR=$(
  cd $(dirname $0)
  cd ../
  pwd
)
# ros node (＝　コンテナ)　の立ち上げ
if [ $# -ge 1 ]; then
  PROJECT=$1
  sudo chmod -R a+x $ACSL_ROS2_DIR/docker/common/

  $ACSL_ROS2_DIR/commands/setup_bashrc $ACSL_WORK_DIR $@
  $ACSL_ROS2_DIR/commands/setup_udev $ACSL_ROS2_DIR/docker/common/rules/$PROJECT.rules
  echo "project_launch_${PROJECT}_sh"
  if [[ -n $(find $ACSL_ROS2_DIR/commands | grep project_launch_${PROJECT}_sh) ]]; then
    sed -i "s|ACSL_ROS2_DIR|$ACSL_ROS2_DIR|g" project_launch_${PROJECT}_sh >project_launch.sh
  else
    cp $ACSL_ROS2_DIR/commands/project_launch.sh project_launch.sh
  fi
  $ACSL_ROS2_DIR/commands/setup_systemd $ACSL_ROS2_DIR/commands/project_launch.sh
  bash # source .bashrc忘れの予防
else
  source $ACSL_ROS2_DIR/docker/common/scripts/super_echo
  recho "Require PROJECT name"
fi
