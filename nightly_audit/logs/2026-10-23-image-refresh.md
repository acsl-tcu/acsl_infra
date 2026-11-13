# 2026-10-23 image-refresh (host: ruth)

## 結果: 成功 (全手順 deny ゼロ、5 run 連続全通し)

| 項目 | 値 |
|---|---|
| 事前 df -h / | 414G 空き (1.5T 中 72% 使用) — 40GB 閾値クリア |
| 旧 jazzy_x86 | `50c262a22eba` / CREATED 2026-10-12T02:39:04+09:00 |
| `docker pull ros:jazzy` | **更新あり** — 新 digest `sha256:103b6c417973394659af6804d4917cd489b91e5ed22eb7bef263025a3bed2410` (前回 066420e0 → 今回 103b6c41。旧 066420e0 は prune で削除を確認) |
| dbuild (--no-cache) | 成功 `Successfully built 037652007143` / 開始 02:30:42 → CREATED 02:41:04 (約 10.5 分) |
| 新 jazzy_x86 | `037652007143` / CREATED 2026-10-23T02:41:04+09:00 (今日) |
| 検証 `ros2 pkg list \| wc -l` | **345** (≥300 OK、前回同数) |
| `dpush jazzy_x86` | 成功 — `jazzy_x86: digest: sha256:03765200714329c27ba71f1368aa2728790dbec518af02923a6e414d07f668da size: 4015` (digest = IMAGE ID) |
| `docker image prune -f` | **18.47GB** 回収。prune 後も jazzy_x86 = `037652007143` が残存することを再確認 |

実行コマンド (一字一句):
- `df -h /`
- `docker images kasekiguchi/acsl-common:jazzy_x86` / `docker inspect --format '{{.Id}} {{.Created}}' kasekiguchi/acsl-common:jazzy_x86`
- `docker pull ros:jazzy`
- `dbuild ros:jazzy jazzy /home/sekiguchi/GitHub/sb/acsl_infra/dockerfiles/dockerfile.base_ros_x86 --no-cache`
- `docker run --rm kasekiguchi/acsl-common:jazzy_x86 bash -c "source /opt/ros/jazzy/setup.bash && ros2 pkg list | wc -l"`
- `dpush jazzy_x86`
- `docker image prune -f`

## 派生イメージ
派生再ビルドは harness が実施 (run.log 参照)。本テーマでは image_* 等を再ビルド・push していない。

## PR
なし (本テーマは PR を作らない)。

## 要相談
- arm 版 `jazzy` (無印) は arm ホスト or qemu が必要でこのホストではビルド不可。arm 側は別ホストでの運用が未整備。
- (定常) dbuild 時に compose 変数未設定警告 (`ACSL_WORK_DIR` / `PROJECT` / `ROS_DOMAIN_ID` / `USER` / `x86` / `DISPLAY`) が出る。cron 環境で未 export のため。ベースビルドには影響なし (ビルド成功)。
- (定常) `[Warning] One or more build-args [BASE_IMAGE] were not consumed` — dockerfile.base_ros_x86 が BASE_IMAGE を使っていない。実害なし、情報のみ。
