# 夜間監査レポート 2026-09-11 — ros2-structure

- ホスト: ruth / 実行: 無人 (cron)
- 対象: project_rf_rover, project_drone2 (targets.conf kind=repo との積集合)
- 方式: 前回 (2026-08-31) 基準線からの差分走査 + 柱1/柱2 は変更 config の全数再チェック
  (Explore fan-out 2 体 + メインループで git 裏取り。実機・コンテナ操作なし)
- 基準線からの差分:
  - rf_rover: 97bcd9ad → fbfb7997、12 コミット (PR #434 Newton 車輪機体 / #436 max_wz_rate 1.5 /
    #437 plot_log / #438 audit 取り込み)。50 ファイル (isaac_sim 側が大半、tools 6 本 + config 15 本)
  - drone2: 07e7dc6 → 3a53ebb、19 コミット (PR #226 coop ケーブル剛体鎖・二段階離陸・EKF metadata 引き継ぎ)。
    25 ファイル (tools 5 本 + config 5 本 + isaac_sim + tests)
- 両リポとも main・クリーン・origin/main 一致で走査

## 結論: **確証指摘 3 件 → draft PR 3 本 (全 drone2)**。柱1/柱2 は両リポ健全 (新規欠落ゼロ)。新規「要相談」3 件 (M27/M28/M29)。

### 前回 PR の状態
- rf_rover #431/#432/#433 (08-31 生成) は **#438 (chore/audit-followups, 09-10 merge) に取り込まれ main 反映済み**。3 本とも CLOSED (中身は 0946ad6f / a4ac9c19 / 64223b29 として main に在る)。
- docs-drift 側の rf_rover #435 / drone2 #225 #228 は OPEN のまま (本テーマ外・触らず)。

## 開いた PR (すべて drone2 / draft / py_compile 通過)

1. **#229** https://github.com/acsl-tcu/project_drone2/pull/229 —
   fix(controller): **HLCController が 28 次元 xd を黙って捨てる** (da015ac の退行)。
   `time_varying_reference.py:44` が `_DIM = 28` で全軌跡 28 次元を出すのに対し、
   `hlc_controller.py:339/:356` は `shape[0] == 20` 完全一致でしか受け取らず、else 節で pos/yaw/vel だけの
   xd に退行 (acc/jerk/snap FF 消失、警告なし)。該当: `omni/sitl.yaml:94+105` (flight circle 等)、`sim/hlc.yaml:24`、
   `px4/sitl_gazebo_hlc.yaml:24,31`。修正 = `_take_xd20()` で 20 次元以上なら前半 20 を切り出す (docstring
   `time_varying_reference.py:5-6`「単機 HLC は前半 20 次元だけを使い」の設計どおり)。
   反証確認: 28 次元を出す SL 系 reference と HLCController が組む phase は無い (landing の SLLandingReference は
   親 LandingReference の 20 次元、`sl_landing_reference.py:15` / `landing_reference.py:91`)。
2. **#230** https://github.com/acsl-tcu/project_drone2/pull/230 —
   fix(reference): SLTakeoffReference の**フェーズ外リセットが `_z_stop` を捨てない** (fde696f)。
   `on_activate()` (:121-126) は捨てるが `step()` のフェーズ外分岐 (:161-168) は捨てず、二段階の再計算が
   無効化側 (:230-238、pL_raw 不在等) に落ちると `:248 if self._z_stop is not None` で前回離陸の停止高度を
   使う。on_activate は `common/acsl/framework/tool_category.py:103-106` により**新規有効化ツールにしか呼ばれない**
   (稼働 checkout で確認) ので、同 reference のまま takeoff→standby→takeoff の経路で顕在化。1 行追加。
3. **#231** https://github.com/acsl-tcu/project_drone2/pull/231 —
   fix(controller): HLC-SL `_effective_P()` の 3 return のうち **mL 不在の早期 return (:302) だけ
   `_apply_ext_force()` を通らない** (4c6ba63)。両フラグ true 時に mL が一瞬欠けると P[7],P[8] (dst) が
   そのステップだけ 0 に戻る。他 2 経路 (:287/:329) と同形に統一。既定 (両フラグ false) では到達しない。

いずれもラベル `nightly-audit` は権限制約 (gh label 系 deny) で付与できず、PR 本文に監査生成の注記を明記。
pytest / flake8 も deny (原文: "Permission to use Bash has been denied because Claude Code is running in
don't ask mode") のため検証は py_compile のみ。PR 本文で `colcon test` / SIM 確認をレビュー時に依頼。

## 網羅範囲 (柱1/柱2)

### 柱1: module: 登録の解決性 — 全解決
- rf_rover: **12/12** (building_nav 6 + line_sim 2 + amcl 1 + slam 3) + rover_main.py の直 import/遅延 import
  18 件 (Nav2PathClient / BcpsInterface / BUILDING_INTERFACE は step 無しの注入ヘルパで正)。
  cascade 名文字列 (rover_main:342-344 / :317-326) と各クラス `name` 属性も一致。
- drone2 (変更 config の連鎖): coop_sl.yaml → extends sitl_sl.yaml → include/phases/vehicle を辿った **10 クラス
  全解決** (hlc_sl / hlc / direct / sl_state_adjust / ekf_sl_dynamics / sl_takeoff / sl_coop / sl_landing /
  sl_flight / sl_settle)。phase の短名 (`["sl_state_adjust", "ekf_sl_dynamics"]` 等) も `name` 属性と一致。

### 柱2: yaml/json パス参照の解決性
- rf_rover: include 6 + estimator 自動ロード 2 + line 系 2 = **全実在**。新規 `config/plot/default.yaml` は
  `plot_log.py:229` と `console:115-117` が読み、キー (figure/panels/traces/…) は全て読み手と一致・未読キーなし。
  `setup.py:32` の新 entry point `lidar_blind_probe:main` は `lidar_blind_probe.py:162` に実在
  (スタンドアロン rclpy Node、Tool ではない = step 無しで正)。
- drone2: 5 変更 yaml + 継承元 sitl_sl.yaml の参照 **全実在** (extends 1 / include 3 / reference 7 / vehicle 2 /
  isaac_sim スクリプト 3)。`rope:` ブロック 12 キーは `set_coop_drones.py` → `lib/rope_chain.py` で**全て消費**。
  M16 の欠落 2 本 (bld10_4f.json / yc_bld7_3f.json) は残存。
- 重複キー: 両リポの変更 yaml (robot 7 + building/exp/rover/omni 5 + drone2 5) に**重複キーなし** (前回 #433 の再発なし)。

### 柱3: 変更 tool の契約・config 整合
- rf_rover: ObstacleAvoid の yaml 27 キー全て defaults に在り / Saturation の新 `min_v_eff`・`min_wz_eff` は
  `robot_spec.derive_saturation_params` (rbq10/go2 の drive.*) から供給 / BuildingSensor の
  `front|back_blind_sectors_deg` は 7 機体 yaml 全てに `blind_sectors_deg` があり供給 / phase_actions の
  `pc.<attr>` 57 種は全て PhaseContext フィールド (新 `ev_exit_*` 含む) / rover_main 新 import 4 関数実在。
- drone2: hlc_sl_coop.yaml の全キーが `@config_params` defaults に在り、新 6 キー (load_mass_tau/max,
  use_estimated_ext_force, ext_force_key/max/tau) は定義・読取とも確認 / EKF の `src` は :500 で束縛済み
  (:519 の参照は安全) / `mL_freeze_until_lifted` は sl_coop_omni.yaml:47 の正しい tool ブロック /
  `sl_state_adjust._lifted` は __init__ :70 で初期化 / sl_takeoff_coop.yaml の新 5 キーはファイル直下
  (drone_main.py:499-506 が残り全体を config として渡す) で cableL 等と同じ階層 = 正 /
  `cos_derivs(amp, w, phase, t, levels)` は sl_trajectory.py:19 に実在。

## 新規「要相談」 (M27〜M29。M22〜M26 は docs-drift 09-10 が使用済み)

- **M27 (高価値・rover_main.py 管理者領域): single_lidar 機体の back LiDAR リマップが rover.yaml に必ず上書きされ不到達**。
  `robot_spec.py:171-172` は `sensors.single_lidar: true` で `lidar_back_topics = ["/scan_front"]` を注入するが、
  `rover_main.py:203-205` が `scan.back_topics` が truthy なら無条件で上書きし、`rover.yaml:190-192` は常に
  back_topics を定義している (上書きを消す top-level config も無い)。該当 whill.yaml:42 / rbq10.yaml:42 /
  go2.yaml:58 (`/scan_back` は `sim_create: false` で誰も publish しない) → `BuildingSensor._scan_back` が空のまま、
  ObstacleAvoid の後方系 (機尾振れガード bL/bR・後壁フィット・backin 停止) が無言で無効化。
  導入順: d840237d (scan_cfg 上書き) → 38197f7a (single_lidar 注入) で後者が前者に負ける。
  修正案 = `:203-205` を `"lidar_back_topics" not in sensor_config` でガード、または `**sensor_layout` の展開を
  scan_cfg ブロックの後へ移す。rover_main.py のため PR 化せず。
- **M28 (rover_main.py / phase_context.py): home_backin の 4 パラメータに config 供給源が無い**。
  `phase_context.py:38-48` の `backin_speed / backin_reach_tol / backin_stall_sec / backin_overshoot_max` は
  コメントで「rover.yaml から注入可」とあるが、`rover_main.py:518-578` の PhaseContext 構築は渡しておらず、
  config/ にもキーが無い (grep 0 件)。CLAUDE.md「デフォルトはコードにハードコードしない」に反するが、
  注入は rover_main.py 側の変更なので要相談。同種: `rover_main.py:1573` の `cabin_turn_margin` (既定 0.05) も
  elevator.yaml に未記載 (他の elevator キーは全て記載済み) — こちらは config 追記だけで済むので次回 PR 候補。
- **M29 (drone2 config・設計判断): coop_sl.yaml の `omni.cableL` だけ 2.98 (継承値)**。
  `coop_sl.yaml:18-25` は `omni:` を上書きするが cableL を書かず `sitl_sl.yaml:29` の 2.98 (アセット鎖の USD 実測)
  を継承。coop は生成ケーブル (`rope.length: 3.0`、アンカー→Hook 中心) で、他の cableL は全て 3.0
  (`coop_sl.yaml:112`、`sl_coop_omni.yaml:15,36`、`PF2_sl_coop.yaml:22`、`sl_takeoff_coop.yaml:8`、
  `sl_landing_coop.yaml:9`)。`omni_sensor.py:109` が読み `:215` wL = pT×(vL−v)/L と `:205` フォールバック pL に効く。
  `coop_sl.yaml:237-238` の「必ず同値に」リストにも omni.cableL が漏れている。差 0.7% で実害は小さく、
  「生成鎖の実効長をどう測るか」は作者判断のため、`omni: cableL: 3.0` 1 行追記の提案に留める。

## 軽微 (PR 化せず記録のみ — 次回再報告しない)

- rf_rover `building_nav.yaml:155` `Saturation.maxv` は `rover_main.py:873-877` が毎ループ上書きする死に config
  だが注釈は `maxw` (:156) にしか無い (`line_sim.yaml:15-16` は逆に maxv のみ注釈)。注釈追記のみ → 次回 PR 候補。
- rf_rover `omni_yc_bld7.yaml:43` `normal_maxv: 1.5  # iw.hub 実機最高速` — 機体は rover.yaml:29 の include
  (megarover2) で決まり、この yaml は機体を切り替えない。値の根拠コメントが機体事実と層違い。
- rf_rover `plot_log.py:59-60` の `_REPO_ROOT` は `__file__` 相対 (realpath 無し)。console 経由はソースツリーを
  PYTHONPATH に載せるので正。install 空間から import した場合のみ default.yaml 解決に失敗しうる (条件付き)。
- drone2 `sl_takeoff_reference.py:104,108` `self._z_stop = None` が __init__ で二重 (無害)。
- drone2 yaml 内のコメントと値の矛盾 2 件 (docs-drift 観点): `sl_coop_omni.yaml:4-5`「estimate_ext_force:true で回し」
  vs `:60 false` / `coop_sl.yaml:39-42`「EKF は不要」vs `:64,69,77` で EKF 有効 (直後のコメント :56-63 が復帰経緯)。
- drone2 契約宣言の乖離 (既存 要相談④に追記): `sl_state_adjust.py:45-47` outputs は state のみで、下流が依存する
  `lifted` (:243 → EKF :519-521) / `pL_raw` (:238 → sl_takeoff :178) が未宣言。EKF の入力宣言は `sensor.state` だが
  実際は `get_cascade_input()` (:388) が主。宣言未整備は系統的なため個別 PR 化しない。

## 持ち越し「要相談」の状態変化 (12 件 + M16/M17/M20/M21)

- **解消 0**。個別確認 (基準線以降の差分で):
  - M20 (amcl yaw 相補フィルタ不到達): `amcl_estimator.py` 変更なし。`amcl.yaml:10 seek_enabled: false` / `:191` 早期 return / `:252-259` フィルタの構図そのまま — 残存。
  - M21 (odo 二重書き疑い): `building_sensor.py` は盲区間追加のみ。`:263` と `:332` が両方 `odo` ゲート — 残存 (行番号 +8)。
  - #5 rear_swing コメント: `building_nav.yaml:62`「≪ 0.25」残存 (値 :64 は 0.1)。
  - maxw 生産者ゼロ: `obstacle_avoid.py:373` `prev.metadata.get("maxw", 1.5)` — 残存 (行 353→373)。
  - drone_main.py:533 誤 module パス: drone_main.py は基準線以降変更なし — 残存。
  - drone2 `config/controller/.hlc_rc.yaml.swp`: git ls-files に残存。
  - M16: `config/paths/` は yc_bld7_1f4f / _v2 / 3f4f の 3 json のみ。欠落 2 本 + `spline_path_reference.py:18` 既定も欠落側 — 残存。
  - #2 探索パス乖離 / #4 / detour_requested / M17 / #1 #3 #6 #7: 関連行に差分なし — 残存。

## 捨てた候補と理由

- M27 の PR 化: 修正箇所が rover_main.py (管理者のみ) → 要相談。config 側の回避 (`scan.back_topics: []`) は
  _deep_merge のリスト置換挙動に依存し、根本修正でないため見送り。
- M28 / cabin_turn_margin: 前者は rover_main.py の注入変更が要る。後者は config 追記のみで可能だが、今夜の PR 枠
  (3 本) を drone2 の実バグ 3 件に充てた → 次回。
- M29 の PR 化: 2.98 (実測) と 3.0 (設計値) のどちらを coop の真とするかは作者判断 → 要相談。
- Saturation.maxv 注釈: 同上 (PR 枠) → 次回候補。
- drone2 yaml コメント矛盾 2 件: どちらが正か (コメント or 値) は作者の意図確認が要る → docs-drift 側で軽微記録。
- 契約宣言の乖離: 系統的 → 既存④に追記のみ。
- escape_side_clear 等デッドパラメータ: 前回記録済み・再報告しない。

## メモ (次回向け)

- 次回 ros2-structure の基準線: **rf_rover fbfb7997 / drone2 3a53ebb** (2026-09-11 origin/main)。
- PR #229/#230/#231 (drone2) の merge 状況を次回確認。
- 次回 PR 候補 (config/注釈のみ・低リスク): rf_rover elevator.yaml へ `cabin_turn_margin: 0.05` 追記 /
  building_nav.yaml:155 と line_sim.yaml:16 の maxv/maxw「rover_main が上書き」注釈そろえ。
- 権限実測 (追加分): `python3 -m pytest` と `python3 -m flake8` は **deny** (原文は上記)。`python3 -m py_compile` は許可。
  稼働 checkout `~/drone/common/acsl/` は Read/grep 可 (framework の挙動裏取りに使える。ソースクローンには common 無し)。

> 夜間自動監査 (nightly-audit) が生成。
