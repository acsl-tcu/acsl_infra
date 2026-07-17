#! /usr/bin/bash

if [ ${HOSTNAME:0:1} == "D" ]; then
  # docker container 内の場合
  cd /root/ros2_ws
else
  # SBC 内の場合
  #cd /home/$USER/ros2
  cd $ACSL_WORK_DIR
fi
