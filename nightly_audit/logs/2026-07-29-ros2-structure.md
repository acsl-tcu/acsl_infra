# 2026-07-29 ros2-structure (ホスト: ruth)

## テーマ / 方針
ROS2 / パイプライン構造の健全性 (柱1: module 解決 / 柱2: yaml 参照解決 / 柱3: 契約整合)。
前回 07-18 フル走査 + 07-28 の drone2 PR #149 merge 確認を踏まえ、**07-18 以降の差分中心**で走査
(柱1/2 は安全のため両リポともフル再走査)。走査は Explore fan-out ×3 (組込み Grep/Glob/Read のみ、
python heredoc 不使用)。

## 調べた範囲 (網羅記録)
- **rf_rover** (07-18 以降 100+ コミット): 柱1 = `module:` 12件 → **全解決** (class + `def step(` 確認済)。
  柱2 = include 3 + 短名 (reference/localizer/planner.type/building.backend) 14 → **全解決**。
  柱3 = 差分ファイル 13 tool + 新規 bcps_ros2_bridge パッケージを精査 (下記)。
- **drone2** (07-18 以降 3 PR のみ: 監査自身の契約修正 #149 / docs #150 / dockerfile.mocap #151):
  柱1 = `module:` 31種 (104 有効サイト) → **全解決**。柱2 = 129件 (include 56 / extends 6 /
  reference パス形式 75 / config_file 9 / 短名 backend・estimator.type・vehicle 等) → **全解決**。
  #149 で変更の 7 tool ファイルも class/step/デコレータ健全。
- 既知の落とし穴 `results[-1]` 前提: 両リポ 0 件 (API は dict-keyed、`ctx.results.get(...)`)。
- 新規 `tools/debug/yaw_probe.py`: どこからも未登録のスタンドアロン rclpy ノード (docstring も直接実行
  のみ案内)。壊れた参照ではない → 指摘なし。

## 開いた PR (draft、いずれも rf_rover)
1. **#224** https://github.com/acsl-tcu/project_rf_rover/pull/224
   `fix: package.xml の依存宣言を実 import に合わせる`
   - `bcps_interface.py:31-38` が `bcps_bridge_msgs`、`building_interface.py:2` が `rf_interfaces` を
     import するが `packages/rf_rover/package.xml` 未宣言。`rover.yaml:130` で bcps が既定バックエンド、
     欠けると `rover_main.py:387-398` の try が握って **建屋 IF が警告のみでサイレント無効化**。
   - `bcps_bridge/package.xml` にも launch が直接 import する `launch`/`launch_ros`/`ament_index_python` を追加。
   - 検証: 純タグ追加を diff 確認 (xmllint は deny → 目視)。colcon build は監査ホスト非対応のため
     merge 前に `build_project` 推奨と PR に明記。
2. **#225** https://github.com/acsl-tcu/project_rf_rover/pull/225
   `docs: 実装と食い違う陳腐化コメント2件を修正`
   - `config/omni_yc_bld7.yaml:50`「gen_yc_bld7.py 未実装・フル起動不可」→ 実在・実用中。
   - `bcps_interface.py:188`「guid フィールドに」→ `DoorControl.msg` は `door_name`/`command` のみ
     (msg コメントで GUID 不可と明記)。コードは正しく、コメントのみ誤り。
   - 検証: py_compile 通過、yaml はコメント部のみ変更。

※ ラベル `nightly-audit` は rf_rover リポに存在せず `gh label create` も deny のためラベル無し。

## 要相談 (確証あるが PR 不可 / 設計判断要)
1. **drone2 `drone_main.py:533` — 誤 module パス (確証・管理者ファイル)**
   フォールバック reference 登録が `drone2.tools.reference.takeoff_reference.LandingReference`。
   `LandingReference` は `landing_reference.py:32` にのみ存在 (takeoff_reference.py には無い — grep で確認)。
   `include.reference` も `phases.*.reference` も無い config で起動すると `_import_class` (:537) が
   AttributeError で**起動失敗**する潜在バグ。修正は1行: `takeoff_reference.` → `landing_reference.`。
2. **rf_rover `obstacle_avoid.py:242` — 生産者ゼロの metadata 読み (確証・設計判断要)**
   `prev.metadata.get("maxw", 1.5)` の `"maxw"` は全パッケージで誰も Result metadata に書かない
   (grep 網羅済)。rover_main は `self.saturation.maxw` の**属性**を毎ループ上書きする方式 (:627,630) で、
   ObstacleAvoid は常にリテラル 1.5 で clamp。building_nav.yaml:75 の「rover_main が上書きする」注記
   および直近の maxw 2.0→1.0 調整 (PR #210 系) と食い違う。どの値に追従させるかは制御設計判断のため PR 化せず。
3. **rf_rover `building_reference.py:219-220` — reference 段が下流 controller の metadata を読む**
   `get_upstream("controller")` で `detour_requested` (生産者 anti_stack.py:57) を参照。パイプライン順は
   reference → controller なので同サイクルでは前周期値/None のはず。挙動は `common/` (ローカル非存在) の
   StepContext 実装依存で静的確証不能 → 実行時検証 (backend-smoke SIM) or 管理者確認へ。
4. **rf_rover 契約宣言と実結合面の乖離 (宣言不足系・低優先)**
   `amcl_estimator.py:77-81` は入力 `pose` のみ宣言だが実際は sensor metadata 4キー
   (`tf_valid`/`amcl_pose`/`nav_odom`) に結合、producer (`building_sensor.py:541-548`) 側宣言も過少。
   ほか lane_keep/obstacle_avoid/person_avoid/building_actuator も宣言外 upstream を読む (キー自体は全て
   生産されており今夜時点で実害なし)。drone2 PR #149 と同型の「optional 宣言追加」で直せるが、rf_rover は
   `def contract()` 方式 (デコレータではない) かつ common/ 不在で IntegrityChecker 検証不可 → 要相談。
5. **drone2 `config/controller/.hlc_rc.yaml.swp` — コミット済み vim swap バイナリ (手動1コマンド)**
   git 管理下 (git ls-files で確認、20KB、07-09 付)。ローダは `*.yaml` glob で実害なしだがリポ衛生違反。
   `git rm` / `rm` とも deny (原文: "Permission to use Bash has been denied because Claude Code is
   running in don't ask mode.") のため自動除去不能。手動で
   `git rm config/controller/.hlc_rc.yaml.swp` を推奨。

## 捨てた候補と理由
- 宣言外 upstream 読み単体 (上記4の個別ファイル分) — 全キーに生産者があり実害なし (RUNTIME-DEPENDENT)。
- `estimator/ekf_sl.yaml:11,13` のコメントアウト module 2件 — dead config、クラスは実在、無害。
- `amcl_estimator` の `seek_active`/`seek_dist` 未 emit — `seek_enabled: false` 既定 + 消費側 .get 既定値で良性。
- yaw_probe 未登録 — デバッグ用スタンドアロン設計として自己整合 (docstring とも一致)。
- bcps_bridge の params.sim.yaml に doorsfile 無し — declare_parameter に既定値ありで整合。

## 権限実測 (今夜の新データ)
許可: `git checkout -b` / `git add` / `git commit -m` / `git push -u` / `git branch -d` /
`gh pr create --draft --body-file` / `python3 -m py_compile` / `grep` / `find` / `ls`。
deny (原文は上記引用と同一): `xmllint` / `gh label create` / `gh pr create` (長大 inline `--body`。
`--body-file` 方式なら許可) / `git rm` / `rm`。

## 前回持ち越しの状態
- drone2 契約 inputs 7件 → PR #149 merge 済 (解消確認済)。
- 要相談 2件 (RC 末尾 sensor / sl_landing 契約継承) → 引き続き管理者判断待ち (今夜も変化なし)。
