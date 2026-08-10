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
source $ACSL_ROS2_DIR/bashrc
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

## 9. メインノードの main() 定型 (必須)

制御ループを持つノードの `main()` は project_common の
`acsl.utils.realtime.spin` を使うこと:

```python
from acsl.utils.realtime import spin

def main(args=None):
    rclpy.init(args=args)
    node = MyNode()
    spin(node)      # executor 選択 + GC 対策 + spin + destroy の定型
    rclpy.shutdown()
```

理由: rclpy (jazzy) の `MultiThreadedExecutor` は購読トラフィックがあると
busy-loop してタイマーが飢餓する (40Hz timer 実測: MTE+購読 p50=72ms/
max=489ms/CPU104% vs Single p50=25.0ms/CPU4%)。引数なしではさらに CPU
コア数分のスレッドを生成する。project_drone2 の実機で「制御ステップが
散発的に数百 ms 停止」の原因になった (project_drone2#127)。
`spin()` は SingleThreadedExecutor 既定 + GC 世代2の停止抑制まで行う。
ブロックする処理 (HTTP/serial 等) はコールバックに置かず独自スレッドへ。
一時的に戻す場合は env `ACSL_EXECUTOR=multi[:N]`。

## 10. 補足
- `commands/scripts/`に便利コマンド（`dps`, `dlogs`, `dup`など）がある。
- ROSパッケージは`packages/`配下に配置する。
