# Nightly Audit: backend-smoke — drone × SITL_AP (2026-07-23, host: ruth)

## テーマ / 対象
- theme: backend-smoke (1晩1 backend)。対象 = deploy `drone` (`~/drone`, project drone2) × mode `SITL_AP`。
- targets.conf 確認済み: SITL_AP は drone の許可 modes に含まれる (SIM,SITL_PX4,SITL_GZ_PX4,SITL_AP,SITL_OMNI)。
- 安全則遵守: SITL (純ソフトウェア) のみ。console 接続・arm/takeoff 等の駆動コマンドは一切送っていない。
  検証は bringup とコンテナログのスナップショット (`docker logs --tail N`、非 follow) まで。

## 環境の前提メモ
- `~/drone` は main = origin/main と同期済み (HEAD 085cfd0)。
- 作業ツリーに未コミット変更あり (coop/omni SL 研究系: `config/estimator/sl_coop_omni.yaml`,
  `config/omni/coop_sl.yaml`, `config/reference/sl_takeoff_coop.yaml`, `config/vehicle/PF2_sl_coop.yaml`,
  notebooks, `launcher/launch_dev.sh` 等)。SITL_AP の設定チェーン
  (`config/ardupilot/sitl.yaml` → sensor/none, estimator/direct, controller/pid, reference/*_enu)
  とは交差しないことを include を読んで確認した上で smoke を実施。

## 実行と結果 (2回実施・2回とも同一挙動)
手順: `dup all SITL_AP` (素の1コマンド。Bash ツールはユーザープロファイル初期化のため
`.acsl/commands/scripts` が PATH に入っており、source 前置なしで通った)。

- Run 1: 02:31 JST / Run 2: 02:34 JST。いずれも:
  1. `ardupilot_sitl` (image `ardupilot_sitl_x86` 既存) 起動 → ArduCopter V4.5.7 SITL binary 単独起動
     (`--uartA udpclient:127.0.0.1:14555`, MAVProxy 非介在)。
     `[launch_ardupilot_sitl] using params: /root/sitl.parm` → `SIM_VEHICLE: Adding parameters from (/root/sitl.parm)`
     を確認 (**PR#146 の sitl.parm 無効バグ修正が機能している**)。
  2. `[project_launch] waiting for 'Flight battery' ... WARNING: not found after 90s; continuing anyway`
     (→ 下の要相談 #1。2/2 で再現する決定的挙動)。
  3. `mavros2` 起動 → `CON: Got HEARTBEAT, connected. FCU: ArduPilot` / `FCU: ArduCopter V4.5.7 (b7207551)`
     / `PR: parameters list received` / `WP: mission received`。traceback なし。
  4. `drone2` (image_drone2_x86 フォールバック = harness 正常動作、指摘ではない) 起動 →
     **`[Druth.drone_node]: Drone ready: config_name=sitl, backend=mavros, dt=0.02, hz=50, use_sim_time=False`**
     に到達。MavrosActuator warmup 全 service ready、SET_MESSAGE_INTERVAL 5本 OK、
     `/mavros/state received (0.60s after init)`。**Python traceback / 例外なし** (2回とも)。
  5. `[project_launch] drone2 MAVROS warmup OK`。

- チェックリスト判定:
  - [x] コンテナ起動 (`docker ps` に ardupilot_sitl / mavros2 / drone2)
  - [x] `Drone ready` ログ到達・traceback なし (2/2)
  - [ ] トピック受動確認 (任意項目) — **未実施**。`docker exec` が権限 deny のため
        (拒否原文: "Permission to use Bash has been denied because Claude Code is running in
        don't ask mode.")。bringup 判定はコンテナログで完結しているため PASS 判定には影響なし。
  - [x] 依存バージョン起因の破壊なし (ROS Jazzy / mavros MAVLink 2026.3.3 / ArduCopter 4.5.7 で正常)

- 後始末: `docker rm -f drone2` / `mavros2` / `ardupilot_sitl` を2サイクルとも実施、
  終了時 `docker ps -a` 空を確認。

## 確証指摘 (PR 対象)
なし。再現する起動失敗はゼロ。PR は開いていない。

## 要相談 (PR にしない)
1. **`project_launch.sh:334` の SITL_AP readiness sentinel `"Flight battery"` は現構成では絶対に
   マッチせず、毎回 90 秒フルに待ってから "continuing anyway" になる (2/2 再現・決定的)。**
   - 証拠: `project_launch.sh:334` `wait_for_docker_log ardupilot_sitl "Flight battery" 90 3`。
     Phase 1.5 で MAVProxy を排除したため "Flight battery" (MAVProxy console 出力) は出ない。さらに
     sim_vehicle.py の RiTW が `Window access not found, logging to /tmp/ArduCopter.log` で
     ArduCopter binary の stdout をコンテナログ外へリダイレクトするので、`docker logs` に出るのは
     sim_vehicle 側出力のみ (最終行 `SIM_VEHICLE: Waiting for SITL to exit`)。
   - 影響: SITL_AP bringup が毎回 +90s。実害はそこまで (UDP connection-less なので接続自体は
     その後成立し、mavros2 の `Got HEARTBEAT` 待ちが実質の同期点になっている)。
   - 修正案: sentinel を `docker logs` に実際に出る行 (例: `SIM_VEHICLE: Waiting for SITL to exit` や
     `bind port 5763 for SERIAL2`) に変えるか、`Got HEARTBEAT` 待ちに一本化して待ちを短縮する。
   - `project_launch.sh` はデプロイインフラ (管理者専用・CLAUDE.md で編集禁止) のため自動修正せず要相談。
2. **`Contract: saturation missing=['cascade.state'] mismatched=[]` WARN** (drone2 init 時、2/2)。
   テーマ仕様の試走時と同一で、node は Drone ready に到達 (cascade 入力は実行時に揃う init 時
   チェックの可能性大 = 良性の見込み)。仕様どおり自動修正せず、ros2-structure 柱3 と突き合わせ待ち。

## 捨てた候補
- `dup` の `image drone2_x86 does NOT exists. Use image_drone2_x86` 表示 → テーマ仕様が明記する
  正常フォールバック。指摘ではない。
- docker compose の `DF` / `BASE_IMAGE` / `USER` / `XDG_RUNTIME_DIR` 未設定 warning → 起動に影響なし。
  compose 変数のデフォルト化は infra 設計判断であり smoke の指摘条件 (機能欠落) を満たさない。
- mavros2 の `CMD: Unexpected command 520, result 0` WARN → AUTOPILOT_VERSION 要求への ArduPilot
  応答仕様差の既知ノイズ。機能欠落なし。

## 運用メモ (次回の自分へ)
- ruth の dontAsk 権限では複合コマンド (`source x && dup ...`) と `docker exec` / `cat` は deny。
  素の `dup all <MODE>` は通る (プロファイル PATH 済み)。`docker logs --tail N` / `docker rm -f` /
  `docker ps` / `grep -n` は許可。
- 前回調査 (project_sitl_ap_127_investigation) の「ruth では SITL_AP 正常動作」と整合する結果。

SMOKE_RESULT: PASS
