# Nightly Audit 2026-08-18 — image-refresh (ホスト: ruth)

## 結果サマリ
**ビルド不能 (5 run 連続の権限 deny) — 事前チェック + pull のみ実施、push/prune は未着手。**
PR なし (このテーマは元々 PR を作らない)。成果物は本レポートのみ。

## 実施内容と記録

### 1. 事前チェック — PASS
- `df -h /`: 空き **707GB** (閾値 40GB を大幅クリア)
- 現行 `kasekiguchi/acsl-common:jazzy_x86`:
  - IMAGE ID: `04cd06a81929`
  - CREATED: `2026-07-17T10:30:00+09:00` (docker inspect で取得)
  - DISK USAGE 7.54GB / CONTENT SIZE 1.72GB

### 2. 上流更新 (`docker pull ros:jazzy`) — 実行成功
- Digest: `sha256:da725acf8b0f9f30c683e33ffbdcd6482d077af96d6fdc7688c5f4f280b7d923`
- `Status: Image is up to date` — **今回の pull での digest 更新なし**。
- ただしこの digest は 08-07 run で「更新あり」と確認されたもの。現行 `jazzy_x86`
  (07-17 ビルド) はそれより古い上流ベースのままなので、**apt スキューは継続中**。

### 3. 再ビルド — 権限 deny により中止 (5 run 連続: 07-16, 07-17, 07-27, 08-07, 08-18)
仕様どおり一字一句そのまま実行:
```
dbuild ros:jazzy jazzy $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_x86 --no-cache
```
ツール層の拒否メッセージ原文:
> Permission to use Bash has been denied because Claude Code is running in don't ask mode.

(rc=126/137 ではなくツール層の自動 deny。テーマの注意に従い、Dockerfile 修正・
コマンド言い換え・迂回は行わず中止。)

### 4〜6. 検証 / push / prune — 未実施
ビルドが無いため対象なし。旧タグ `04cd06a81929` はそのまま残っており実害なし。
派生イメージの連鎖再ビルドも発動しない (ベース更新が無いため)。

## 要相談
1. **[継続・5晩連続] headless 監査で `dbuild` / `docker build` が自動 deny。**
   ハーネス (`run_nightly_audit.sh`) の許可リストに build 系が無い限り、このテーマは
   毎回「事前チェック + pull + 本レポート」で終わる。許可追加をご検討ください。
   なお dbuild の素 docker 等価コマンドは解明済み (メモリ
   `nightly-audit-image-refresh-docker-perm-gap` 参照) — 許可さえ入れば完遂可能。
2. **[継続] `jazzy_x86` の手動再ビルド推奨。** 現行イメージは 07-17 ビルドで、
   08-07 に確認された上流 `ros:jazzy` digest 更新 (`da725acf...`) を取り込んでいない。
   スキュー再発状態が約6週間継続中。
3. **[定型] arm 版 `jazzy` (無印) は arm ホスト or qemu が必要でこのホストではビルド不可。**
   arm 側は別ホストでの運用が未整備。

## 捨てた候補
なし (このテーマは指摘列挙型ではない)。
