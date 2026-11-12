# 夜間監査レポート 2026-08-20 — ros2-structure

- ホスト: ruth / 実行: 無人 (cron)
- 対象: project_rf_rover, project_drone2 (targets.conf kind=repo との積集合)
- 方式: 前回 (2026-08-09) 基準線からの**差分走査** + 全 config の module/パス参照は全数再チェック
  (走査は Explore fan-out、git 裏取りはメインループ。実機・コンテナ操作なし)
- 基準線: rf_rover = 7534f1f7 の親 (以降 ~20 コミット / PR #320〜#332)、
  drone2 = 085cfd0 (以降 PR #209〜#216 ほか sl_coop 系大量追加)

## 結論: **確証指摘 0 件・PR 0 本 (成功)**。柱1/柱2 は両リポとも全解決。新規「要相談」2 件。

前回監査の PR **rf_rover #324** (gen_ref の door_wait 解除漏れ) は **2026-08-12 に merge 済み**。

## 網羅範囲 (指摘ゼロの根拠)

### 柱1: module: 登録の解決性 — 全解決
- rf_rover: **12/12** (10 クラス、Saturation/TSCFController は二重登録)。全て 実ファイル + class + `def step(` に解決。
- drone2: **107/107 有効登録** (109 行中 2 行はコメントアウト: estimator/ekf_sl.yaml:11,13)、29 クラス全解決。
  sl_coop 新規追加分 (SLCoopReference / SLTakeoffReference / SLSettleReference / SLLandingReference /
  SplinePathReference / HLCSuspendedLoadController / SuspendedLoadStateAdjust 等) 含む。

### 柱2: yaml/json パス参照の解決性
- rf_rover: パス形式参照 **4/4 実在** (rover.yaml:246,247 / line.yaml:29 / sitl_line.yaml:26)。
  変更 3 config (omni_bld10 / omni_yc_bld7 / robot/megarover2) にはパス形式参照なし (コメントとシム調整のみ)。
- drone2: 引用 .yaml/.json 値 **197 件 (64 ターゲット) 中、欠落 2 件** — ただし下記のとおり
  現行起動経路からは到達不能のため PR 化せず要相談へ:
  - `config/reference/bld10_spline_4f.yaml:4` → `/root/ros2_ws/config/paths/bld10_4f.json` **不在**
  - `config/reference/yc_bld7_spline_3f.yaml:4` → `/root/ros2_ws/config/paths/yc_bld7_3f.json` **不在**
  - 実行時生成の `_sl_layout.gen.json` (omni/sitl_sl.yaml:63) 等は欠落扱いにしない。

### 柱3: 変更 tool ファイルの静的整合 — 破綻なし
- rf_rover `tools/phase/phase_definition.py`: 9 フェーズ名と遷移端点の整合、
  `build_building_phases` の 16 kwargs が呼び出し側 rover_main.py:367-384 と完全一致、
  コールバック先 (プロパティ/チェッカ) 全実在。clean。
- rf_rover `tools/reference/building_reference.py`: step/contract あり、gen_sequence import 解決、
  phase_actions からの `_x`/`_orient_yaw`/`_node_xy`/`gid` アクセス全解決、`self.Bld` は全て .get() 経由。clean。
- drone2 変更 8 ファイル (hlc_sl_controller / sl_state_adjust / reference 6 本): repo 内 import 全解決
  (takeoff_reference の `_poly9` 等・sl_ref_adjust の `_smoothstep6` 等・sl_coop_trajectory→sl_trajectory)、
  `def step(` 全員あり、読む config キーと供給側 yaml のキーが相互一致、短名 (`sl_state_adjust`/
  `hlc_sl_controller`/enum 系) も全て `name =` 属性・分岐実装に一致。clean。
- spline_path_reference には専用テスト (test/test_spline_path_reference.py) も追加されている。

## 新規「要相談」 (今回 2 件 + 軽微 1 件)

- **M16: drone2 フライスルー経路 json 2 本が未コミット** (上記柱2の欠落 2 件)。
  `config/paths/README.md` は「経路 json は config/paths/ を正本として **git 管理する**」と定めるが、
  `bld10_4f.json` / `yc_bld7_3f.json` は **git 履歴に一度も存在しない** (`git log --all` で 0 件 —
  作者ローカルにのみ存在した資産)。参照元はともにコメントアウト行のみ
  (omni/sitl_bld10.yaml:113 / omni/sitl_yc_bld7.yaml:300) のため現行運用では踏まないが、
  コメント解除すると spline_path_reference.py:62,73 で即 FileNotFoundError。
  対処は (a) 作者が json をコミット / (b) 陳腐化した yaml を削除 / (c) 参照先変更 — いずれも
  人手判断 (経路データは path_editor 人手作成資産で監査は生成不能、ファイル削除系コマンドは deny)。
- **M17 (軽微):** drone2 `config/reference/sl_settle_coop.yaml:6` の `cableL: 1.5` が coop 系他 config の
  3.0 (vehicle/PF2_sl_coop.yaml:17 等) と不一致。ただし当該ファイルはどこからも参照されていない
  (coop_sl.yaml:69 は settle を sl_coop_flight.yaml に向けている)。物理パラメータの判断につき記録のみ。

## 持ち越し「要相談」の状態変化 (2026-08-09 の 12 件)

- **解消 0 / 残存 12**。個別に確認した変化:
  - #2 (doors_bcps.json 探索パス乖離): rover_main.py:1186 に `/ENV/<name>/repo/config` 候補が**追加され 6 候補に** (bcps_interface 側は変更なし) — 乖離は継続、候補リストはさらに非対称化。
  - 旧 drone_main:533 誤 module パス: **残存を実測再確認** (`takeoff_reference.LandingReference` 参照だが
    実体は landing_reference.py:33。fallback 経路でのみ AttributeError)。
  - 旧 drone2 `.hlc_rc.yaml.swp`: **git 管理下に残存** (`git ls-files` で確認。削除系 deny のため手動 `git rm` 待ち)。
  - #5 rear_swing_radius: megarover2.yaml は変更されたが該当箇所は未変更 (今回差分は lidar_back_z 0.35→0.15 のみ) — 残存。
  - その他 (#1,#3,#4,#6,#7 / obstacle_avoid maxw / building_reference detour / contract 乖離): 関連ファイルに
    基準線以降の変更なし (building_reference の変更は set_gid ガードと door_wait 解除のみで detour 部に非接触) — 残存。

## 捨てた候補と理由

- 柱2 欠落 2 件の PR 化: 機械的修正が存在しない (json は生成不能・yaml 削除は deny + 設計判断) → M16 要相談へ。
- sl_settle_coop.yaml の cableL 不一致: 未参照ファイル + 物理パラメータ判断 → M17 軽微記録。
- config/paths/yc_bld7_1f4f.json・_v2.json が yaml から未参照: README の規約どおり path_editor の
  保存/復元資産 (docs/PATH_EDITOR_GUIDE.md:41,46 で言及) であり欠陥ではない → 非指摘。
- megarover2.yaml `sim.usd: "/ENV/..."`: config 経由の環境参照は規約どおり (ハードコード禁止はコード側) → 非指摘。

## メモ (次回向け)

- 次回 ros2-structure の基準線: **rf_rover 175f143c / drone2 82d1278** (2026-08-20 origin/main)。
- rf_rover ローカルはユーザー WIP ブランチ `feature/env-phase2` (クリーン)。今回チェックアウト変更なし。
- 権限: `grep -rn <word> <abs-path>` は許可。cwd は通知またぎでリセットされることがある (cd し直すこと)。

> 夜間自動監査 (nightly-audit) が生成。
