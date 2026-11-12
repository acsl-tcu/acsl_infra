# 2026-10-17 backend-smoke: drone × SITL_PX4 (host: ruth)

## 結論
**BLOCKED** — 利用者の coop (4機協調) 実験ノードが稼働中だったため、`dup all SITL_PX4` を起動しなかった。
PR なし。

## 事前確認 (起動前チェック)
- `docker ps`: `drone2_1`〜`drone2_4` が 8 時間前から Up
  - compose project `drone2_N_drone2`, config `/home/sekiguchi/drone/.acsl/docker/docker-compose.yml`
  - **`NetworkMode=host`**、`~/drone/{packages,config,common,launcher,...}` を live マウント
- `docker logs --tail 15 drone2_1`: HLC-SL ノードが稼働中 (`phase=standby T=40.00 mLi=0.790 ... HLC-SL timing step=1.01ms`)。
  = 利用者の協調吊り下げ実験の ROS2 ノードが生きている。
- `~/drone` checkout は `fix/coop-estimator-true-mass` ブランチ + 未コミット変更
  (`isaac_sim/notebooks/setup_isaac_coop_drone.ipynb`)。
- `ss -ulnp`: 14540/14580 等の PX4 系ポートは未使用 (px4_hlc 衝突は今回は無し)。

## BLOCKED と判断した理由
1. SITL_PX4 の `drone2` / `quadrotor_sim` も host network の ROS2 ノード。同一ホスト・同一 DDS ドメインで
   稼働中の 4 機ノードと topic 空間を共有し、利用者の実験に干渉し得る。
2. smoke を `origin/main` 基準で行うには稼働 checkout の切替が必要だが、稼働コンテナが
   `packages/` `config/` を live マウントしているので、切替 = 利用者の実行中コードの差し替えになる。
   未コミット変更もある。
3. 利用者のコンテナを `docker rm -f` で止めるのは論外 (前例: 2026-09-15 px4_hlc の BLOCKED と同じ扱い)。

## 静的に確認できたこと (起動はしていない)
- `origin/main` = `04e26f8` (Merge PR #243)。
- `git log origin/main -- .gitmodules packages/px4_msgs` は**空**。
  → 2026-09-14 に FAIL 確定した `ModuleNotFoundError: No module named 'px4_msgs'`
  (quadrotor_sim / drone2 即死) の原因は main 上で未解消のまま。次回起動できても FAIL が見込まれる。
  px4_msgs の取り込み方針 (submodule / vendoring / image 焼き込み) は **要相談** (継続)。

## 要相談
- 夜間 smoke の時間帯に drone2 fleet コンテナが常駐している場合の運用 (smoke を skip するか、
  ROS_DOMAIN_ID を分けた隔離起動経路を harness に用意するか)。
- px4_msgs 欠落 (2026-09-14 から継続)。

## 後始末
- 本監査ではコンテナを一切起動・削除していない。checkout も変更していない。

SMOKE_RESULT: BLOCKED
