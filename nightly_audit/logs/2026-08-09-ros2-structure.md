# Nightly Audit 2026-08-09 — ros2-structure

- ホスト: ruth / 実行: 夜間自動監査 (headless)
- 基準線: 前回 2026-07-29 run (logs/2026-07-29-ros2-structure.md)。方針どおり **07-29 以降の差分のみ走査** + 持ち越し状態確認。

## 調べた範囲

- **project_drone2**: 07-29 以降 origin/main にコミットなし (先頭 085cfd0 のまま) → 走査スキップ。前回の全解決状態が基準線として有効。
- **project_rf_rover**: 07-29 以降 約100 PR merge・39 ファイル変更 (`git diff --stat 605f6752 origin/main`)。変更は config 6 + tools 9 + rover_main.py + 新規 `config/robot/` / `robot_spec.py` (機体諸元集約) + isaac_sim スクリプト群。
- 走査: 柱1/柱2 はメインループの grep/Read で全数再照合。柱3 は Explore fan-out 3本 (①機体諸元キー整合 ②reference/phase 契約 ③controller/actuator 差分) → 敵対的検証としてメインループで実コード再読・代入サイト網羅を手動確認。

## 柱1: module 登録の解決性 — 全解決 (指摘ゼロ)

rf_rover の `module:` 登録 12 件 (building_nav 6 / amcl 1 / line_sim 2 / slam 3、実クラス 10 種) すべて実ファイル + `class` 定義 + `def step(` に解決。`results[-1]` 落とし穴 0 件。

## 柱2: yaml 参照解決性 — 全解決 (指摘ゼロ)

- `rover.yaml` include: `controller/building_nav.yaml` ✓ / **新設** `robot/megarover2.yaml` ✓ (rover_main の `_expand_includes` は汎用 {key: path} 展開のため `robot:` キーも解決、欠落時は明示エラー)
- `line.yaml` / `sitl_line.yaml` include: `controller/line_sim.yaml` ✓
- `localizer:` 短名 → `estimator/amcl.yaml` ✓ / `estimator/slam.yaml` ✓
- 機体諸元集約のキー整合: 読み側 22 アクセス vs `megarover2.yaml` 18 leaf キーを全数照合、**欠落キーゼロ** (`_req` 必須 8 キー全実在、デフォルト付き get はデフォルト値まで yaml と同値)。

## 確証指摘 → draft PR (1件)

### PR #324: `door_wait` の解除漏れで目標変更後にローバー恒久停止
https://github.com/acsl-tcu/project_rf_rover/pull/324 (draft)

07-29 以降の新機能 (開扉確認ゲート, PR #314/#317) の導入バグ。`_door_wait` の代入は 4 サイトのみでリセット経路がなく、開扉待ち中に目標変更 → 新経路がエレベータ乗車 (`_legs=[]`) かドア無し経路 (leg 1本) だと `_maybe_advance_leg()` (building_reference.py:878) が早期 return してゲート未再計算 → 古いドア名が metadata で出続け tscf_controller.py:90-98 が毎周期 [0,0]。修正 = `gen_ref()` 冒頭 1 行リセット (真の待機は同一周期内で再セットされるため挙動不変)。py_compile 通過。確信度: 高 (連鎖が静的に閉じる)。
※ `nightly-audit` ラベルは gh label 系 deny (08-08 実測済み) のため未付与。

## 要相談 (新規 — PR 化見送りの理由付き)

1. **実機 (EXP) では開扉確認ゲートが恒久ブロック**: bridge の `door/states` publish は `bcps_ros2_bridge/config/params.yaml:43` `door_status: 0.0` でタイマー不生成 (今回 1.0 にしたのは params.sim.yaml のみ、launch_bcps_bridge.sh:31 で非 sim は params.yaml)。`confirm_open: true` は rover.yaml:155 の共通既定で exp 系が上書きしていない → 実機はドア手前で永久停止。修正候補が「実機 bridge の建屋 API polling 有効化」か「exp での confirm_open 無効化」かは設計判断で、前者は実建屋 API への負荷を伴うため監査 PR 不可。
2. **doors_bcps.json 探索パス乖離**: `bcps_interface.py:170-176` は候補 2 本のみで、`rover_main.py:1186-1199` の 5 候補 (兄弟リポ配置 `../environment_*/config` 含む) と食い違う。rover_main は解決済み `self._env_config_dir` を持つのに BcpsInterface へ渡していない (`rover_main.py:417-424`)。正修正は rover_main 側の注入 = 管理者ファイル。
3. **doors_bcps.json の guid 契約非対称**: rover 側 (`bcps_interface.py:174-175`) はファイルの guid を正とし guid 無し要素を捨てるが、bridge 側 (`bridge_node.py:384-388`) は「doorName のみ使用・guid は API 解決を正とする」と明示。同一ファイルへの要求が矛盾。加えて手元の environment_bld10/yc_bld7 checkout に doors_bcps.json 自体が無く floor_map にも doors セクション無し → 現状ゲートは自己無効化 (機能が複数リポにまたがる作りかけの疑い)。door 系はまとめて管理者確認要。
4. **backin_wall_stop ゲート非対称**: `phase_actions.py:186-197` は「壁フィット成功 (`back_wall is not None`)」で位置到達判定を無効化するが、`obstacle_avoid.py:352-379` は config `backin_wall_stop: false` でも `back_wall` を常時出力 → 機能を無効化すると壁停止イベントが永久に来ず、完了は stall/overshoot 頼みに。現既定 (true) では実害なし。壁可視中の距離完了抑止は PR #263 の意図的挙動のためゲート条件の変更は設計判断。
5. **rear_swing_radius の安全根拠コメント陳腐化 + 妥当性疑義**: 現値 0.1 (building_nav.yaml:47) に対しコメントは「掃引 6〜12cm/周期 ≪ 0.25」(同:45, obstacle_avoid.py:908)。値だけ直すと「6〜12cm ≪ 0.1」となり**数値的に成立しない** (12cm > 10cm) ため機械的コメント修正では済まず、閾値 0.1 で 10Hz 監視が接触前に止まれるかの再確認が要る (安全に関わるため監査では触らない)。
6. **line.yaml の `robot:` 名前空間衝突**: `line.yaml:24-25` の `robot: {initial_pose:...}` が rover.yaml include 展開後の機体諸元 `robot:` と `_deep_merge` で重なる。再帰マージなら無害だが `common/` 未チェックアウトで実装未確認。line 系 config の `robot:` キー改名は生 yaml 直読の消費者 (diffdrive_sim / extract_initial_pose / sitl bridge) に波及するため要設計判断。
7. **check_backin_pending が階を限定していない** (疑い・データ依存): `phase_definition.py:140` → `backin_from()` は現在階の backin テーブルを目標階ノード id で引く。階間で id 重複があると別階走行中に move_elevator が塞がれる。floor_map json がリポ外のため静的確証不能 → backend-smoke 側で確認可。

## 軽微 (PR 化せず記録のみ)

- `obstacle_avoid.py:22` の `back_range_min` デフォルト 0.05 は yaml の 0.15 (RPLiDAR 仕様, PR #249) と不一致。yaml が常に上書きするため実害なし。
- `_creep_latch` (obstacle_avoid.py:32) が orient/backin/standby 経路でクリアされない — 再発火条件が限界的で実害確証なし (疑い)。
- `phase_definition.py:12-13` 未使用 import / phase `go_home` 遷移ゼロで到達不能 — 基準線 (07-29) 以前からの残骸、差分外。
- `megarover2.yaml` の未読キー 3 件 (`lidar_front.y` / `lidar_back.z` / `lidar_back.yaw`) — いずれも yaml コメントで意図明示済みのドキュメント値。
- sim の door status 語彙 "opening"/"closing" (auto_door_runtime.py:683-686) は DoorState.msg の "moving" と不一致だが rover 側は fail-closed で安全側。

## 持ち越し状態確認 (07-29 分)

- **PR #224 / #225: 両方 merge 済み** (81056b4d / 605f6752) → クローズ。
- 要相談 5 件はすべて**残存・状態変化なし** (重複報告せず): ① drone_main.py:533 誤 module パス ② obstacle_avoid `maxw` 生産者ゼロ (行移動 242→299) ③ building_reference `detour_requested` 逆流読み (219→241) ④ contract() 宣言乖離 ⑤ drone2 `.hlc_rc.yaml.swp` (git ls-files で残存確認、手動 git rm 待ち)。

## 権限実測 (追加分)

- `git submodule status` → deny (原文: "Permission to use Bash has been denied because Claude Code is running in don't ask mode")。`git fetch` / `checkout -b` / `add` / `commit -F` / `push -u` / `gh pr create --draft --body-file` は 07-29 実測どおり全通し。
