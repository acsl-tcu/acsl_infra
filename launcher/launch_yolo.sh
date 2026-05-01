#! /usr/bin/bash

YOLOv8を使用するための環境のインストール
参考サイト:[https://docs.ultralytics.com/ja/quickstart/#use-ultralytics-with-cli]
$ pip install ultralytics


RICOH THETAを使うための環境構築，かなり苦戦したので以下のコマンドだけではうまくいかないかも，参考までに
現状の問題点：/libuvc-theta/buildに移動してから~/libuvc-theta-sample/gst/gst_loopbackを打たないとTHETAが認識されないこと，環境構築をやり直せばうまくいくかも，現状このやり方でできなくなったことはないので保留中
参考サイト2つ：[https://qiita.com/onushi-k/items/8440ba1add465ba9c38b], [https://codetricity.github.io/theta-linux/]
openCVの構築
$ sudo apt install -y build-essential cmake libgtk2.0-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev libusb-1.0-0 libjpeg-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev v4l2loopback-dkms
$ wget -O opencv.zip https://github.com/opencv/opencv/archive/3.4.14.zip
$ unzip opencv.zip
$ cd opencv-3.4.14
$ mkdir build
$ cd build
$ cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
$ make -j4
$ sudo make install
libuvcの構築
$ git clone https://github.com/libuvc/libuvc
$ cd libuvc
$ mkdir build
$ cd build
$ cmake ..
$ make && sudo make install
libuvc-thetaの構築
$ git clone https://github.com/ricohapi/libuvc-theta
$ cd libuvc-theta
$ mkdir build
$ cd build
$ cmake ..
$ make
$ sudo make install
$ sudo ldconfig
libuvc-theta-sampleの構築
$ cd
$ git clone https://github.com/codetricity/libuvc-theta-sample
$ cd ~/libuvc-theta-sample/gst
$ make clean
$ make
v4l2loopbackの構築
$ git clone https://github.com/umlaeute/v4l2loopback.git
$ cd v4l2loopback
$ make 
$ sudo make install
$ sudo depmod -a
RICOH THETAの起動(MainCommands.txtと同様)
THETAを接続したらModeボタンを押してLiveモードにする
$ sudo modprobe v4l2loopback # 仮想デバイスの設定
# v4l2-ctl --list-devices # 仮想デバイスのリスト
# sudo modprobe -r v4l2loopback # 仮想デバイスの削除
$ cd ~/libuvc-theta/build # ディレクトリ移動
$ ~/libuvc-theta-sample/gst/gst_loopback --format 2K # Live streamingの実行

Pythonを用いたROS2，カスタムメッセージを使用
参考サイト：[https://qiita.com/myasu/items/3a026697f535183e12e8]
$ cd ~/MovingSignage/vehicle/jetson/ros2_ws # ここに作成
/ros2_ws/src/custom_msg：カスタムメッセージの定義，MATLABのカスタムメッセージ設定と合わせる必要あり
/ros2_ws/src/program/pos.py：YOLOv8を用いた歩行者の角度推定および推定角度のPublishをするプログラム
使用コマンド
$ ros2 run yolo pos