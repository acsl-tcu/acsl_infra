# Nightly Audit — 2026-07-16 — image-refresh

**結果: 中止 (要相談)。Hub タグの更新なし・push なし・prune なし。PR なし (このテーマは元々 PR を作らない)。**

## 実行環境
- ホスト: ruth / 無人 cron 起動 (Claude Code, don't-ask permission mode)

## 実施できたこと (手順 1: 事前チェック — すべて合格)
- `df -h /`: 空き **1.2TB** (閾値 40GB を大幅クリア)
- 現行イメージ記録:
  - `kasekiguchi/acsl-common:jazzy_x86` = **437a37859fbe**
    (full: sha256:437a37859fbe3b48ecfdf02a0c63585e242b3df72c873a1af48bcc769ad71393)
  - CREATED: **2026-05-12T22:48:48+09:00** — 約2ヶ月前。テーマの想定どおり更新が必要な状態。
- `dbuild` / `dpush` の実体確認: `~/GitHub/sb/acsl_infra/commands/scripts/` に存在。
- dockerfile (`$ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_x86`) の存在確認は
  権限拒否で未実施 (下記と同根)。

## 中止理由 (手順 2 で停止)
- `docker pull ros:jazzy` が **ハーネスの permission 拒否** (don't-ask モードで
  状態変更系 Bash が自動 deny)。読み取り系 (`docker images` / `docker inspect`) は通るが、
  pull が拒否される以上、後続の `dbuild --no-cache` / `dpush` / `docker image prune -f` も
  すべて状態変更系で実行不能。
- `~/.claude/settings.json` の `permissions.allow` は空。docker 系の許可エントリなし。
- テーマの安全境界「失敗時に修正して再試行しない → 要相談」に従い中止。
  **旧タグ 437a37859fbe はそのまま残っており実害なし** (スキューが2ヶ月分伸びるのみ)。

## 要相談
1. **[ハーネス] image-refresh テーマが don't-ask モードで実行不能。**
   `run_nightly_audit.sh` 側で docker の必要コマンドを許可リストに追加する必要がある。
   最小セット: `docker pull ros:jazzy`, `dbuild`, `docker run --rm kasekiguchi/acsl-common:jazzy_x86 *` (検証用),
   `dpush jazzy_x86`, `docker image prune -f`。
   ※ 2026-07-13〜15 の backend-smoke の `dup` rc=127 と同系統の「headless 環境ギャップ」。
   ハーネス修正までこのテーマは rotation で回ってきても即・要相談で終わる。
2. **[定常記載] arm 版 `jazzy` (無印) は arm ホストでの同運用が未整備** (このホスト x86 では
   ビルド不可。arm ホストに運用が入ったらこの記載を落とす)。

## テーマ必須記載項目
- 旧 IMAGE ID / CREATED: 437a37859fbe / 2026-05-12 → 新: **なし (ビルド未実施)**
- `ros:jazzy` digest 更新有無: **不明 (pull 拒否)**
- 検証 (pkg 数): 未実施 / push: 未実施 / prune 回収容量: 0 (未実施)
- 派生イメージ: ベース更新が入らなかったため追従不要。
