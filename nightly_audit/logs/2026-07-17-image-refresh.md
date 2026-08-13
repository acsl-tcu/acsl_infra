# Nightly Audit — 2026-07-17 — image-refresh

**結果: 手順 3 (dbuild) で権限 deny により中止 (要相談)。Hub タグの更新なし・push なし・prune なし。PR なし (このテーマは元々 PR を作らない)。**

前回 (2026-07-16) は手順 2 の `docker pull` で deny されたが、今回は **pull まで許可**され
手順 2 まで完了 (ハーネス許可の部分改善)。ビルド (`dbuild` / 素の `docker build`) は依然 deny。

## 実行環境
- ホスト: ruth / 無人起動 (Claude Code, don't-ask permission mode)

## 実施できたこと
### 手順 1: 事前チェック — すべて合格
- `df -h /`: 空き **1.2TB** (閾値 40GB を大幅クリア)
- 現行イメージ記録: `kasekiguchi/acsl-common:jazzy_x86` = **437a37859fbe** /
  CREATED **2026-05-12T22:48:48+09:00** (前回から変化なし。約2ヶ月遅れが継続)

### 手順 2: 上流更新 — 完了 (前回は不能だった)
- `docker pull ros:jazzy` 成功。
  digest: **sha256:31daab66eef9139933379fb67159449944f4e2dcf2e22c2d12cc715f29873e0f**
- 出力は `Image is up to date` — **ベース digest の更新なし**。
  (テーマ仕様どおり digest 不変でも apt レベル更新の取り込みに `--no-cache` 再ビルドは必要)

## 中止理由 (手順 3 で停止)
- `dbuild ros:jazzy jazzy $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_x86 --no-cache` が
  **ハーネスの permission 拒否** (don't-ask モードで自動 deny)。
- 既知の環境ギャップ (07-16 から継続、07-17 昼にも再確認済み) であり、言い換え・迂回は
  行わない方針のため素の `docker build` 等価コマンドの再試行もせず中止。
- **旧タグ 437a37859fbe はそのまま残っており実害なし** (スキューが伸びるのみ)。

## 要相談
1. **[ハーネス] dbuild / docker build の許可が未追加で、image-refresh は手順 3 以降が実行不能。**
   07-17 run で pull / df は許可に改善されたので、残りの最小許可セットは:
   - `dbuild` (または等価の素コマンド: `docker build --no-cache --build-arg ROS_DISTRO=jazzy -t kasekiguchi/acsl-common:jazzy_x86 -f $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_x86 $ACSL_ROS2_DIR/docker`)
   - `docker run --rm kasekiguchi/acsl-common:jazzy_x86 *` (手順 4 の検証用)
   - `dpush jazzy_x86` / `docker image prune -f` (手順 5–6。今回はビルド不能のため未検証)
   許可追加までこのテーマは rotation で回ってきても手順 2 止まりで終わる。
2. **[定常記載] arm 版 `jazzy` (無印) は arm ホストでの同運用が未整備** (このホスト x86 では
   ビルド不可。arm ホストに運用が入ったらこの記載を落とす)。

## テーマ必須記載項目
- 旧 IMAGE ID / CREATED: 437a37859fbe / 2026-05-12 → 新: **なし (ビルド deny で未実施)**
- `ros:jazzy` digest 更新有無: **更新なし** (sha256:31daab66eef9... / Image is up to date)
- 検証 (pkg 数): 未実施 / push: 未実施 / prune 回収容量: 0 (未実施)
- 派生イメージ: ベース更新が入らなかったため追従不要。
