# Nightly Audit 2026-08-08 — docs-drift

- ホスト: ruth / テーマ: docs-drift (ドキュメント/コメントと実装の乖離)
- スコープ: acsl_infra, project_rf_rover, project_drone2 (targets.conf repo 行 × テーマ対象)
- 手法: Explore 2並列 (rf_rover=very thorough / acsl_infra=medium)。drone2 は 07-22 以降
  コミットゼロ (前回 07-28 走査済み) のため新規走査なし。全 PR 候補は駆動側が
  Read/grep で file:line 単位に再検証してから PR 化。

## 前回 (07-28) からの差分と PR 状態

- rf_rover: **PR #223 マージ済み** (07-30)。07-29〜08-05 に約 100 コミット
  (障害物回避・バック駐車・door/elevator・robot spec 集約・render 系) → 今夜の主戦場。
- acsl_infra: PR #56 は **open のまま** (draft)。新規は 1a3b7a8 (FASTDDS 既定を上限なし
  UDPv4 に、07-29) のみ。
- drone2: PR #153 は **open のまま** (draft)。新規コミットなし → 要相談 N4〜N6 は状態不変。

## 確証指摘と draft PR (今夜 3 本、すべて rf_rover)

### PR 1: https://github.com/acsl-tcu/project_rf_rover/pull/321
`audit/docs-drift-obstacle-avoid-robot-spec` — docs/OBSTACLE_AVOIDANCE.md のみ。
08-01 (d837ebe2) 全面改訂の直後 08-03 の **robot spec 集約 dce6c93c** に未追従:
1. 幾何キー 8 種の上書き元 (building_nav.yaml → robot 諸元注入。`building_nav.yaml:30-35`,
   `rover_main.py:223-248`, 重ね順 controller < robot < calib)
2. `back_range_min` 0.15 の出所 (`config/robot/megarover2.yaml:43` min_range、個体差は
   `exp.yaml:38-46` calib)
3. 機尾ガード need 式の `min(rear_swing_radius, ...)` 上限欠落 (`obstacle_avoid.py:873-881`)
4. `rear_swing_tail_r` 実効 0.40 → 0.403 (`robot_spec.py:53` hypot(0.35,0.20)。導出値は
   手計算で全キー再確認済み)
5. orient 素通しの発生源 EV のみ → +ゴール姿勢回頭/backin 整列 (`phase_actions.py:26,40,51,66`)

### PR 2: https://github.com/acsl-tcu/project_rf_rover/pull/322
`audit/docs-drift-bcps-door-elevator-gates` — BCPS_NAV_INTEGRATION.md / EXPERIMENT_YC_BLD7.md /
PHASE_FLOW.md (降車条件行)。08-01 の door/elevator 改修 (#313/#314/#317) に未追従:
1. `open_door` の msg フィールド guid → `door_name` (`bcps_interface.py:258-272`, bridge README:238)
2. 降車完了条件に `exit_hall_reach` (0.8m, どちらか早い方) 追記 (`rover_main.py:499-526`,
   `rover.yaml:167-170`)
3. ドア接近判定「edge 中点」→「エッジ線分への最短距離」(`building_reference.py:614-631`)
4. 開扉確認ゲート confirm_open (door/states 確認までドア手前 node 待機、TSCF は door_wait で
   [0,0] 静止。`rover.yaml:151-156`, `rover_main.py:433-441`, `tscf_controller.py:86-98`) を
   二段ゲートとして追記 + config 例に confirm_open/state_stale_sec 追加

### PR 3: https://github.com/acsl-tcu/project_rf_rover/pull/323
`audit/docs-drift-phase-graph-and-config-tree` — 構成説明の追従 (7 ファイル):
1. phase 遷移図: 実装に無い `request_complete` を削除し、`goal_cleared` / `start_backin` /
   `backin_done` / `reach_goal` / `goal_oriented` 等を `phase_definition.py:43-171` の
   PhaseTransition と 1:1 で反映 (PHASE_FLOW.md, phase_definition.py docstring, CLAUDE.md:53)。
   phase_definition.py は docstring のみ変更、`py_compile` 通過を確認
2. controller cascade に LaneKeep 追記 (CLAUDE.md:45, DEVELOPMENT_GUIDE.md:34,63。
   `building_nav.yaml:121` enabled: true)
3. EXP/SIM モード注記 SLAM/dr → AMCL/odo・AMCL 継承/cmd (`exp.yaml:6-7`, `local.yaml`,
   `rover.yaml:12`)。include は controller+robot の 2 つ (`rover.yaml:245-247`)
4. README config ツリー: robot/ 追加・不在の apriltag_map.json (実体は environments 側、
   `rover_main.py:148`) 訂正・実在一覧 (ls 突合) へ更新
5. 機体 USD 指定元 isaac_sim.rover_usd → robot 諸元 sim.usd (ISAAC_ASSET_SETUP.md,
   isaac_sim/README.md:80。`set_env.py:151-157`)

いずれも draft・実装/設定側は無変更 (phase_definition.py は docstring のみ)。
`nightly-audit` ラベルは今夜も付与不能 (下記)。

## 権限メモ (deny 原文つき)

- `gh pr edit 321 --add-label nightly-audit` → deny。原文: "Permission to use Bash has been
  denied because Claude Code is running in don't ask mode"。07-28 の `gh label create` deny と
  合わせ、**ラベル系操作は全滅**。ラベル運用するなら手動作成+手動付与が必要。
- PR パイプライン (checkout -b / add / commit -F / push -u / gh pr create --draft --body-file)
  は今夜も全行程 headless で成功 (3 本)。

## 要相談 (修正先が一意でない / 実装側変更 / 仕様解釈が必要)

### 今夜の新規
| # | 場所 | 内容 | 理由 |
|---|------|------|------|
| M1 | acsl_infra `hardware_setup/README_WSL2.md` | 1a3b7a8 で compose コメント (`docker-compose.yml:65-67`) が「WSL2 で robot を動かす場合は `FASTDDS_BUILTIN_TRANSPORTS='UDPv4?max_msg_size=1400B&sockets_size=4MB'` を明示」と定めたが、WSL2 セットアップ doc に DDS 節が無い | 欠落補完 (追記位置・文言の判断要)。なお既存 doc に旧既定 (max_msg_size=1400) を既定と記す残骸は無し (md 全 grep 0 件) |
| M2 | acsl_infra `commands/setup.sh:15` | `docker/common/rules/$PROJECT.rules` を setup_udev に渡すが `docker/common/` に rules/ は無い。実体はリポ直下 `rules/` (default*.rules, full.rules) | コード側修正。`rules/$PROJECT.rules` が意図か要確認 (該当名のファイルも無い) |
| M3 | acsl_infra `for_new_project.md:41-45` | `docker compose --env-file <envfile>` 起動手順だが docker/ に env.* は無く実体は dup | README_DOCKER.md の env.** 持ち越しと同根。一括で書き直すべき |
| M4 | rf_rover `docs/EXPERIMENT_YC_BLD7.md:17-24` | environments/ への手動 git clone 手順は旧内包 clone を再現する。現 `setup:14-44` は env_sync + `~/ENV/<name>/repo` への symlink 化を行い、旧 clone には警告を出す | 手順の書き直し。旧 acsl_infra 環境のフォールバックとして残すかは運用判断 |
| M5 | rf_rover `packages/rf_rover/README.md:16-256` | behavior/interface/controller/estimator ディレクトリ構成の旧世代アーキテクチャ記述 (実体は tools/ ほか 4 dir のみ) | 全面書き直しか削除。機械的追従の範囲外 |
| M6 | rf_rover `CLAUDE.md:23` | 編集禁止リストの `stop` スクリプトがリポに無い (setup/console/project_launch.sh はある) | 削除してよいか owner 確認要 |
| M7 | rf_rover `AGENTS.md:44` | EXP = "MegaRover3" と記すが robot 諸元は megarover2 (`config/robot/megarover2.yaml`)。一方 `setup:58` は megarover3_bringup をビルド | リポ内でも矛盾しており正が確定不能 |
| M8 | rf_rover `building_nav.yaml:44-45` / `obstacle_avoid.py:906-908` | 「掃引 6〜12cm ≪ 0.25」の安全根拠コメントが旧 rear_swing_radius 0.25 前提。現値 0.1 (`building_nav.yaml:47`) では 12cm ≪ 0.1 が成り立たない | 単純追従すると安全根拠の主張が偽になる。閾値/根拠の再確認要 (設計判断) |
| - | acsl_infra `README.md:53` | フォルダツリー内に迷い込みの 1 文字「ダ」 | 軽微 typo。単独 PR はノイズのため次回 acsl_infra PR に同乗させる |

### 継続 (今夜、現状を実測確認)
- rf_rover N1 (orient 保持記述): **残存**。4 doc 箇所に加え `tscf_controller.py:63` コメントも
  同旨の陳腐化。実装は「回頭後 orient 解除 + gid=nan 静止」(`phase_actions.py:240-249,277-285`)。
  修正文言は 07-28 レポート提案どおりで可だが挙動仕様節の書き直しになるため引き続き要相談。
- rf_rover N2 (omni_bld10 `building.backend: action` 明示指定の記述): **残存**
  (実ファイルに building: 無し、`omni_bld10.yaml:17` コメントのみ)。:136-139 の段落削除を含む。
- rf_rover N3 (`arrive_settle_sec` が rover.yaml に無い): **残存** (config/ 全 grep 0 件。
  コード既定 6.0 のみ `bcps_interface.py:70`)。config 追加 = 実装側変更のため要相談維持。
- acsl_infra 07-17 系 4 件 (README.md:317 packages/acs / packages/README_ROS.md 旧一覧 /
  docker/README_DOCKER.md env.** 構成 / commands/setup.sh:20 の存在しない
  project_launch.sh cp): **全て残存** (今夜 Read で確認。README_ROS は表リンク 7 本中 6 本が
  リンク切れ、.gitignore により setup.sh:20 の else 分岐は恒久的に失敗)。
- drone2 N4〜N6: リポにコミットが無いため状態不変 (再検証省略)。#153 マージ待ち。

## 捨てた候補 (棄却理由つき)

- acsl_infra `docker-compose.yml:67,70` の discovery_env.sh 言及 — 実体は
  project_rf_rover/discovery_env.sh に実在し (Read 確認)、記述 (監視 PC 側受信設定の生成) も
  実装と一致。リポ横断の所在注記は改善提案であり乖離ではない。
- acsl_infra: 1a3b7a8 (FASTDDS 既定変更) 起因の docs 乖離 — なし (*.md に DDS 関連記述ゼロ、
  compose コメント自体が新既定を正しく説明)。
- rf_rover `OBSTACLE_AVOIDANCE.md:39-40` 「機尾角の回転半径は約 0.40m」 — 導出 0.4031 の
  近似として妥当 (表の実効値のみ 0.403 に更新)。
- rf_rover elevator/door 系の他キー (confirm_open/state_stale_sec/exit_hall_reach の
  rover.yaml 記載、poll_sec 等) — config とコードは一致 (乖離は docs のみ → PR 2 で解消)。

## 次回への引き継ぎ

- ローカル audit ブランチ 3 本 (push 済み) が rf_rover クローンに残存。checkout は main に
  復帰済み。merge 後に `git branch -d` (branch-cleanup テーマ)。
- レビュー待ち draft: rf_rover #321/#322/#323 (今夜)、acsl_infra #56、drone2 #153 (07-28)。
- ラベル運用は管理者の手動作成+付与が必要 (`gh label create` も `gh pr edit --add-label` も deny)。
- rf_rover は活発 (100 コミット/10日)。次回 docs-drift は 08-08 以降の差分走査 + 上記
  M1〜M8/N1〜N3 の状態確認から。
