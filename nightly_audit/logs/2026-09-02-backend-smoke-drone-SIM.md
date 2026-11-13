# Nightly Audit — backend-smoke (drone × SIM)

- 実行日: 2026-09-02 (02:30 JST) / ホスト: ruth
- 対象: deploy=drone (`~/drone`, project drone2), mode=SIM (targets.conf の許可 modes 内)
- 基準: main = origin/main (07e7dc6 "Merge pull request #224 from acsl-tcu/feat/setup-robot-repos")
- 安全則遵守: SIM のみ起動。console 操作 (arm/takeoff 等) は一切送らず、bringup とログ確認のみ。

## 実行内容

```
dup all SIM          # ホスト直 (dup は profile 経由で PATH にあり、source 不要だった)
docker ps            # → drone2 コンテナ Up
docker logs --tail 300 drone2   # 非 follow スナップショットで判定 (2回)
docker rm -f drone2  # 後始末。監査前から存在した他用途の Exited コンテナ (rover/yolo 等) は温存
```

- ホスト競合なし (開始時 `docker ps` は空)。
- `dup all SIM` → `Container drone2 Started` (image は既知のフォールバック
  `image_drone2_x86` を使用。ログの "image drone2_x86 does NOT exists" は正常表示、指摘ではない)。

## 結果: bringup 成功

コンテナログ (要点):

```
[launch_drone2] config_path=/root/ros2_ws/config/sim/pid.yaml agent_index=0
[Druth.drone_node]: Init Drone Control (Orchestrator + Tool chain)
[Druth.drone_node]: Sensor: SIM (in-pipeline), tools=['sim_sensor']
[Druth.drone_node]: Estimator: direct (passthrough)
[Druth.drone_node]: Reference: ['TakeoffReference', 'HoverReference', 'LandingReference']
[Druth.drone_node]: Controller: pid_controller -> saturation
[Druth.drone_node]: Console server on port 7720
[WARN] Contract: saturation missing=['cascade.state'] mismatched=[]
[Druth.drone_node]: Drone ready: config_name=pid, backend=sim, dt=0.02, hz=50, use_sim_time=False
[Druth.drone_node]: GC tuning enabled: freeze + threshold(700,10,1000)
[Druth.drone_node]: Executor: SingleThreadedExecutor
```

- **`Drone ready: config_name=pid, backend=sim` に到達**。Python traceback / 例外なし。
- 起動後しばらく置いた2回目のスナップショットでも新規エラー行なし (standby で静定)。
- 再現するビルド/起動失敗 = **ゼロ**。draft PR は開いていない。

## 要相談 (指摘にはしない)

1. **Contract WARN: `saturation missing=['cascade.state']`** — 2026-06 試走から継続する既知
   WARN。node は ready に到達しており、cascade 入力は実行時に揃う init 時チェックの可能性大
   (テーマ仕様どおり自動修正せず)。ros2-structure 柱3 (契約宣言) と突き合わせて要判断。
2. **Fast-DDS `XMLPARSER Error: realpath failed No such file or directory -> loadDefaultXMLFile`**
   — 起動直後に1回出る (試走レポートには記載がなかった行)。デフォルト profiles XML
   (`DEFAULT_FASTRTPS_PROFILES.xml` or `FASTRTPS_DEFAULT_PROFILES_FILE` 参照先) が
   コンテナ内に無いことによる非致命エラーとみられ、node は正常に ready 到達。
   コンテナ内環境の確認 (`docker exec`) は本監査の権限で deny されたため深追いせず。
   実害の兆候はないが、DDS 設定を意図して置いているつもりなら参照切れの可能性があるので要確認。

## 捨てた候補

- なし (上記2件はいずれも「高確信・機械的修正可」の基準を満たさないため要相談送り)。

## 権限メモ

- 複合コマンド (`source ... && dup ...`)、`docker exec`、Monitor ツールは deny
  (原文: "Permission to use Bash has been denied because Claude Code is running in don't ask mode.")。
  素の `dup all SIM` / `docker ps` / `docker logs --tail` / `docker rm -f` は許可され、
  監査遂行に支障なし。任意項目の ros2 topic 受動確認だけ docker exec deny により未実施。

SMOKE_RESULT: PASS

---
**昇格台帳**: base `04cd06a81929` — 残り mode: SITL_PX4 SITL_AP SITL_OMNI (全 PASS で正式イメージ dpush)
