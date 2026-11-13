# 2026-11-13 backend-smoke: drone × SIM (pid.yaml) — ホスト ruth

## 対象・範囲
- deploy = drone (`/home/sekiguchi/drone`, main @ f846f9a, clean, origin/main と同期)
- mode = SIM, 起動コマンド: `dup all SIM pid.yaml` (→ `sim/pid.yaml`)
- イメージ: `kasekiguchi/acsl-common:image_drone2_x86` **e626420c3a38**
  (11/7〜11/10 に ImportError FAIL が出たのは 71ed265e90d2。その後イメージが入れ替わっている)
- 事前確認: `docker ps -a` は空 (fleet/px4_hlc 等の利用者コンテナ無し)、`ss -ulnp` に PX4/MAVLink ポートの衝突無し
- 安全: SIM のみ。console 接続無し、arm/takeoff 等の駆動指令は一切送っていない

## 結果: 2/2 PASS
| run | 起動 | `Drone ready` | traceback | 備考 |
|---|---|---|---|---|
| 1 (13:07:15) | drone2 Up | 到達 (`config_name=pid, backend=sim, dt=0.02, hz=50`) | 無し | Executor 起動まで確認 |
| 2 (13:07:28) | drone2 Up | 到達 (同上) | 無し | 同上 |

ログ抜粋 (run 2):
```
[Druth.drone_node]: sensor readiness: required_sensors=[] (必須外部センサー無し)
[Druth.drone_node]: Controller: pid_controller -> saturation
[WARN] [Druth.drone_node]: Contract: saturation missing=['cascade.state'] mismatched=[]
[Druth.drone_node]: Drone ready: config_name=pid, backend=sim, dt=0.02, hz=50, use_sim_time=False
[Druth.drone_node]: Executor: SingleThreadedExecutor
```

- **11/7〜11/10 の `validate_category_contracts` ImportError (acsl v0.8.0 退行) は今回のイメージでは再現しなかった**
  (`drone_main.py` の import を通過して Ready まで到達)。イメージ再ビルドまたは update_common が実施されたとみられる。
  ただし恒久対策 (`dockerfile.base_ros_*` の `project_common@v0.8.0` 固定の引き上げ) が入ったかは未確認 → 要相談のまま継続
- PR #254 (required_sensors / readiness ゲート) 以降の SIM 起動経路も正常に動いている

## 良性 / 既知 (指摘にしない)
- `Contract: saturation missing=['cascade.state']` WARN: これまでと同じ init 時チェックで、Ready には到達する。自動修正はせず、ros2-structure 柱3 と突き合わせる (要相談・継続)
- `XMLPARSER Error realpath failed ... loadDefaultXMLFile`: Fast DDS が既定の XML プロファイルを探して見つからなかったことを示す表示で、動作には影響しない
- `image drone2_x86 does NOT exists. Use image_drone2_x86`: harness が正常にフォールバックしたことを示す表示
- compose の `DF` / `BASE_IMAGE` 未設定 WARN: 起動には影響しない

## 実施できなかったこと (権限)
- 任意の受動チェック (コンテナ内の acsl version と import 確認) は deny されたため未実施。
  拒否メッセージ原文: "Permission to use Bash has been denied because Claude Code is running in don't ask mode."
  (`docker exec drone2 /root/.venv/bin/python -c ...`、`docker image inspect --format ...` の 2 件)

## 後始末
- 各 run 後に `docker rm -f drone2` を実行し、最終的に `docker ps -a` が空であることを確認した

## 指摘 / PR
- 確証指摘: 0 件、PR: 無し

SMOKE_RESULT: PASS

---
**昇格台帳**: base `53a40d15104b` — 残り mode: SITL_PX4 SITL_GZ_PX4 SITL_AP (全 PASS で昇格 = gpull common 展開可)
