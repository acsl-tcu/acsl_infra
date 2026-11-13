# 2026-10-12 image-refresh (host: ruth)

## 結果: 成功 (build → 検証 → push → prune 全手順完了、deny ゼロ)

| 項目 | 値 |
|---|---|
| 事前 df -h / | 575G 空き (40GB 閾値クリア) |
| 旧 jazzy_x86 | `c422f9aaac4b` / CREATED 2026-10-01T02:41:20+09:00 |
| `docker pull ros:jazzy` | **digest 更新あり** — `Downloaded newer image for ros:jazzy`, digest `sha256:066420e07f60aa18262f2479981def87ebcfcec42eefb0c0c57c4a46098348ca` |
| ビルド | `dbuild ros:jazzy jazzy /home/sekiguchi/GitHub/sb/acsl_infra/dockerfiles/dockerfile.base_ros_x86 --no-cache` 成功 (02:30:45 開始 → 02:39 頃完了、約9分) — `Successfully tagged kasekiguchi/acsl-common:jazzy_x86` |
| 新 jazzy_x86 | `50c262a22eba` / CREATED 2026-10-12T02:39:04+09:00 (今日、ID 変化確認) |
| 検証 `ros2 pkg list \| wc -l` | **345** (≥300 OK) |
| push `dpush jazzy_x86` | 成功 — `jazzy_x86: digest: sha256:50c262a22eba57577d8451b9e5b6daf8de6f3c7b06a682b0f53beb594283aa08 size: 4016` |
| `docker image prune -f` | Total reclaimed space: **17.29GB** (旧 c422f9aaac4b を含む dangling のみ) |

補足:
- ビルド中に project_common `v0.8.0` (commit 78200242) から acsl-framework 0.8.0 を pip install。
- ビルドログの `PROJECT`/`ACSL_WORK_DIR` 等未設定 warning と `build-args [BASE_IMAGE] were not consumed` は従来どおりの無害な警告。

## 派生イメージ
派生再ビルドは harness が実施 (run.log 参照)。このテーマでは image_* 等を再ビルド・push していない。

## 要相談
- arm 側 (`kasekiguchi/acsl-common:jazzy` 無印) は別ホストでの運用が未整備 (このホストではビルド不可)。
