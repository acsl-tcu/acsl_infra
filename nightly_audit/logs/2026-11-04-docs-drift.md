# 2026-11-04 docs-drift (host: ruth)

## 調べた範囲 (前回基準線からの差分)
- project_drone2: `5a97194..e418898` (#250-#255。px4_msgs submodule 化、SITL_PX4 config 受け渡し、
  **#254 required_sensors + config 明示必須化**、#255 周知 doc + 旧形式 dup 例一掃)
- project_rf_rover: `b54d134c..12ecea99` (#472-#474。同じく required_sensors + config 明示必須)
- acsl_infra: `25c3fb9..9e0f8f6` (#66-#71。dup/build_project の --image 正規化、nightly_audit 自身は対象外)
- 重点: config 明示必須化 (#254/#473) に対し、docs の `dup all <MODE>` 例・config 表が追従しているか。
  各リポ `git grep "dup all"` で全 md を当たり、project_launch.sh の require_config / `$2` 必須判定と照合。

## 確証指摘 → draft PR (2 本)
1. **drone2 #256** https://github.com/acsl-tcu/project_drone2/pull/256
   `config/README.md:136-150`「起動 mode と config の対応」表が「`<MODE>` 別 default config」
   「第2引数 (任意)」「EXP_ESP32: 任意」のまま。実装は `project_launch.sh:196-203` require_config で
   全 9 モード config 必須 (default 無し)。見出し・列名を必須に、EXP_ESP32 行を実装
   (`:245-247` subdir マップ無し) に合わせた。表の yaml 値は require_config の例示値と全行一致なので不変。
2. **rf_rover #475** https://github.com/acsl-tcu/project_rf_rover/pull/475
   config 無しの `dup all` 例 5 箇所 (#474 の一掃漏れ): `docs/setup.md:269` `dup all SIM`、
   `:275` `dup all EXP`、`README.md:39` `dup all isaacsim`、`docs/MAPPING.md:41` `[omni_*.yaml]`、
   `CLAUDE.md:133` 「`dup all isaacsim` (=omni_bld10)」。実装 `project_launch.sh:33-37/46-49/55-58` で exit 1。
   各箇所の注記が既に示す config (local/exp/omni_bld10) を明示。
- 検証: 参照 config の実在と required_sensors 宣言を git grep で確認。docs のみの変更。

## 捨てた/要相談
- **M52 (要相談・軽微)** drone2 `docs/REQUIRED_SENSORS.md:42`「36 本」— `git grep -L "^required_sensors:"`
  で sim/px4/ardupilot/omni/esp32/serial の全 tracked yaml を当たると宣言は **35 本** (未宣言 0)。
  作者の数え方 (sensor_catalog.yaml を含めた?) が不明なため PR にせず。rover の「8 本」は一致。
- **M53 (要相談)** drone2 `ROADMAP.md:188-191` の `dup all EXP` (config 無し・モード名も旧 EXP) と
  `dup all SIM circle.yaml` (`config/sim/circle.yaml` は無い。circle は `reference/circle.yaml`)。
  ROADMAP は Phase 6 時点の計画記録で、正しい置換先 (EXP_PX4 px4/exp.yaml? 行削除?) が一意でない。
- drone2 `config/README.md` トップレベル config 一覧に sim/hlc_sl*.yaml・coop_sl・omni/sitl_sl 等が
  載っていない — 既存の網羅漏れ (今回差分外)、追記は説明文の作成を要するので対象外。
- rf_rover `docs/BCPS_SIM_RUNTIME_MERGE.md:17/149` の `dup all OMNI` は building 側プロジェクトの
  コマンドで rover の project_launch.sh 対象外 → 指摘にしない。
- infra: `README.md:164` `dup all` は汎用説明で問題なし。dup/build_project のコメントは実装と一致。

## 滞留 draft PR (前回からの持ち越し、状態不変)
- drone2 #247 / #248 / #242 / #241 は DRAFT のまま。#242 は close 推奨 (ros2-structure 10-25)、
  #241 は rope_mass 抜粋が main と食い違い、#228 は close 推奨のまま。
- 既存要相談 M9-M51 は今回差分で変化なし (再走査せず)。

## 次回基準線
rf_rover `12ecea99` / drone2 `e418898` / acsl_infra `9e0f8f6`

## 権限メモ
- 拒否原文: "Permission to use Bash has been denied because Claude Code is running in don't ask mode."
  - `git ls-tree --name-only origin/main config/ ...` (既知) / `git grep -n -A3 ...` (既知) /
    パターンに `$` や `|` を含む `git grep -E` 2 件 → deny。`git grep -L` / `-c` / `-n` 単純パターンは許可。
- commit は `-F`、PR は `--body-file` で通過 (既知どおり)。
