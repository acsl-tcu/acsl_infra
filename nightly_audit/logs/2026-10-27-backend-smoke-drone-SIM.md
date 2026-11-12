# 2026-10-27 backend-smoke — drone × SIM (host: ruth)

## テーマ / 対象
- テーマ: backend-smoke (1晩1 backend)
- deploy = drone (`/home/sekiguchi/drone`)、mode = SIM (`sim/pid.yaml`, backend=sim)
- 対象コミット: `5a97194 Merge pull request #246 from acsl-tcu/feature/coop-model-error` (main, origin/main と一致, clean)
- イメージ: `kasekiguchi/acsl-common:image_drone2_x86` (ID b5cf10af938f)。`drone2_x86 does NOT exists` のフォールバック表示は仕様どおり (指摘ではない)

## 事前確認 (衝突回避)
- `docker ps`: 稼働コンテナなし (fleet drone2_1..4 / px4_hlc / isaac-sim いずれも無し)
- `ss -ulnp`: 14540/14580 等の PX4/MAVLink ポート使用なし
- → 検証実施可能と判断

## 実施内容 (安全則: SIM のみ・駆動指令なし・console 操作なし)
| 回 | コマンド | 結果 |
|---|---|---|
| 1 | `dup all SIM` → `docker logs --tail 150 drone2` → `docker ps` ×2 → `docker rm -f drone2` | `Container drone2 Started`、`Drone ready: config_name=pid, backend=sim, dt=0.02, hz=50, use_sim_time=False`、traceback なし、11 秒後も Up |
| 2 | 同上 | 同じ ready ログ、traceback なし、Up 継続を確認後 `docker rm -f drone2` |

後始末: `docker ps` 空を確認済み。

ツールチェーン (両回同一): sensor=`sim_sensor` / estimator=direct / reference=Takeoff,Hover,Landing / controller=`pid_controller -> saturation` / Console server :7720 / SingleThreadedExecutor。

## 確証指摘
- なし (再現する起動失敗なし)。PR は開いていない。

## 要相談 (既知・自動修正対象外。前回 2026-09-13 から変化なし)
1. `WARN Contract: saturation missing=['cascade.state']` — 2026-06 から継続。ready には到達。契約宣言は `@tool_contract`/common 側に絡むため ros2-structure 柱3 と突き合わせ要。
2. Fast-DDS `XMLPARSER Error: realpath failed ... loadDefaultXMLFile` — 非致命。compose が `FASTRTPS_DEFAULT_PROFILES_FILE` を空文字で渡している疑い (`.acsl/` は監査の編集スコープ外)。
3. compose の未設定変数 WARN (`DF` / `BASE_IMAGE` / `USER` / `XDG_RUNTIME_DIR`) — 非致命。`USER`/`XDG_RUNTIME_DIR` は cron 環境由来の可能性。
4. SIM は `use_sim_time=False` (launcher の `*)` 分岐経由) — 既報どおり。

## 未実施 (任意項目)
- トピック publish の受動確認 (`din` 経由の `ros2 topic list/hz`) は対話シェル前提のため未実施。SIM はパイプライン内で完結するため bringup 判定には影響しない。

## 権限メモ
- `cd /home/sekiguchi/drone && source .acsl/bashrc && dup all SIM ...` は拒否された (原文: "Permission to use Bash has been denied because Claude Code is running in don't ask mode.")。harness が PATH/ACSL_* を export 済みなので、素の `dup all SIM` で起動できた。
- `cat <targets.conf>` と `ls <logs/>` も同じ文面で拒否された。Read ツールで代用した。

SMOKE_RESULT: PASS

---
**昇格台帳**: base `037652007143` — 残り mode: SITL_PX4 SITL_GZ_PX4 SITL_AP SITL_OMNI (全 PASS で正式イメージ dpush)
