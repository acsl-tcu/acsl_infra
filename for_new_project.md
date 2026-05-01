# 新規プロジェクト構築手順（ROS2ベース）

このリポジトリのベースシステムを使って、新しいプロジェクトを立ち上げる手順をまとめる。

## 1. リポジトリ取得
```bash
cd ~/
git clone https://github.com/acsl-tcu/ros2.git
cd ~/ros2
```

## 2. プロジェクト情報の決定
以下を決める。
- `PROJECT`: プロジェクト名（例: `drone`, `whill`, `rover`）
- `ROS_DOMAIN_ID`: 同一ネットワークでの衝突回避用ID

## 3. Dockerイメージの取得
```bash
PROJECT="<PROJECT>"
IMAGE="image_${PROJECT}"
docker pull kasekiguchi/acsl-common:${IMAGE}
```

## 4. systemd登録（HOST側）
`commands`のセットアップスクリプトでsystemdに登録する。
```bash
PROJECT="<PROJECT>"
cd ~/ros2/commands
bash setup.sh "${PROJECT}"
source ~/.bashrc
```

起動確認（必要に応じて再起動）:
```bash
dps
dlogs "<container_name>"
sudo reboot
```

## 5. コンテナ起動（手動で起動する場合）
```bash
cd ~/ros2/docker
docker compose --env-file <envfile> up common -d
```
`<envfile>`はプロジェクトに対応する環境ファイルを指定する。

## 6. ビルド（コンテナ内）
コンテナ内でビルドする。必要ならパッケージ指定でビルド可能。
```bash
# 例: すべてのパッケージをビルド
launcher/launch_build.sh

# 例: 指定パッケージのみビルド
launcher/launch_build.sh <package_name>
```

## 7. 追加パッケージの作成（必要時）
```bash
ros2 pkg create <package_name> \
  --node-name <node_name> \
  --build-type ament_python \
  --dependencies rclpy std_msgs sensor_msgs \
  --maintainer-email ksekiguc@tcu.ac.jp \
  --maintainer-name "Kazuma SEKIGUCHI"
```

## 8. 実行確認（コンテナ内）
```bash
source /root/ros2_ws/install/setup.bash
ros2 run <package_name> <executable_name>
```

## 9. 補足
- `commands/scripts/`に便利コマンド（`dps`, `dlogs`, `dup`など）がある。
- ROSパッケージは`packages/`配下に配置する。
