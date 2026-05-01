# ROS2関係の説明

ROSシステムの実行は DOCKER 上のUbuntu 環境内を想定している。
このフォルダ以下がDOCKER上の /root/ros2_ws/src/ros_packages にバインドされる。
バインド関係の詳細は[docker設定](../docker/README_DOCKER.md)参照

## 用語

## フォルダ構成

```
.
|- acs/                 ：ROSパッケージ
|- acsl_interfaces/     ：ROSパッケージ
|- lacalization_sys/    ：ROSパッケージ
|- mavlink_driver/      ：ROSパッケージ
|- multi_v531x/         ：ROSパッケージ
|- switchbot_driver/    ：ROSパッケージ
|- whill_driver/        ：ROSパッケージ
|- README_ROS.md        ：このファイル
```

ROSパッケージの詳細

|フォルダ名（パッケージ名）|概要|
|:--|:--|
| [acs](./acs/README.md) | 自律制御のメインシステムを管理しているパッケージ|
| [acsl_interfaces](./acsl_interfaces/README.md) | カスタムメッセージ型を定義しているパッケージ |
| [localization_sys](./localization_sys/README.md) |  |
| [mavlink_driver](./mavlink_driver/README.md) | フライトコントローラと通信するためのプログラムを管理しているパッケージ |
| [multi_v531x](./multi_v531x/README.md) |  |
| [switchbot_driver](./switchbot_driver/README.md) |  |
| [whill_driver](./whill_driver/README.md) | WHILL model CRを制御するためのプログラムを管理しているパッケージ |

## 実行方法

* 飛行システムの起動

[systemdの設定](../systemd_files/README_SYSTEMD.md)が済んでいれば電源投入で自動的に起動する。

* 個別のパッケージの起動（HOSTから）

```bash
cd ros2/docker
docker compose --env-file <envfile> up common -d
# <envfile> : パッケージに対応したenvfile
```

* 個別のパッケージの起動（DOCKER内で）

```bash
cd ~/ros2_ws/
source install/setup.bash
ros2 run <package_name> <executable_name>
<executable_name> は setup.py でaliasを付けた名前でも良い
```

## 拡張方法

拡張するための環境は[ROS パッケージの拡張](../docker/README_DOCKER.md)参照

### 自作パッケージの作成

```bash
 ros2 pkg create <package_name> --node-name <node_name> --build-type ament_python --dependencies rclpy std_msgs sensor_msgs 
 --maintainer-email ksekiguc@tcu.ac.jp
 --maintainer-name Kazuma SEKIGUCHI
# https://qiita.com/naga-karupi/items/f7e1dc4cfe65e5783181
# rclpy : ROS Client Library for the Python language.
# std_msgs : common_interfaces の一つ
#    https://github.com/ros2/common_interfaces/tree/humble/std_msgs
# sensor_msgs : common_interfaces の一つ
#    https://github.com/ros2/common_interfaces/tree/humble/sensor_msgs
# rosidl_default_generators : 独自メッセージを作る際に必要
#    https://note.com/npaka/n/nd001a9b9e310
```

結果として以下のフォルダが出来上がる。

```bash
./<package_name>
|- <package_name>
    |- __init__.py : 触らない
    |- <node_name>.py : メインで開発するファイル
|- package.xml : 
|- setup.py
|- setup.cfg : 基本触らない
|- test/ : 基本触らない
|- resource/<package_name>  : 触らない
```

[こちら](https://zenn.dev/array/articles/6b7f8d86e6779f#%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E6%A7%8B%E9%80%A0)が詳しい。

### 自動生成ファイル群で意識すべき点

setup.py

```bash
entry_points={
        'console_scripts': [
            '<executable_name> = <package_name>.<node_name>:<function_name>'
        ],
    }
    # <executable_name> : default では <node_name>
    # 
```

### 共有ライブラリの作成

```bash
ros2 pkg create <package_name> --dependencies rclpy --library-name <library_name>
```

## コマンド（DOCKER内）

雛形

```bash
# 一つのノードを立ち上げる場合
ros2 run <package_name> <executable_name> 
ros2 node list # ノード一覧
ros2 node info <node_name> # ノード情報
  # node_nameはデフォルトではpackage_name
ros2 topic list
ros2 topic info <topic_name>
ros2 msg list
ros2 msg info <msg_name>
ros2 launch <launch_file> # 複数ノードをまとめて実行
```

具体例

```bash
# 自律分散系 : namespaceを指定
ros2 launch src/ros_packages/acs/launch/decentralized_launch.py __ns:=/no
ros2 run acs est --ros-args --remap __ns:=/no
ros2 run acs main --ros-args --remap __ns:=/no

# realsenseシリーズのノード実行
# T265起動コマンド
ros2 launch acs rs_launch.py pointcloud.enable:=false enable_gyro:=true enable_accel:=true
ros2 launch realsense2_camera rs_launch.py pointcloud.enable:=false enable_gyro:=true enable_accel:=true

#d435i起動コマンド
ros2 launch realsense2_camera rs_launch.py initial_reset:=true device_type:=d435 depth_module.profile:=1280x720x30 pointcloud.enable:=true enable_gyro:=true

# vl 単体
ros2 run vl53l1x vl53l1x_node # vl53l1xのセンサ取得値表示
ros2 topic echo vl53l1x/range  
# vl複数
ros2 run multi_vl53l1x main # vl　2つ
ros2 run multi_vl53l1x quatro_main # vl ４つ

# フライトコントローラとの通信ノード実行
ros2 run mavlink_driver main

# メガローバー
# micro-ros agent 起動コマンド
ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyUSB-megarover

# Turtlebotノードの起動
ros2 launch acs robot.launch.py
# タートルボット
ros2 run turtlesim turtlesim_node

# WHILL CRノードの起動
ros2 run whill_driver whill

# RPLiDAR ノードの起動
ros2 launch acs rplidar_s1_launch.py

# Motive ノードの起動
ros2 launch acs mocap.launch.py

# コンソールノード実行
ros2 run acs console

# 推定器のノードの実行
ros2 run localization_sys est

# メインプログラムの実行
ros2 run acs main --ros-args -p execplan:=0 # tokyu 指定と等価
ros2 run acs main --ros-args -p execplan:=tokyu # 東急ドローン
ros2 run acs main --ros-args -p execplan:=case_study # 事例研
```

```bash
# 終了時
shutdown
hostshutdown
hostbash ,sudo shutdown -h #↑のでシャットダウンできない場合
```

```bash
# デバイスの使用権限を更新
# デバイスによっては必要な場合があるかも
sudo chmod 777 /dev*
```

動作確認

```bash
ros2 topic echo /fcu/ESC_TELEMETRY_1_TO_4 # モータ見れる
ros2 topic echo /camera/pose/sample # 
ros2 topic echo /fcu/ESC_TELEMETRY_1_TO_4 # 
ros2 topic echo multi_vl53l1x/ceiling_range # 
ros2 topic echo multi_vl53l1x/ground_range # 
```

トラブル対応時

```bash
ls /dev/tty* #フライトコントローラーがつながっているか確認することができる
```

deprecate

```bash
ros2 launch realsense2_camera rs_launch.py #t265の起動
ros2 launch acs mocap.launch.py
src/ros2/mavlink_driver/mavlink_driver/main.py # fcumode(matlabの時は使わない)
src/ros2/acs/acs/ROSnode/Estimator/main.py

#ros2bag 記録コマンド
cd ros2bag_files
ros2 bag record -o [filename] /topic1 /topic2
ros2 bag record -o [filename] /scan_front /scan_behind /rover_odo /tf --ros-args -p execplan:=tokyu
```

## ROSパッケージのビルド

以下に該当するときはビルドしなおす。

* ノードを追加した場合
  * 新しいノードを自作
  * packageを追加した場合
* launchファイルを書き換えた場合

```bash:bash
cd <ROS2_ws>
colcon build source install/setup.bash<package_name>
  --symlink-install : 可能ならシンボリックリンクで
  --packages-select : 指定したパッケージのみのビルド
```

|オプション|概要|
|:--|:--|
|`--symlink-install`|Pythonのシンボリックリンクを作成する (Pyhtonコードを書き変えても再ビルドが不要になる)|
|`--continue-on-error`|ビルドエラーが発生しても続行する|
|`--parallel-workers <NUMBER>`|並列してビルドするパッケージ数を指定する|
|`--packages-select PATH`|ビルドする対象のパッケージを指定する|
|`--base-paths PATH`|ビルドする対象のディレクトリを指定する|
|`--packages-skip-build-finished`|ビルド済みのパッケージはスキップする|
|`--cmake-clean-cache`|これまでのキャッシュファイルを削除して再ビルド|

###

* [ROS2 Foxy Fitzroy](https://docs.ros.org/en/humble/index.html)
* [ROS Noetic Ninjemys](http://wiki.ros.org/noetic)
