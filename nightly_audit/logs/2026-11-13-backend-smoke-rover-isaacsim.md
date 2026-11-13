# Nightly Audit 2026-11-13 — backend-smoke-rover-isaacsim (host: ruth)

## テーマ / 対象
- テーマ: backend-smoke (1晩1 backend)
- deploy = rover (`/home/sekiguchi/rover`), mode = isaacsim, config = omni_bld10.yaml
- rover HEAD: `12ecea99` (= origin/main, `git fetch origin` 後に up to date を確認)
- 起動コマンド: `dup all isaacsim omni_bld10.yaml` (一字一句そのまま)

## 安全
- 実機・EXP 系は起動していない。console 操作 (start/target 等) も cmd_vel 送出も一切なし。
- Isaac Sim 本体は起動していない (`dup all isaacsim` は rover 側スタックのみを起動し、
  Isaac Sim は別途 GUI で起動する構成)。よってセンサー未受信 = standby のまま (駆動なし)。

## 実施内容
起動前の `docker ps -a` は空 (ホストは空き)。同じシーケンスを **2回** 実施:
`dup all isaacsim omni_bld10.yaml` → `docker ps` → 各コンテナを `docker logs --tail N`
(follow しない) → `docker rm -f rover_gtlog yolo nav2 rover bcps_bridge rf_tf`。

| コンテナ | イメージ | 1回目 | 2回目 | 判定ログ |
|---|---|---|---|---|
| rf_tf | image_rf_rover_x86 | Up | Up | `[robot_state_publisher]: Robot initialized` |
| bcps_bridge | image_rf_rover_x86 | Up | Up | `bcps_bridge starting: base_url=http://127.0.0.1:8090/v1` (以降は接続リトライ。下記) |
| rover | image_rf_rover_x86 | Up | Up | `[Druth.robot_node]: Building nav ready: rid=1, floor=4, cid=15` → `Executor: SingleThreadedExecutor` |
| nav2 | nav2_x86 | Up | Up | `[lifecycle_manager_localization]: Managed nodes are active` (map bld10_4F_slice 5521x5572 読込, amcl active) |
| yolo | yolo_x86 (GPU) | Up | Up | `[yolo_person_node]: [yolo] model ready` → `rgb=/rover_camera/rgb ... -> det=/person_detections` |
| rover_gtlog | image_rf_rover_x86 | Up | Up | `[gt_logger]: gt_logger: /rover_gt_odom と /amcl_pose を記録 → /tmp/gt_log.csv` |

- 両回とも全コンテナのログに **Python traceback / 例外なし**。`Contract:` WARN もなし。
- 後始末: 2回目の後に `docker ps -a` が空であることを確認。

## 確証指摘
なし (再現する起動失敗は無い)。PR は開いていない。

## 観察事項 (指摘にしなかったもの・理由)
1. **全コンテナで FastDDS `XMLPARSER Error realpath failed ... loadDefaultXMLFile`** —
   既知 (`FASTRTPS_DEFAULT_PROFILES_FILE` がホストパスのまま渡り、コンテナ内で XML 未適用)。
   起動は阻害しない。`project_launch.sh:10` / acsl_infra 側の扱いが要る設計判断 = **要相談 (既報)**。
2. **bcps_bridge: `token request failed ... 127.0.0.1:8090 Connection refused` を 5s 毎リトライ** —
   接続先はモック BOS (`bcps_sim_server`)。`dup all` の範囲外で起動されるもので、
   `project_launch.sh:249` のコメントどおりリトライ待ちは設計通り。環境ギャップ扱い。
3. rover WARN `doors_bcps.json が見つからない (env=bld10)` / `EV exit auto 判定不能 (cabin_size なし)` —
   環境リポ側データの有無に依存するフォールバック。bringup は阻害しない。要否は管理者判断 (要相談・軽微)。
4. yolo: `/root/.config/Ultralytics/rover.yaml 不在 → ノード既定トピックで起動` — トピックは
   launch 引数で明示されており実害なし。
5. 受動トピック確認 (任意) は未実施: `docker exec rover bash -lc "... ros2 topic list"` が
   拒否された (原文: "Permission to use Bash has been denied because Claude Code is running in don't ask mode.")。
   なお Isaac Sim 未起動のためセンサー系トピックは元々来ない。

## スコープの注記
本 smoke の PASS は「`dup all isaacsim omni_bld10.yaml` が起動する rover 側 6 コンテナが
2回とも bringup し、ready ログに到達し、例外が無い」ことを意味する。Isaac Sim 本体
(GUI 起動) とのセンサー連携・bcps_sim_server 連携は検証範囲外。

SMOKE_RESULT: PASS

---
**🎖 昇格**: rover の全 mode (SIM:local.yaml,isaacsim:omni_bld10.yaml) が base `53a40d15104b` 由来で PASS。派生イメージは Hub へ push しない方針 — 各ホストは `gpull common` で取り込む (pull + setup full のローカル再ビルド)
