# 2026-10-01 image-refresh (host: ruth)

## 結果: 成功 (jazzy_x86 を再ビルドし push 済み)

| 項目 | 値 |
|---|---|
| 事前 df -h / | 空き 769G (48% 使用) — 40GB 以上なので OK |
| 旧 IMAGE ID / CREATED | `d0c4ef08f81d` / 2026-09-20T02:40:29+09:00 |
| `ros:jazzy` digest | `sha256:c3706ef0a0aa45413c07803cf433602f543b22e45b4855f6fca955c2d8ecc4e8` — 「Image is up to date」(前回から**更新なし**)。手順どおりビルドは続行 |
| 再ビルド | harness 注入の絶対パス版 `dbuild ros:jazzy jazzy /home/sekiguchi/GitHub/sb/acsl_infra/dockerfiles/dockerfile.base_ros_x86 --no-cache` → `Successfully built c422f9aaac4b` / `Successfully tagged kasekiguchi/acsl-common:jazzy_x86` (02:30 開始、約11分) |
| 新 IMAGE ID / CREATED | `c422f9aaac4b` / 2026-10-01T02:41:20+09:00 (本日。CREATED は `docker inspect` で取得) |
| 検証 (ros2 pkg list \| wc -l) | **345** (≥300 で OK) |
| push | `dpush jazzy_x86` 成功 — `jazzy_x86: digest: sha256:c422f9aaac4bcfc7f1da4c0f437ba049aa4e2ed1b45c0582e693c358b864f003 size: 4016` |
| prune | `docker image prune -f` (dangling のみ) — 旧 `d0c4ef08f81d` 含む dangling を削除、**10.65GB 回収** |

## 備考
- ビルドログの `The "PROJECT" variable is not set` 等の compose 警告、`[Warning] One or more build-args [BASE_IMAGE] were not consumed` は従来どおりで実害なし。
- 派生再ビルドは harness が実施 (run.log 参照)。このテーマでは image_* 等は触っていない。
- 権限 deny: なし。rc=126 / 137 もなし。稼働中コンテナには一切触れていない。

## 要相談
- arm 側 (`jazzy` 無印) は別ホストでの運用が未整備 (このホストではビルド不可)。
