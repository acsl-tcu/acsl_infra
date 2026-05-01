# docker image関係機能

```bash
build   => dbuild
rename => dcommit
pull/push  => dpull/ dpush
colcon build => build_project
up  => dup
```

## 方針：kasekiguchi/acsl-commonには不要にtagを増やさない

ベース系だけ　humble/humble_x86, jazzy/jazzy_x86 など
image_rf_robot などはbase イメージからプロジェクトのデプロイ時や setupコマンドで作成・更新する

## ベースイメージの作成

```bash
acsl robot rf 44 robot # 何でも良いのでACSLプロジェクトをまずデプロイしその環境内で実行する。
ROS_DISTRO=jazzy dbuild ros:jazzy jazzy  $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_x86
dpush jazzy_x86
ROS_DISTRO=humble dbuild ros:humble humble  $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_x86
dpush humble_x86
ROS_DISTRO=jazzy dbuild arm64v8/ros:jazzy jazzy  $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_arm
dpush jazzy
ROS_DISTRO=humble dbuild arm64v8/ros:humble humble  $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_arm
dpush humble
```

dbuildの第１引数としてイメージを指定しているが実際は使っておらず、dockerfile内でROS_DISTROとアーキテクチャから自動的に使用するイメージを選択している。

できあがったイメージの確認 & image update & image upload
(jazzy_x86の例：最新のbase_ros_x86のdockerfileではapt update & upgradeも入っているので、apt updateの時点でAll packages are up to date.と出るはず)

```bash
dup --image=jazzy_x86 dev # --image=image-tag container-name
# in container
apt update
apt upgrade -y
# outside container
dcommit dev jazzy_x86 # container-name image-tag
dpush jazzy_x86
```

### Third party imageを利用するとき

setupに記述
base imageからproject 用イメージ作成
third party imageをpullしてきて、パッケージ用イメージ作成
build時
image指定
dbuild image_rf_robot slam_toolbox slam_toolbox
dbuild image_rf_robot rplidar rplidar
実行時
imageを指定
DDS指定

### setupファイル例

```bash
#! /bin/bash

source $ACSL_ROS2_DIR/bashrc
echo ${PROJECT}${TARGET}${x86}
echo ${ROS_DOMAIN_ID}
ROS_DISTRO=humble # base image 指定
if [ "$1" == "full" ]; then
  dpull $ROS_DISTRO$x86
  dtag $ROS_DISTRO$x86 image_${PROJECT}${TARGET}${x86}

  dbuild $ROS_DISTRO${x86} slam_toolbox slam_toolbox # base imageをベースにパッケージ特化イメージを作成
  # docker pull microros/micro-ros-agent:jazzy # third party imageを利用する場合
  cd ~/.ssh/
  cat id_*.pub >>authorized_keys
fi

build_project megarover3_bringup megarover_description
```
