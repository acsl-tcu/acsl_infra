# 2026-10-19 backend-smoke — drone × SITL_AP (host: ruth)

## 結論
**BLOCKED**。利用者の coop fleet (`drone2_1`〜`drone2_4`) が稼働中のため smoke を起動しなかった。
`dup` は一度も実行していない。コンテナの停止・削除や checkout の切替もしていない。

## 事前確認 (証拠)
- `docker ps`: `drone2_1`〜`drone2_4` (image 96edd2645012) がいずれも `Up 2 days`
  (StartedAt 2026-10-16T09:08Z)。
- `docker inspect drone2_1`: `NetworkMode=host`。`/home/sekiguchi/drone/{packages,config,common,...}` を
  live マウントしている。
- `docker logs --tail 5 drone2_1`: `phase=standby T=40.00 mLi=0.790 ... ケーブル長=2.74/2.74` と
  `HLC-SL timing (avg/200): step=1.01ms` を出し続けている = HLC-SL ノードが生きている。
- `~/drone` の checkout: `fix/coop-estimator-true-mass` ブランチで、`isaac_sim/notebooks/setup_isaac_coop_drone.ipynb`
  に未コミット変更がある。

## BLOCKED にした理由
- SITL_AP の smoke では drone2・mavros2・ArduCopter SITL も host network で動く。そのため fleet と
  ROS2 topic 空間・MAVLink ポートを共有することになり、利用者の実験に干渉し得る。
- 監査ブランチ (origin/main) に切り替えると、live マウントしている稼働中 fleet のコードが差し替わる。
- 以上から、前例 (10/17 SITL_PX4、10/18 SITL_GZ_PX4) と同じく BLOCKED とした。

## 確証指摘 / PR
- なし (検証を実施していない)。

## 要相談
- fleet が常駐し続ける限り、drone の SITL 系 smoke はすべて BLOCKED になる (10/17・10/18 に続き3晩連続)。
  対策案は2つ。(a) harness で「drone2_N が Up なら drone deploy をスキップし rotation を後ろ倒し」にする。
  (b) smoke 専用の別 checkout と ROS_DOMAIN_ID を分けて、隔離して起動する。
- 参考: 前回の SITL_AP smoke (2026-09-16) は PASS 2/2。既知の「Flight battery」90s 空費
  (project_launch.sh の sentinel) は未解決のまま。

SMOKE_RESULT: BLOCKED
