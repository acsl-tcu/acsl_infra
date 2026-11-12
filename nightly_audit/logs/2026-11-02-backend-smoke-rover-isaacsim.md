# Nightly Audit 2026-11-02 — backend-smoke-rover-isaacsim (host: ruth)

## テーマ / 対象
- テーマ: backend-smoke (1晩1 backend)
- deploy = rover (`/home/sekiguchi/rover`, main @ `8e0be030` = origin/main と一致, 追跡ファイルに差分なし)
- mode = isaacsim / config = omni_bld10.yaml
- 起動コマンド: `dup all isaacsim omni_bld10.yaml` (注入どおり一字一句)
- 安全: 実駆動指令は一切送っていない (console 未使用、arm/target/start/cmd_vel なし)。EXP 未起動。

## 実施内容
1. `cd /home/sekiguchi/rover` → `dup all isaacsim omni_bld10.yaml` (rc=0, detached)
2. `docker ps -a` / 各コンテナ `docker logs --tail N <c>` で非 follow スナップショット
3. `docker rm -f` で 6 コンテナを個別削除 → 同じシーケンスを **2 回目** 実行 → 同結果
4. 後始末: `docker rm -f rover_gtlog yolo nav2 rover bcps_bridge rf_tf` → `docker ps -a` が空であることを確認

※ `dup` は PATH 上にあり、`source .acsl/bashrc` は不要だった (`source .acsl/bashrc && dup ...` の形は複合コマンドなので deny)。

## 結果 (2 回とも同一)
起動したコンテナ 6 つ (すべて `Up`):

| container | image | 判定ログ |
|---|---|---|
| rf_tf | image_rf_rover_x86 | `[robot_state_publisher]: Robot initialized` |
| bcps_bridge | image_rf_rover_x86 | `bcps_bridge starting: base_url=http://127.0.0.1:8090/v1` (下記 要相談1) |
| rover | image_rf_rover_x86 | **`[Druth.robot_node]: Building nav ready: rid=1, floor=4, cid=15`** → `Executor: SingleThreadedExecutor` |
| nav2 | nav2_x86 | `map_server` が `bld10_4F_slice` (5521x5572) を読込、`[lifecycle_manager_localization]: Managed nodes are active` |
| yolo | yolo_x86 (GPU) | `[yolo] model ready` / `rgb=/rover_camera/rgb ... -> det=/person_detections` |
| rover_gtlog | image_rf_rover_x86 | `gt_logger: /rover_gt_odom と /amcl_pose を記録 → /tmp/gt_log.csv` |

- どのコンテナのログにも **Python traceback / 例外なし**。
- config 解決 (rover.yaml + omni_bld10.yaml の deep merge、include controller/robot/building/elevator、estimator/amcl.yaml) は正常。
- `Contract:` WARN は出ていない。
- `image rover_x86 does NOT exists. Use image_rf_rover_x86` はフォールバック表示で正常 (指摘ではない)。

## 範囲外・未実施
- **Isaac Sim 本体 (GUI) は `dup all isaacsim` では起動されない** (別途手動起動前提)。そのため今回の smoke は
  ROS 側バックエンドの bringup までを確認した。`/clock`・LiDAR・カメラ・`/rover_odo` は来ないので
  required_sensors の readiness は未充足のまま (smoke では FAIL 条件ではない)。
- 受動トピック確認 (`ros2 topic list`) は権限で拒否されたため未実施。拒否メッセージ原文
  (`docker exec rover bash -lc "ros2 topic list"`):
  > Permission to use Bash has been denied because Claude Code is running in don't ask mode.
  allowlist に `docker exec` を足すなら、この項目も無人で確認できる。
- 過去レポートとの比較はしていない (`ls logs/` が同じメッセージで拒否、Read はディレクトリを開けない)。

## 確証指摘
- なし (再現する起動失敗なし)。PR は開いていない。

## 要相談 (PR 化せず)
1. **bcps_bridge → `127.0.0.1:8090` が Connection refused で 5 秒ごとに再試行し続ける** (2 回とも)。
   `launch_bcps_bridge.sh` は "sim params (bcps_sim_server 向け)" と表示するが、相手の bcps_sim_server
   は `dup all isaacsim` では立たない様子 (Isaac/環境リポ側で起動する想定かは要確認)。
   落ちずに待ち続けるので bringup は阻害しないが、Isaac なしの smoke ではエレベータ/ドア連携は検証できない。
2. `[BcpsInterface] doors_bcps.json が見つからない (env=bld10) — 開扉確認 (door_open) は常に不明を返す` WARN。
   環境リポ (`/ENV/bld10/repo/config`) 側のファイル有無の問題で、rover の修正範囲外。
3. `EV exit auto 判定不能 (cabin_size なし) — orient (回頭降車) で続行` WARN。elevator.yaml / 環境側の
   cabin_size 未定義。fallback (回頭降車) があるので致命的ではないが、意図した設定かは確認したい。
4. 全コンテナで `[XMLPARSER Error] realpath failed No such file or directory -> loadDefaultXMLFile`。
   既知の FastDDS profile 未適用問題 (`FASTRTPS_DEFAULT_PROFILES_FILE` がホストパスのまま)。管理者判断待ちの既存事項。

## 捨てた候補
- `The "DF"/"BASE_IMAGE"/"USER"/"XDG_RUNTIME_DIR" variable is not set` (docker compose warning): 毎回出るが
  起動には無関係で、acsl_infra 側の compose 環境変数の話。指摘にしない。
- `/root/.config/Ultralytics/rover.yaml 不在 → ノード既定トピックで起動` (yolo): トピックは `-p` 引数で明示されており正しく反映済み。良性。

SMOKE_RESULT: PASS

---
**🎖 昇格**: rover の全 mode (SIM:local.yaml,isaacsim:omni_bld10.yaml) が base `037652007143` 由来で PASS。派生イメージは Hub へ push しない方針 — 各ホストは `gpull common` で取り込む (pull + setup full のローカル再ビルド)
