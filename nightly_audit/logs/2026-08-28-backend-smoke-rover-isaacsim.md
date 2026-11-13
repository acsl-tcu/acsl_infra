# Nightly Audit — backend-smoke (rover × isaacsim)

- 実行日: 2026-08-28 (02:31–02:40 JST) / ホスト: ruth
- 対象: deploy=rover (`~/rover`, project rf_rover) / mode=isaacsim (targets.conf 許可済)
- 安全則遵守: SIM 系のみ。console 操作・駆動指令は一切送っていない (bringup とログ観察のみ)。

## 前提 (checkout 状態)

- `~/rover` は main = origin/main (50f2bf7, PR #374 merge) と同期済み。
- ローカル未コミット差分あり (ユーザー作業・未変更のまま温存):
  - `config/rover.yaml` — robot include の代替候補 2 行を**コメントとして**追加のみ。有効設定は不変。
  - `config/omni_yc_bld7.yaml` — `rover_spawn_node_index: 21→19`。今回使う既定 config は
    `omni_bld10.yaml` のため smoke に影響なし。
  - 未追跡 `isaac_sim/scene_setup_progress.log` (影響なし)。
- 実質 origin/main 相当の状態で検証できたと判断。

## 実行内容 (テーマ手順どおり・2 回再現)

```
dup all isaacsim        # 1回目 02:31, 2回目 02:34 (間に docker rm -f で全片付け)
docker logs --tail N <container>   # 非 follow スナップショットで判定
docker inspect -f "... restarts=..." (5 コンテナ)
docker rm -f rover nav2 rf_tf bcps_bridge yolo   # 後始末 (docker ps -a 空を確認)
```

### 結果 (2 回とも同一・クリーン)

| コンテナ | イメージ | 判定 |
|---|---|---|
| rf_tf | image_rf_rover_x86 (fallback) | `robot_state_publisher: Robot initialized` ✔ |
| bcps_bridge | image_rf_rover_x86 (fallback) | 起動 ✔。モック BOS (127.0.0.1:8090) へ接続リトライ中 (設計どおりの待機 — 下記) |
| rover | image_rf_rover_x86 (fallback) | **`Building nav ready: rid=1, floor=4, cid=15`** 到達 ✔ traceback なし |
| nav2 | nav2_x86 | 起動 ✔。map transform 待ち INFO ループ (Isaac Sim 未起動なのでスキャンが無い = 想定内) |
| yolo | yolo_x86 | `[yolo] model ready` + `/person_detections` 配線 ✔ |

- config 解決も正常: `Config: config/omni_bld10.yaml localizer=amcl map=bld10_{floor}F_slice initial_pose=[85.0, 38.2, 3.14159] initial_floor=4`。
- 全 5 コンテナ `restarts=0 / running` (両 run)。Python traceback ゼロ。
- `image rf_tf_x86 does NOT exists. Use image_rf_rover_x86` 等はテーマ既知の正常フォールバック表示 (指摘ではない)。

## 検証範囲の境界 (明記)

- **Isaac Sim 本体は起動していない**。`dup all isaacsim` は ROS 側スタックのみ起動する設計で、
  Isaac Sim 本体は `disaac` (GUI 対話・`-it`・DISPLAY=:0・起動後にシーンスクリプトを手動 exec)
  で別途立てる運用。無人夜間監査では対話 GUI は扱えないため対象外とした。
  → 本 PASS は「isaacsim モードの ROS 側スタック bringup」の PASS であり、Isaac Sim 連携
  (センサループ・トピック疎通) までは保証しない。
- **任意項目の受動トピック確認は権限 deny でスキップ**。拒否原文 (ホスト `ros2 topic list` と
  `docker exec rover ros2 topic list` の両方):
  > Permission to use Bash has been denied because Claude Code is running in don't ask mode.
  代替として nav2/yolo/rover のログでノード活動を確認した (rc やコマンド不存在ではなく明示 deny)。

## 指摘 (再現する起動失敗)

**なし** (2 回とも bringup 成功)。PR は開いていない。

## 要相談 (PR 化せず記録)

1. **`FASTRTPS_DEFAULT_PROFILES_FILE` がホストパスのままコンテナへ渡り、全コンテナで
   FastDDS プロファイルが黙って未適用**
   - 証拠: `project_launch.sh:10` が全モード共通で
     `FASTRTPS_DEFAULT_PROFILES_FILE=${ACSL_WORK_DIR}/isaac_sim/config/fastdds_udp_no_shm.xml`
     (=`/home/sekiguchi/rover/...`) を export → `.acsl/docker/docker-compose.yml:71` が素通しで
     コンテナへ注入 (docker inspect で確認)。コンテナ内ワークスペースは `/root/ros2_ws` なので
     このパスは存在せず、全コンテナログに毎回
     `XMLPARSER Error realpath failed No such file or directory -> loadDefaultXMLFile` が出る。
   - 影響: `FASTDDS_BUILTIN_TRANSPORTS=UDPv4` (compose 既定) で「UDP のみ・SHM 無効」は
     カバーされるが、XML 側にしかない `maxMessageSize=1400` / `intraprocess_delivery OFF` /
     送受信バッファ設定 (`isaac_sim/config/fastdds_udp_no_shm.xml:12-31`) は効いていない。
   - PR にしない理由: 設計判断が要る。compose のコメント (`docker-compose.yml:60-67`) は
     「native Linux 既定は上限なし UDPv4。max_msg_size=1400 は RViz の /map 受信を壊すので
     既定から撤去した」と明記しており、XML の 1400B 制限をコンテナに効かせる方向が正しいのか
     自体が論点 (Isaac 高レート topic のクラッシュ回避 vs /map 配送)。`project_launch.sh` は
     管理者相談ファイルでもある。→ 管理者判断: (a) 現状維持で launch 側の export を撤去して
     エラー行を消す / (b) コンテナ側パス (`/root/ros2_ws/isaac_sim/config/...`) に変換して渡す。
2. **`doors_bcps.json` 不在 (env=bld10)** — rover WARN「開扉確認 (door_open) は常に不明を返す」。
   環境リポ `/ENV/bld10/repo/config` にカタログが無い。自動ドア開扉ゲート有効設定と噛み合って
   いるかは環境リポ側の整備問題 (rover コードの問題ではない)。
3. **EV `cabin_size` なし** — WARN「EV exit auto 判定不能 — orient (回頭降車) で続行」。
   `config/building/elevator.yaml` の整備待ちか意図的既定かの判断が要る。
4. **bcps_sim_server (モック BOS) は `dup all isaacsim` では起動されない** — bcps_bridge は
   127.0.0.1:8090 へ 5s 間隔の接続リトライを続ける (Connection refused)。`project_launch.sh:237`
   に「bridge 不在でも rover 側は接続リトライで待つ」とあり設計どおりだが、smoke では EV/ドア
   経路が常に未検証のまま PASS になる。モックサーバーを smoke に含めるべきかは壁打ち事項。

## 捨てた候補と理由

- nav2 の `Timed out waiting for transform map→base_footprint` INFO 連発 — Isaac Sim 未起動で
  スキャン/odom が無い状況の想定内動作。起動失敗ではない。
- yolo の `WARN /root/.config/Ultralytics/rover.yaml 不在 → ノード既定トピックで起動` —
  launcher が `-p rgb_topic:=...` を明示指定しており機能影響なし。
- イメージフォールバック表示 (`rf_tf_x86 does NOT exists` 等) — テーマ仕様に「指摘ではない」と
  明記済みの正常動作。

## 後始末

対象 5 コンテナを名前指定 `docker rm -f` で削除し、`docker ps -a` が空であることを確認済み。
ローカル未コミット差分・未追跡ファイルは触っていない。

SMOKE_RESULT: PASS

---
**昇格台帳**: base `04cd06a81929` — 残り mode: SIM (全 PASS で正式イメージ dpush)
