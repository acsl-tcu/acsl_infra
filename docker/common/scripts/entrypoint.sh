#! /usr/bin/bash

mapfile -t tmp < <(ls /opt/ros/)
ROS_DISTRO=${tmp[0]}

#############################################################
# docker container 環境内で実行されるファイル
# docker-compose.yml 内で entrypointとして設定
#############################################################

### Define the process when stopping the container
function stop_container_process() {
  if [[ -f /common/scripts/stop ]]; then
    /common/scripts/stop
  fi
  # コンテナ内で生成されたファイルがroot権限になるのを防ぐ処理
  chmod -R a+wr /root/ros2_ws/launcher/rosbags/*
  apt-get clean && apt clean && rm -rf /var/lib/apt/lists/*
  # killall5
  sync
  exit 0
}
trap 'stop_container_process' 15 2
# trap for kill command and Ctrl+C

# container 作成時のみの設定
setuped=$(cat /root/.bashrc | grep ROS_DOMAIN_ID)
if [[ -z $setuped ]]; then
  echo "set path for din "
  chmod -R a+xr /common/scripts
  # path, prompt 設定
  sed -i -e 's/\r//g' /common/scripts/setup_common.sh
  source /common/scripts/setup_common.sh

  # udev起動（devを使うため） : hostでやっていれば不要では？
  sed -i -e 's/\r//g' /common/scripts/run_udev.sh
  source /common/scripts/run_udev.sh
fi

source /common/scripts/super_echo
recho ROS_DOMAIN_ID : $ROS_DOMAIN_ID
export PATH=/common/scripts:${PATH}
source /opt/ros/${ROS_DISTRO}/setup.bash
if [[ -d /root/ros2_ws/install ]]; then
  source /root/ros2_ws/install/local_setup.bash
  source /root/ros2_ws/install/setup.bash
fi
gecho ===== Ready! =====
echo $PATH
if [ $# -eq 0 ]; then
  echo "Press Ctrl+C to stop the container."
  read
else
  $@
  # "でくくるとslam_toolboxが動かない。
  # "$@" &
  # child_pid=$!
  # 子プロセスが終わるまで待つ
  # wait "$child_pid"
fi
rm -f $ACSL_WORK_DIR/launcher/launch_dev.sh
stop_container_process
