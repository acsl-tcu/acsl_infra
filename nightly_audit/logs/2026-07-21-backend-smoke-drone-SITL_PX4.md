# Nightly Audit 2026-07-21 — backend-smoke-drone-SITL_PX4 (host: ruth)

## 結論
**smoke スキップ (ホスト使用中ゲート・要注意)。claude 未起動・PR なし・既存コンテナには未接触。**

対象 project (drone) 以外のコンテナが Up のため、干渉回避で bringup せず終了:
- `yolo`
- `nav2`
- `rover`
- `bcps_bridge`
- `rf_tf`
- `isaac-sim`
- `bcps_sim`
- `slam_toolbox`

常駐等で無視してよいコンテナは env の `NIGHTLY_SMOKE_IGNORE` (カンマ区切り) に追加する。
