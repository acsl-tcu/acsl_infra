# Nightly Audit 2026-08-07 — image-refresh (ホスト: ruth)

## 結果サマリ
**ビルド以降は実行不能 (docker build 系の permission deny、4 run 連続)。**
事前チェックと `docker pull ros:jazzy` までは完了。push / prune は未実施 (ビルドが無いため)。
Hub タグ `kasekiguchi/acsl-common:jazzy_x86` は**未更新のまま**。

## 実施内容と記録

### 1. 事前チェック — PASS
- `df -h /` → 空き **548GB** (閾値 40GB を大幅クリア)
- 現行イメージ: `kasekiguchi/acsl-common:jazzy_x86`
  - IMAGE ID: **04cd06a81929**
  - CREATED: **2026-07-17T10:30:00+09:00** (07-17 の手動再ビルド分)

### 2. 上流更新 — **digest 更新あり**
`docker pull ros:jazzy` →
```
Digest: sha256:da725acf8b0f9f30c683e33ffbdcd6482d077af96d6fdc7688c5f4f280b7d923
Status: Downloaded newer image for ros:jazzy
```
上流ベースが 07-17 以降に更新されている。つまり現行 jazzy_x86 (07-17 ビルド) は
**古い上流 digest ベースになっており、スキューが再発し始めている**。再ビルドの必要性は実在。

### 3. 再ビルド — 実行不能 (permission deny)
仕様どおり一字一句そのまま実行:
```
dbuild ros:jazzy jazzy $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_x86 --no-cache
```
ツールが返した拒否メッセージ原文:
> Permission to use Bash has been denied because Claude Code is running in don't ask mode. IMPORTANT: You *may* attempt to accomplish this action using other tools that might naturally be used to accomplish this goal, e.g. using head instead of cat. But you *should not* attempt to work around this denial in malicious ways (...) If you believe this capability is essential to complete the user's request, STOP and explain to the user what you were trying to do and why you need this permission. Let the user decide how to proceed.

テーマ仕様・メモリの方針に従い、言い換え・迂回 (素の `docker build` 等) は行わず中止。

### 4〜6. 検証 / push / prune — 未実施 (ビルド不成立のため)

## 要相談
1. **[継続・4 run 連続: 07-16 / 07-17 / 07-27 / 08-07] headless (don't-ask) で `dbuild` /
   `docker build` が自動 deny。** pull / df / docker images / docker inspect は許可。
   ハーネス (`run_nightly_audit.sh`) 側で build / push / prune 系の allow 追加が必要。
   今回は上流 digest が実際に更新されており (上記 sha256:da725acf...)、jazzy_x86 の
   スキューが再発し始めているため、許可追加までは **07-17 同様の手動再ビルド** を推奨:
   `dbuild ros:jazzy jazzy $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_x86 --no-cache`
   → 手順4の検証 → `dpush jazzy_x86` → `docker image prune -f`
2. **arm 側は別ホストでの運用が未整備** (arm 無印 `jazzy` はこのホストではビルド不可)。

## 派生イメージ
ベース更新が不成立のため、harness による `derived_images.conf` 連鎖再ビルドは対象なし。

## PR
なし (このテーマは PR を作らない)。
