# 2026-11-03 image-refresh (host: ruth)

## 結果: 成功 (全6手順完了・deny ゼロ)

| 項目 | 値 |
|---|---|
| 事前 df -h / | 空き 323G (78% 使用) — 40GB 閾値クリア |
| 旧 IMAGE ID / CREATED | `037652007143` / 2026-10-23T02:41:04+09:00 |
| `docker pull ros:jazzy` | **digest 更新あり** (`Status: Downloaded newer image for ros:jazzy`)。新 digest `sha256:8eed0a4669bbf43ee331878a4c39bd8ebddea8e3312a58b4fae8edb14526b617` |
| 再ビルド | harness 注入の絶対パス版 `dbuild ros:jazzy jazzy /home/sekiguchi/GitHub/sb/acsl_infra/dockerfiles/dockerfile.base_ros_x86 --no-cache` をそのまま実行。02:30:47 開始 → `Successfully built 53a40d15104b` / `Successfully tagged kasekiguchi/acsl-common:jazzy_x86` (約7分) |
| 新 IMAGE ID / CREATED | `53a40d15104b` / 2026-11-03T02:37:37+09:00 (7.42GB, content 1.69GB) |
| 検証 (ros2 pkg list \| wc -l) | **345** (≥300 OK) |
| `dpush jazzy_x86` | 成功 (保存済み credential で Login Succeeded)。`jazzy_x86: digest: sha256:53a40d15104bf88e7871c0c64cfb3ef4ec830ce981c3383aa3b2c865a6711080 size: 4015` |
| `docker image prune -f` | Total reclaimed space: **18.5GB** (旧 jazzy_x86 `037652007143` を含む dangling のみ) |

### 補足
- ビルドログ中の project_common は `v0.8.0` (commit 78200242) を pip install。
- build 時に compose 由来の未設定変数 warning (PROJECT / ACSL_WORK_DIR 等) と
  `build-args [BASE_IMAGE] were not consumed` が出るが、毎回出ている既知の無害 warning。
- 派生再ビルドは harness が実施 (run.log 参照)。本テーマでは jazzy_x86 以外を push していない。
- 稼働中コンテナへの操作なし。実機関連操作なし。

## 要相談
- arm 版 `jazzy` (無印) は arm 側は別ホストでの運用が未整備 (このホスト x86 ではビルド不可)。
