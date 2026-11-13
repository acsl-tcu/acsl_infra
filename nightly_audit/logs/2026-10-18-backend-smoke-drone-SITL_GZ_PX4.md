# 2026-10-18 backend-smoke — drone × SITL_GZ_PX4 (host: ruth)

## 結果: BLOCKED (検証未実施)

## 事前確認
- `docker ps -a`: `drone2_1`〜`drone2_4` が `Up 32 hours` (image 96edd2645012)。
- `docker inspect drone2_1`: NetworkMode=`host`、`~/drone/packages`・`~/drone/config`・`~/drone/common` を live マウント。
- `docker logs --tail 8 drone2_1`: HLC-SL ノードが `phase=standby` で稼働中 (timing ログ継続出力)。
- 稼働 checkout `~/drone` は利用者の `fix/coop-estimator-true-mass` ブランチ、未コミット変更あり
  (`isaac_sim/notebooks/setup_isaac_coop_drone.ipynb`)。

## BLOCKED の理由
- smoke の drone2 / mavros2 / px4_sitl も host network の ROS2 で、利用者の4機 fleet と topic 空間・
  ポートを共有するため干渉し得る (2026-10-17 と同じ状況)。
- origin/main 基準で起動するには checkout の切替が必要だが、live マウントされている稼働中コードを
  差し替えることになる。利用者のコンテナを止めたり rm したりもしない。

## 指摘 / PR
- なし (検証を実施していないため)。
- 既知の要相談事項 (前回から変化なし・未確認): `project_launch.sh` の UDP 14540 待ちで毎回90秒を
  空費する件 (2026-08-24 のレポート参照)。

## 後始末
- 起動したコンテナはない。既存コンテナには触れていない。

SMOKE_RESULT: BLOCKED
