# Nightly Audit — 2026-08-29 — image-refresh (ホスト: ruth)

## 結果サマリ
**ビルド不成立 (権限 deny、6 run 連続)。** 事前チェックと `docker pull ros:jazzy` までは完了。
上流 digest は 08-18 時点から**更新されていた**が、`dbuild` が don't-ask モードで deny され
再ビルドできないため、push / prune / 検証は未実施。Hub の `jazzy_x86` は旧のまま (実害なし、
旧タグ健在)。

## 実施内容と記録

### 1. 事前チェック — PASS
- `df -h /`: 空き **667GB** (閾値 40GB を大幅クリア)。
- 現行イメージ: `kasekiguchi/acsl-common:jazzy_x86`
  - IMAGE ID: **04cd06a81929** (DISK USAGE 7.54GB / CONTENT 1.72GB)
  - CREATED: **2026-07-17T10:30:00+09:00** (`docker inspect --format {{.Created}}` で取得)
  - → 上流とのスキューは**約6週間**に拡大。

### 2. 上流更新 — digest 変化あり
- `docker pull ros:jazzy` 成功。
  - **Digest: `sha256:2589a8fba5257307857890173c069852c2abf913a0be7970f172478baecb09e4`**
  - Status: **Downloaded newer image** — 08-18 の記録 (`da725acf…`) から**ベース digest が更新**。
  - つまり今回は apt レベルどころかベースイメージ自体が新しく、再ビルドの必要性は高い。

### 3. 再ビルド — 権限 deny (拒否メッセージ原文引用)
実行コマンド (手順どおり一字一句):
```
dbuild ros:jazzy jazzy $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_x86 --no-cache
```
ツールの拒否メッセージ原文:
> Permission to use Bash has been denied because Claude Code is running in don't ask mode.
> IMPORTANT: You *may* attempt to accomplish this action using other tools that might
> naturally be used to accomplish this goal, e.g. using head instead of cat. But you
> *should not* attempt to work around this denial in malicious ways (…) If you believe
> this capability is essential to complete the user's request, STOP and explain to the
> user what you were trying to do and why you need this permission.

- rc=126/137 ではなく**明示的な permission deny** (07-16〜08-18 の5 run と同一事象、今回で
  **6 run 連続**)。deny の意図が「headless で docker build をさせない」であるため、
  素の `docker build` 等価コマンドへの言い換えによる迂回は行わなかった
  (dbuild の等価展開は解明済み — メモリ参照)。

### 4〜6. 検証 / push / prune — 未実施
ビルドが走っていないため対象なし。旧タグ `04cd06a81929` はそのまま残っており実害なし。
派生イメージ再ビルド (harness 実施) もベース更新不成立のため発動しない。

## 要相談
1. **[継続・6 run 目] headless (don't-ask) の許可リストに `dbuild` (または docker build) が
   無く、image-refresh テーマが恒久的に bringup 不能。** pull/df/images/inspect は許可済みで
   事前チェックまでは毎回通る。ビルド許可 (`dbuild` 前綴 or `docker build` 前綴) の追加、
   もしくはこのテーマを harness 側スクリプト実行に移す判断をお願いしたい。
2. **上流 `ros:jazzy` の digest が 08-18 → 08-29 で更新** (`2589a8fb…`)。ローカル
   `jazzy_x86` は 07-17 ビルドのままでスキュー約6週間。**手動での再ビルド & push を推奨**:
   `dbuild ros:jazzy jazzy $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_x86 --no-cache`
   → 手順4の検証 → `dpush jazzy_x86` → `docker image prune -f`。
3. arm 版 `jazzy` (無印) は arm 側での同運用が未整備 (このホスト x86 ではビルド不可、恒例記載)。

## PR
なし (このテーマは PR を作らない。成果物は Hub タグ更新だが今回は不成立)。
