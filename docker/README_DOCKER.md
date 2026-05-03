# README for Docker system

First read [README_SYSTEM.md](../README_SYSTEM.md) and complete the setup section

## Terminology

Refer to [README_SYSTEM.md](../README_SYSTEM.md) for the common terminologies.

<https://docs.docker.jp/engine/reference/commandline/compose.html>

|Term|Meaning|
|-|-|
|image| docker image (preserve on a HDD)|
|container| instance build up from image|
|:--|:--|
|docker-compose.yml|blueprint for Docker image/contaier <br>- env setting for build image<br>- env and mount setting for container up|
|dockerfile|blueprint for docker image<br>イメージ構築に必要なaptやROSパッケージのインストールコマンドが記述されている|
|docker ディレクトリ|Dockerコンテナ内にバインドされるdirectory．<br>ROSのセットアップファイルやコンテナを起動するときに最初に呼び出されるスクリプトが格納されている|

## フォルダ構成

```
.
|- common/              ：DOCKERイメージ共通の設定フォルダ
|- ros2_autoware/       ：Autoware用DOCKER設定フォルダ
|- docker-compose.yml   ：DOCKERイメージ構築・起動時の設定（フォルダのバインドなど）
|- README.md 　　　　　　：このファイル
|- env.**               ：ROSパッケージ毎の設定ファイル
```

## 実行方法

* 飛行システムの起動

[systemdの設定](../systemd_files/README_SYSTEMD.md)が済んでいれば電源投入で自動的に起動する。

* 開発用コンテナの起動

以下のコマンドでdevコンテナを作り、その中に入れる

 ```bash:bash
  cd ~/ros2/docker/
  docker compose up common -d
  docker compose exec common bash
 ```

* VScodeでLocalからアクセス
   1. LocalでVScodeを開きextension （Remote-SSH、　　Docker、　　Dev Contaiers）を入れる
   2. 左下の"Open a Remote Window" からConnect to Host で接続する（新規の場合はAdd New SSH HostでHostを追加する）
   1. VScode上のDockerメニュー（左に並んでいるクジラのロゴ）を開く
   1. コンテナ一覧で接続したいコンテナを選び右クリック
   1. VScodeでアタッチするを選択する

## Docker system セットアップ

[Docker JP ドキュメンテーション](https://matsuand.github.io/docs.docker.jp.onthefly/get-docker/)
に従ってDocker engineまたはDocker desktopをインストールする．

* Linux系のインストールの際は必ずページ末の次のステップも忘れずに実施すること

## Docker 運用

docker-compose.yml に従ってイメージを作成する。

**docker-compose内に渡せる環境変数とその意味**

|環境変数|意味|デフォルト値|
|-|-|-|
|TARGET_STAGE|dockerfile内のstage (asで指定しているもの)。 できあがるイメージのタグ|base: ros2_py3|
|||common: realsense_ros2|
|HOSTNAME|containerのホスト名|base: [base]　　common: 無し|
|BASE_IMAGE|buildの元となるイメージ|base:arm64v8/ros|
|||common:kasekiguchi/acsl-base:ros2_py3|
|CONTAINER_NAME|コンテナの名前|base: 無効　　common: dev|
|TARGET_FILE|dockerfile名|base: dockerfile.baseで固定　　common:dockerfile.common|
|ROS_LAUNCH|コンテナ起動時に実行するファイル|base:無効　　common:launch-void.sh|
|ID|ROS_DOMAIN_ID|9|

### Docker image の build

```bash
docker compose build base
docker compose build drone
docker compose build vehicle
TARGET_TAG=drone_ros2 TAG=drone_build docker compose build common
TARGET_TAG=vehicle_ros2 TAG=vehicle_build docker compose build common
docker login
docker push kasekiguchi/acsl-base:ros2_py3
docker push kasekiguchi/acsl-common:drone_ros2
docker push kasekiguchi/acsl-common:drone_build --no-cache
docker push kasekiguchi/acsl-common:vehicle_build --no-cache
```

**Build 時の文法**

```bash
docker compose --env-file <envfile> build <service_name> --no-cache
  # <envfile> : 環境設定ファイル
  # <service_name> : docker-compose.yml で設定しているservice
  # --no-cache : キャッシュを使わず１からビルド
```

共通プログラムでは２段階のイメージを作成している。
イメージ毎にdocker-compose内でserviceを作り、対応したdockerfileを用意

1. base イメージ作成
<envfile> :無し　（--env-fileから不要）
<service_name> : base
生成されるイメージ名 : kasekiguchi/acsl-base

2. common イメージの作成
<envfile> : 無し　（--env-fileから不要）
<service_name> : common
生成されるイメージ名 : kasekiguchi/acsl-common

### Docker image のdocker hubへのpush

```bash
docker login
docker push <イメージ名>
```

### Docker container の起動・中に入る

文法

```bash
 # 起動
 docker compose --env-file <envfile> up <service_name> 
 # 中に入る
 docker compose --env-file <envfile> exec <service_name> bash
```

baseイメージの例（buildイメージの中を確認するくらい）

```bash
# 起動
docker compose --env-file env.dev up base -d

# コンテナに入る
docker compose --env-file env.dev exec base bash
```

commonイメージはentrypointとしてdocker/common/scripts/entrypoint.shを指定しており
その中で任意のコマンドが呼べるようになっており（docker-compose内のcommandで指定）、
/common/ros_launcher/内のファイルをROS_LAUNCH変数経由で指定できる。

以下を実行することで対応したROS packageを実行できる

```bash
docker compose --env-file env.realsense up common -d
docker compose --env-file env.estimator up common -d
docker compose --env-file env.mavlink up common -d
```

[setup.sh](../systemd_files/setup.sh)では複数機対応するためnamespaceを指定する記述を追加している。

### その他のDocker コマンド

```bash
# image一覧
docker images -a
# コンテナ一覧
docker ps -a
# log 確認
docker logs <container_name>
# 設定の確認
docker compose --env-file=<envfile> config

# docker hubからイメージを入手
docker pull kasekiguchi/acsl-common:realsense-ros2

#実行時変数
COMPOSE_DOCKER_CLI_BUILD=1 : multi stage build を許可 

# 使われていない image container 全て削除
docker system prune 
# container 全削除
docker container prune 
```

## コンテナ内の共通設定 docker-composeで指定

```bash
 tty: true
 privileged: true # 特権モード
 environment:
  - HOST_USER=$LOGNAME # ホストのユーザーをDocker内の環境変数に出力
  - ROS_DOMAIN_ID=${ID:-9}
 network_mode: host
 ipc: host
 device_cgroup_rules:
      # a (all), c (char), or b (block) 
      # https://www.kernel.org/doc/Documentation/admin-guide/devices.txt
      # Realsenseを使うためのおまじない
    - 'c 81:* rmw' # video4linux
    - 'c 189:* rmw' # USB serial converters - alternate devices
 volumes: 次節で説明
```

### コンテナ内のフォルダ構成 volumes

以下となるようにdocker-compose内でマウント設定（volumes）している

```
/
|- dev                           : HOST:/dev
|- common                        : HOST:~/ros2/docker/common
|- root/ros2_ws/src/             : ROS2パッケージフォルダ（realsenseなど他のgitプロジェクトはこちらに入っている）
  |- ros_packages                : HOST:~/ros2/ros_packages
|- root/.vscode-server           : 名前付きvolume
```

#### フォルダ構成詳細

| フォルダ名 | 目的 |
| :-- | :-- |
|/dev | すべてのデバイスにアクセスできるようにマウント|
|/common | コンテナ内で利用するスクリプトをマウント|
|/root/.vscode-server | VScodeのインストールデータを永続化(VScode拡張機能を保持する為)|
|/root/ros2_ws/src/ros_packages | rosパッケージをコンテナ内で使えるようにする|
|/etc/udev/rules.d/90-custom.rules | デバイスのカスタム設定をマウント|

### 構成されているもの(未整理)

コンテナによって内容は異なる。

* 基本的なツール(git, nano, tzdataなど)
* 外部に情報をつなぐツール(ssh, xserver, udev)
* [ROS2 Humble Hawksbill](https://docs.ros.org/en/humble/index.html)
* [librealsense](https://github.com/IntelRealSense/librealsense)
  * バージョン v2.53.1
  * (2023/6/10)最新バージョンv2.54.1でビルドが失敗するバグを確認しています．
  * T265の生産終了により最新バージョンで実行できなくなる可能性があります．
* [turtlebot3](https://emanual.robotis.com/docs/en/platform/turtlebot3/overview/)
* Python3 package
  * 数値計算パッケージ [numpy](https://numpy.org/)
  * 科学技術計算パッケージ [scipy](https://scipy.org/)
  * データ解析パッケージ [pandas](https://pandas.pydata.org/)
  * WHILL制御パッケージ [pywhill](https://github.com/WHILL/pywhill)
  * UART通信パッケージ [pyserial](https://pythonhosted.org/pyserial/)
  * MAVLINK通信パッケージ [pymavlink](https://github.com/ArduPilot/pymavlink)
  * グラフ描画パッケージ [matplotlib](https://matplotlib.org/)
    * 3D 描画のためにv3.1.0以降である必要があります．
* ROS2ワークスペースのパッケージ依存関係のインストール
  * この部分はros2_wsの内容に依存します．
  * ビルドする前にROSのソースファイルを格納しておいてください．

## 拡張方法

### Docker imageの拡張

1. 上述のdevコンテナに入り必要な拡張(apt installなど)をする。
2. 拡張内容が確定したらdockerfileに反映
    内容に応じて dockerfile.base か dockerfile.commonに分けて反映
2'. realsense-ros2をbase imageにして拡張するdockerfileと、docker-compose上のserviceを追加
3. buildし直す
4. docker hubにアップロード
5'. ros2_launch_sh のservice名を変更
6. HOST上でgit登録

###

1. 上述のdevコンテナに入る
2. DOCKER上でros2_ws/src/ros_packages/内でパッケージを開発
3. 各種起動ファイルを追加
  3.1 ROSパッケージを起動するコマンドを書いたlaunch_***.shを
      docker/common/ros_launcherに追加
  3.2 対応するenv.*** をdocker/内に追加
  3.3 systemd_files/ros2_launch_shに3.1のファイルの起動を追加
4. HOST上でgitに登録
5. systemd_files/setup.sh を実行し自動起動の設定をする
