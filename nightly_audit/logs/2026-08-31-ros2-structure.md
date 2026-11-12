# 夜間監査レポート 2026-08-31 — ros2-structure

- ホスト: ruth / 実行: 無人 (cron)
- 対象: project_rf_rover, project_drone2 (targets.conf kind=repo との積集合)
- 方式: 前回 (2026-08-20) 基準線からの差分走査 + 柱1/柱2 は全数再チェック
  (Explore fan-out 3 体 + メインループで git 裏取り。実機・コンテナ操作なし)
- 基準線: rf_rover = 175f143c 以降 **約 90 コミット** (PR #385〜#430、whill/jackal/iw_hub/
  nova_carter/go2/rbq10 の 6 機体追加 + EV 乗降ナビ大改修)、drone2 = 82d1278 以降 14 コミット
- 両リポとも main・クリーン・origin/main 一致の状態で走査 (前回のユーザー WIP
  `feature/env-phase2` は解消済み)

## 結論: **確証指摘 3 件 → draft PR 3 本 (rf_rover)**。柱1/柱2 の参照解決は両リポとも健全 (新規欠落ゼロ)。新規「要相談」2 件 (M20/M21)。

## 開いた PR (すべて rf_rover / draft / 検証済み)

1. **#431** https://github.com/acsl-tcu/project_rf_rover/pull/431 —
   docs(config): rover.yaml:48 の `odom_source: dr` 注釈が実装と乖離
   (「dr = /rover_navodo」とあるが、navodo を購読するのは `odo` 分岐
   building_sensor.py:255。`dr` はどの分岐にも一致せず「何も購読しない」値で、
   line.yaml:20 の注釈が正)。コメントのみの修正、動作差ゼロ。
2. **#432** https://github.com/acsl-tcu/project_rf_rover/pull/432 —
   refactor: 未使用 import 3 件除去 (obstacle_avoid.py:15 `front_min` /
   building_reference.py:10 `math` / phase_context.py:7 `field`)。
   repo 全体 grep で未使用を全数確認、py_compile 3 ファイル通過。
3. **#433** https://github.com/acsl-tcu/project_rf_rover/pull/433 —
   fix(config): megarover2.yaml `sensors.lidar_front` 内の **`min_range` 重複キー**
   (L39: 0.10 / L45: 0.15)。git log -L で確証: d840237d が 0.15 を先に書き、
   9e772fe4 (EV 乗車の壁フィット修正) が 0.10 を上に追加して重複発生。YAML 後勝ちで
   実効 0.15 となり、新しいコミットの意図 (0.10、EV 至近有効判定) が negated。
   後行 0.15 行を削除して 0.10 を実効化 (sim は sim_create:false + front_lidar.py:64 の
   既定 0.15 フォールバックで無影響)。**実機の front_range_min が 0.15→0.10 に変わる**点は
   PR 本文でレビュー観点として明示済み。

いずれもラベル `nightly-audit` は権限制約 (gh label 系 deny) で付与できず、PR 本文に監査生成の注記を明記。

## 網羅範囲 (柱1/柱2 全数)

### 柱1: module: 登録の解決性 — 全解決
- rf_rover: **12/12** (building_nav 6 + line_sim 2 + amcl 1 + slam 3)。全て実ファイル +
  class + `def step(` に解決。コメントアウト登録 0。新機体 6 追加でも module 登録は不変。
- drone2: **107/107 有効登録** (109 行中 2 行は ekf_sl.yaml:11,13 のコメントアウト・
  参照先クラスは実在)。30 ユニーククラス全解決。継承 2 件 (SLLandingReference /
  MocapSLSensor) も自前 step を保持。

### 柱2: yaml/json パス参照の解決性
- rf_rover: include 6 + estimator 自動ロード 6 + リポ内パス 4 + runtime_behaviors 9 =
  **25/25 実在**。新機体 7 robot yaml のアセット参照は全て `/ENV/` (環境資産・対象外) か空。
  短名レジストリ 18 件 (backend/localizer/policy 等) は対象外として列挙のみ。
- drone2: 197 行 (72 ユニーク) 中、**欠落は既知 M16 の 2 件のみ** (bld10_spline_4f.yaml:4 /
  yc_bld7_spline_3f.yaml:4 → paths json 不在)。今回変更の omni/*.yaml (coop_sl, sitl*) は
  全参照解決。新たに `extends:` 継承 6 箇所も走査し全解決。

### 柱3: 変更 tool ファイル (rf_rover 10 本) の静的整合
- saturation.py / rplidar_safety.py: clean。
- config キー整合: building_nav.yaml / rover.yaml の全キーが実装で読まれておりタイポ落ちなし
  (下記 M20/M21/軽微を除く)。
- sensor parallel の `results[-1]` 前提: rover_main は sensor_cat に 1 tool のみで破綻なし。

## 新規「要相談」 (M20/M21。M18/M19 は docs-drift 08-30 が使用済み)

- **M20: amcl_estimator の yaw 相補フィルタが全デプロイ config で不到達 (確証・高価値)**。
  PR #393 (89a3ac06) が追加した yaw_blend_k フィルタ (amcl_estimator.py:252-259) は
  `self._converged` ブロック内にあるが、`seek_enabled` は estimator/amcl.yaml:10 の
  `false` のみで上書き無し → L191 の早期 return が常に先行し**一度も実行されない**。
  同ファイル L170-172 のコメントが dr_hold で同一の配置バグを直した経緯を明記しており、
  yaw フィルタだけ同じ罠に残った形。修正は「フィルタを新規に発火させる」推定挙動の変更で、
  nav_odom 取得・_yaw_odom_prev 更新の並べ替えも要る (単純移動では済まない)。
  SIM 起動検証がこの環境で不能 (backend-smoke ハーネス既知障害) のため PR 化せず要相談。
  回頭オーバーシュート改善 (PR #393 の目的) が実は効いていない可能性を作者に確認されたい。
- **M21: `odom_source: odo` で `_nav_odom` の書き手が二重 (疑い)**。
  building_sensor.py:255 (/rover_navodo, Odometry) と :324 (/rover_odo, Twist 積分) が
  両方 `odo` で有効。両トピック併存環境では後勝ちで一方の積分が毎周期破棄され、odom TF も
  二重 broadcast になり得る。実機で片方しか出ていなければ無害。どちらを `odo` の正とするか
  (あるいは navodo に別値を割るか) は設計判断。#431 のコメント修正はこの論点に踏み込まず
  `dr` の記述のみ直した。

## 軽微 (PR 化せず記録のみ — 次回再報告しない)

- rover.yaml:54 デフォルト `floor_map: maps/bld10_{floor}F_exp1` は環境リポに 1F/4F の
  2 枚しか無く、素の rover.yaml 起動で 2F/3F/5F 遷移時に解決不能。実運用 config は全て
  `_slice` 系で上書きするため露出しない。どのマップをデフォルトにするかは設計判断。
- tscf_controller.py:51 の `dt: 0.1` は rover.dt と独立供給 (現状一致・rover.dt 変更で無言乖離)。
- phase_actions.py:67-76 の if/elif で backout 経路が floor_changed/elevator_done リセットを
  飛ばす (疑い。実経路では standby / rover_main:1220,1239 がリセットし顕在化せず)。
- obstacle_avoid.py の `escape_side_clear` / `escape_center_gain` が宣言のみのデッドパラメータ、
  building_sensor.py:254 `_latest_sim_stamp` は書き捨て (読み手ゼロ・__init__ 未初期化)。
- CLAUDE.md「sensor は parallel」に対し実装は ToolCategory 既定 cascade (tool 1 本のため
  挙動差なし) — docs-drift テーマ側の観点。
- 契約乖離の新詳細: building_sensor.py:596 の contract outputs `rplidar` 宣言は実キー
  scan_front/scan_back と不一致 (既存 要相談④「contract() 宣言乖離」に追記。宣言側の
  未整備は系統的なため個別 PR 化しない)。

## 持ち越し「要相談」の状態変化 (12 件 + M16/M17)

- **解消 0 / 残存 12 + M16/M17**。個別確認:
  - #2 探索パス乖離: rover_main.py の候補は :1557 へ移動 (name 4 + rel 2 の 6 候補)、
    bcps_interface.py:172-174 は依然 2 候補 — 乖離継続 (entrypoint symlink で実害なしも同じ)。
  - #4 backin_wall_stop 非対称: 構図残存だが phase_actions.py:252-257 に
    「壁未停止のままノード超過 → 打ち切り」安全弁が追加され影響さらに縮小。
  - #5 rear_swing コメント: building_nav.yaml:55 に「≪ 0.25」が残存 (値 0.1 のまま)。
    周辺は角速度連動緩和 (7d30991d) で書き足されたが当該行は未修正。
  - obstacle_avoid maxw 生産者ゼロ: 残存 (消費行 353 へ移動、フォールバック 1.5 固定)。
  - detour_requested 逆流読み: building_reference.py:250 に残存。
  - drone_main.py:533 誤 module パス (takeoff_reference.LandingReference): 残存を実測再確認。
  - drone2 `.hlc_rc.yaml.swp`: git 管理下に残存 (git ls-files 確認)。
  - M16: 残存。`config/paths/` に yc_bld7_1f4f/_v2/3f4f の 3 json + README は git 管理下入り
    したが、欠落 2 本 (bld10_4f.json / yc_bld7_3f.json) は依然未コミット。新情報:
    spline_path_reference.py:18 の**デフォルト値も欠落側** yc_bld7_3f.json を指す。
  - M17 (cableL): 当該ファイル差分なし・未参照のまま。記録のみ継続。
  - #1/#3/#6/#7: 関連ファイルに基準線以降の変更なし — 残存。

## 捨てた候補と理由

- M20 (yaw blend 不到達) の PR 化: 修正が推定挙動の新規発火 + コード再配置で、SIM 検証不能 → 要相談。
- contract 宣言乖離 (building_sensor rplidar 等) の PR 化: 宣言未整備が系統的で、部分修正は
  既存 要相談④ の設計判断を先取りする → 追記のみ。
- rover.yaml:54 floor_map デフォルトの差し替え: exp1 vs slice の選択は設計判断 → 軽微記録。
- escape_side_clear 等デッドパラメータ削除: config スキーマ変更で外部 yaml (calib 等) への
  影響を静的に否定しきれない → 見送り。
- drone2 側: 新規 PR 可能な欠陥なし (今回差分は env パス修正系で参照は全解決)。

## メモ (次回向け)

- 次回 ros2-structure の基準線: **rf_rover 97bcd9ad / drone2 07e7dc6** (2026-08-31 origin/main)。
- PR #431/#432/#433 の merge 状況を次回確認。
- 権限実測 (追加分): `python3 -m py_compile <files>` は**許可**、`python3 -c "..."` は
  **deny** (原文: "Permission to use Bash has been denied because Claude Code is running
  in don't ask mode")。yaml のパース検証はコマンドでは不能 — grep + Read 目視で代替。
  gh label 系は従来どおり使用不可のため PR 本文に監査注記を明記する運用を継続。

> 夜間自動監査 (nightly-audit) が生成。
