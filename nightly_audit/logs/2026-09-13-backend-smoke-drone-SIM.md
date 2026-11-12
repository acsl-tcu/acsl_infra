# Nightly Audit — backend-smoke (drone × SIM)

- 実行日: 2026-09-13 (02:33 JST) / ホスト: ruth
- 対象: deploy=drone (`~/drone`, project drone2), mode=SIM (targets.conf の許可 modes 内)
- 基準: origin/main = 3a53ebb "Merge pull request #226 from acsl-tcu/feature/coop-cable-rope-chain"
  - 稼働 checkout は開始時 `fix/coop-ext-force-units` (a0c4c98, clean, origin/main を包含) にあった。
    監査基準を main に揃えるため `git checkout --detach origin/main` で一時的に切り替えて smoke を実施し、
    終了時に `git checkout fix/coop-ext-force-units` で元に戻した (作業ツリーは前後とも clean)。
- 使用 image: `kasekiguchi/acsl-common:image_drone2_x86` (efd8664cb663) — `drone2_x86` 不在時の正常フォールバック
- 安全則遵守: SIM のみ起動。console 操作 (arm/takeoff 等) は一切送らず、bringup とログ確認のみ。

## 実行内容

```
git checkout --detach origin/main
dup all SIM                       # 1回目 (02:33:57)。rc=0, "Container drone2 Started"
docker ps                         # → drone2 Up
docker logs --tail 60 drone2      # 非 follow スナップショット
docker logs drone2                # 全文 (短い)
docker inspect -f '{{json .Mounts}}' drone2   # packages/ config/ common/ が checkout から bind mount
docker rm -f drone2
dup all SIM                       # 2回目 (02:34:45)。同じシーケンスで再現確認
docker ps / docker logs --tail 40 drone2 / docker inspect (State=running, ExitCode=0)
docker rm -f drone2               # 後始末 → docker ps -a 空
git checkout fix/coop-ext-force-units
```

- ホスト競合なし (開始時 `docker ps -a` は空。他用途コンテナは存在せず)。
- ソースはイメージ焼き込みではなく checkout からの bind mount
  (`packages/` → `/root/ros2_ws/src/ros_packages`, `config/` ro, `common/` ro)。
  ログの `Config loaded: /root/ros2_ws/config/sim/pid.yaml` も checkout 側を参照している。

## 結果: bringup 成功 (2/2)

コンテナログ (2回目・要点。1回目も同一内容):

```
[launch_drone2] config_path=/root/ros2_ws/config/sim/pid.yaml agent_index=0
[XMLPARSER Error] realpath failed No such file or directory -> Function loadDefaultXMLFile
[Druth.drone_node]: Init Drone Control (Orchestrator + Tool chain)
[Druth.drone_node]: Config loaded: /root/ros2_ws/config/sim/pid.yaml
[Druth.drone_node]:   include sensor: .../config/sensor/none.yaml
[Druth.drone_node]:   include estimator: .../config/estimator/direct.yaml
[Druth.drone_node]:   include reference: .../config/reference/hover.yaml
[Druth.drone_node]:   include controller: .../config/controller/pid.yaml
[Druth.drone_node]: Sensor: SIM (in-pipeline), tools=['sim_sensor']
[Druth.drone_node]: Estimator: direct (passthrough)
[Druth.drone_node]: Reference: ['TakeoffReference', 'HoverReference', 'LandingReference']
[Druth.drone_node]: Controller: pid_controller -> saturation
[Druth.drone_node]: Phase tool map: {'takeoff': ..., 'flight': ..., 'landing': ...}
[Druth.drone_node]: Console server on port 7720
[WARN] Contract: saturation missing=['cascade.state'] mismatched=[]
[Druth.drone_node]: Drone ready: config_name=pid, backend=sim, dt=0.02, hz=50, use_sim_time=False
[Druth.drone_node]: GC tuning enabled: freeze + threshold(700,10,1000)
[Druth.drone_node]: Executor: SingleThreadedExecutor
```

- **`Drone ready: config_name=pid, backend=sim` に 2 回とも到達**。Python traceback / 例外なし。
- 起動後に置いた追加スナップショット (各回) でも新規エラー行なし (standby で静定)。
  `docker inspect` で State=running / ExitCode=0 を確認。
- 再現するビルド/起動失敗 = **ゼロ**。draft PR は開いていない。

## 要相談 (指摘にはしない)

1. **Contract WARN: `saturation missing=['cascade.state']`** — 2026-06 試走から継続する既知 WARN
   (2026-09-02 レポートと同一)。node は ready に到達。テーマ仕様どおり自動修正せず、
   ros2-structure 柱3 (契約宣言) と突き合わせて要判断。
2. **Fast-DDS `XMLPARSER Error: realpath failed ... loadDefaultXMLFile`** — 前回同様、起動直後に 1 回。
   docker-compose.yml は `FASTRTPS_DEFAULT_PROFILES_FILE=${FASTRTPS_DEFAULT_PROFILES_FILE:-}` を
   空文字で渡しており、空パスの realpath 失敗に見える (非致命・ready 到達)。
   意図して未使用なら「空文字ではなく未設定にする」だけで消えそうだが、compose は監査の編集スコープ外
   (`.acsl/` = 管理者領域) のため要相談。
3. **SIM の use_sim_time** — `project_launch.sh` の SIM は `dup drone2 sim/pid.yaml` を呼ぶため
   launcher は `*)` 分岐 (use_sim_time 指定なし → `use_sim_time=False`) を通る。launcher 側に
   `"SIM")` 分岐 (`use_sim_time:=true`) があるが到達していない。in-pipeline SIM は wall clock で
   問題なく動く設計なら現状で良い。動作不良ではなく設計確認事項。
4. **`install/` はイメージ焼き込み** — checkout に `install/` は無く、entrypoint も launcher も
   colcon build を走らせない。`ros2 run drone2` が解決する python パッケージが `--symlink-install`
   で `src/ros_packages` (bind mount) を指しているかは `docker exec` が deny のため未確認。
   symlink でなければ smoke は「イメージ焼き込み時点の drone2 コード + 最新 config」を検証している
   ことになる。昇格台帳の解釈に関わるので確認を推奨 (image-refresh 側の dbuild 手順を参照)。

## 捨てた候補

- なし (上記はいずれも「高確信・機械的修正可」の基準を満たさないか、スコープ外のため要相談送り)。

## 権限メモ

- deny された呼び出し (原文: "Permission to use Bash has been denied because Claude Code is running
  in don't ask mode."): `cat <cwd 外の絶対パス>`, `ls <cwd 外の絶対パス>`, `cd <cwd 外>`, `printenv`。
  cwd (`~/drone`) 外のパス参照は Bash では通らないが Read/Write ツールでは読める/書ける (前回同様)。
- 許可: `dup all SIM` (harness が PATH/ACSL_* を export 済みで source 不要), `docker ps/logs/inspect/rm`,
  `git status/log/checkout/merge-base`, `grep`, `ls <相対>`。
- 任意項目の ros2 topic 受動確認は未実施: `din` は `docker exec -it ... bash` (対話) で、
  `docker exec` 自体が allow リストに無いため。

SMOKE_RESULT: PASS

---
**昇格台帳**: base `dabf4202bbf0` — 残り mode: SITL_PX4 SITL_GZ_PX4 SITL_AP SITL_OMNI (全 PASS で正式イメージ dpush)
