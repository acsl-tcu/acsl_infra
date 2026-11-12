# Nightly Audit 2026-11-12 — backend-smoke (rover × SIM / local.yaml) — host: ruth

## テーマ / 対象
- deploy = rover (`/home/sekiguchi/rover`, main @ `12ecea99`, origin/main と一致, 未追跡ファイルのみ)
- mode = SIM, config = local.yaml
- 起動コマンド: `dup all SIM local.yaml` (一字一句このまま)
- 安全: SIM のみ。console 操作・駆動指令は一切送っていない。EXP 不実行。

## 実施内容
1. 事前に `docker ps` が空 (ホスト空き) を確認。
2. `dup all SIM local.yaml` → rc=0。起動コンテナ: `rf_tf`, `bcps_bridge`, `rover`, `nav2` (全て `docker ps` で Up)。
   - config 解決: `localizer=amcl map=bld10_{floor}F initial_pose=[0.0, 0.0, 0.0] initial_floor=4`
   - rover/bcps_bridge/rf_tf はイメージ `image_rf_rover_x86` へフォールバック (正常表示)、nav2 は `nav2_x86`。
3. `docker logs --tail N <c>` (非 follow) で各コンテナを2回スナップショット。

## 判定結果
- **rover**: config/include/estimator 読込 → `Estimator: AMCL` → `Console server on port 7720` →
  **`Building nav ready: rid=1, floor=4, cid=15`** → `Executor: SingleThreadedExecutor`。
  `sensor readiness: required_sensors=[]` (#473 のゲートが local.yaml の空宣言を正しく解釈)。
  **Python traceback / 例外なし**。(定期ハートビートログは無い設計 — hb は console 経由のみ。よって後続ログ無しは正常)
- **nav2**: map_server (bld10_4F 528x1828) / amcl が configure→activate、`Managed nodes are active`。
  planner_server は launch 済 (activate は TF 待ちと launch_nav2 が明示)。エラーなし。
- **rf_tf**: `robot_state_publisher: Robot initialized`。エラーなし。
- **bcps_bridge**: 起動するが `http://127.0.0.1:8090` (bcps_sim_server モックBOS) に接続拒否で
  5s 毎に初期化リトライし続ける (WARN、例外死ではない)。下記「要相談」参照。
- Contract WARN: 今回のログには出ていない。

## 確証指摘
- なし (再現する起動失敗なし)。PR は開いていない。

## 要相談 (自動修正しない)
1. **ローカル SIM で bcps_bridge が永久リトライ**: `project_launch.sh:250-257` は EXP 以外で
   `dup bcps_bridge sim <env>` を起動するが、ローカル SIM (diffdrive/cmd 推測) では
   bcps_sim_server (Isaac 側ランタイム経由) が存在しないため `Connection refused` が続く。
   rover 側は「bridge 不在でも接続リトライで待つ」設計 (同ファイル L249 コメント) で bringup は阻害しない。
   #472 で意図的に追加されたため、SIM で bridge を起動しない/モックを同時起動する等は設計判断 → 管理者判断。
2. `[BcpsInterface] doors_bcps.json が見つからない (env=bld10)` WARN — 開扉確認は常に「不明」になる。
   環境リポ (秘匿 /ENV) 側のアセット有無の問題で、本リポ修正対象外。
3. 全コンテナで `XMLPARSER Error realpath failed ... loadDefaultXMLFile` — 既知
   (FASTRTPS_DEFAULT_PROFILES_FILE がホストパスのままコンテナに渡る件。管理者判断待ちの既知事項)。
4. `EV exit auto 判定不能 (cabin_size なし)` WARN — フォールバック動作 (orient) が明示されており良性。

## 未実施 / 権限メモ
- 任意項目の `ros2 topic list` (受動) は未実施。`docker exec rover bash -ic "ros2 topic list -t"` が拒否された。
  拒否メッセージ原文: "Permission to use Bash has been denied because Claude Code is running in don't ask mode."
- `source .acsl/bashrc && dup all SIM local.yaml` (複合コマンド) も同メッセージで拒否 → 素の
  `dup all SIM local.yaml` で実行し成功 (dup はプロファイル経由で PATH 上にあった)。
- `cat .../targets.conf` も同メッセージで拒否 → Read ツールで代替。
- 再現2回は失敗指摘の要件のため、失敗が無かった今回は1回の bringup で判定。

## 後始末
- `docker rm -f rover nav2 bcps_bridge rf_tf` → `docker ps -a` が空であることを確認。

SMOKE_RESULT: PASS

---
**昇格台帳**: base `53a40d15104b` — 残り mode: isaacsim (全 PASS で昇格 = gpull common 展開可)
