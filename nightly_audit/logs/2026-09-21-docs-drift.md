# 2026-09-21 docs-drift (ホスト: ruth)

## テーマ / スコープ

ドキュメント・コメントと実装の乖離。targets.conf の `kind=repo` 3 本が対象:

| repo | 基準線 (前回) | 今回の origin/main | 差分 |
|---|---|---|---|
| project_rf_rover | `ae36f052` | **`b024a537`** | 30 commits / 35 files (PR #440 + Newton 系) |
| project_drone2 | `3a53ebb` | `3a53ebb` | **0 commits** |
| acsl_infra | `689683d` | **`25c3fb9`** | 2 commits (gpull 並列化のみ) |

前回方針どおり「既提出 PR のマージ確認 + 基準線以降の差分走査」に絞った。
rf_rover に実質すべての新規面があったため、走査はそこへ集中した。

## 既提出 PR のマージ確認

| PR | 状態 |
|---|---|
| rf_rover #383 (occupancy paths) | **CLOSED** — `#438 chore/audit-followups` で取り込み済 |
| rf_rover #384 (megarover2 ns) | **CLOSED** — 同上 |
| rf_rover #435 (Newton LiDAR status) | **MERGED** (09-20) |
| drone2 #225 (robot ns) | OPEN (draft, `MERGEABLE`) — 08-29 提出、**23 日経過** |
| drone2 #228 (coop rope defaults) | OPEN (draft, `MERGEABLE`) — 09-09 提出 |

→ rover 側は 3 本とも決着。**drone2 の 2 本は依然 OPEN**。どちらも競合なし。

## 今夜開いた draft PR (3 本)

| PR | 内容 | 確信度 |
|---|---|---|
| [#441](https://github.com/acsl-tcu/project_rf_rover/pull/441) | `ISAAC_IFC_METADATA_TOOLS.md` の `apply_metadata_csv.py` 参照パスを環境リポ vendor 先へ追従 (3 箇所) | 高 |
| [#442](https://github.com/acsl-tcu/project_rf_rover/pull/442) | `CLAUDE.md` の 3 点 (include 列挙の自己矛盾 / 削除済み `stop` / console `p` 欠落) | 高 |
| [#443](https://github.com/acsl-tcu/project_rf_rover/pull/443) | `AGENTS.md` Modes の実在しない `SITL`/`local_sim` を `EXP`/`SIM`/`isaacsim` へ | 高 |

いずれもドキュメントのみの変更。実装・config には一切触れていない。

### #441 の根拠
`apply_metadata_csv.py` は `ad5c9021` で環境リポへ移管済み。rover リポに無く
(`ls` で確認)、`environment_yc_bld7/omni/scripts/` と `environment_bld10/omni/scripts/`
に実在。doc の `exec(open(...).read())` 2 箇所はそのまま貼ると FileNotFoundError。
移管先スクリプトに `set_root`/`list_matches`/`make_glass`/`make_movable` が全て残ることを
確認済み = **パスだけが陳腐化**しており本文の説明は現状と一致する。
表記は既存 house style (`isaac_sim/README.md:88,109,122`) に合わせた。

### #442 の根拠
1. `CLAUDE.md:122` が「include するのは controller と robot 諸元のみ」と書くが
   `config/rover.yaml:27-32` は 4 つ include する。**同じファイルの :119-120 が
   building/elevator の include を正しく書いており自己矛盾**。
2. `:23` の `stop` は `dea7b31e` で削除済み。リポジトリ直下にもデプロイ先 `~/rover` にも無い。
   (`:92-93` の `stop` は console サブコマンドで実在 → 変更せず)
3. `:92` の console 一覧に `c4c160ca` で入った `p` が無い (`console:61-62`, `:161-163`)。

### #443 の根拠
`project_launch.sh:51` の Usage は `{EXP|SIM|isaacsim}` のみ。`SITL`/`local_sim` は
分岐が存在せず必ず Usage 終了になる。既定 config も各モード固有 (`:14/:41/:48`)。

## 棄却した候補 (敵対的検証で落としたもの)

- **`EXPERIMENT_YC_BLD7.md:106` の `door_names: ['RBTSTN']` が誤り** — **誤検知**。
  fan-out は「RBTSTN は config/ packages/ に 0 件」と報告したが、**実際は多数ヒット**する。
  決定的証拠として環境リポの `environment_yc_bld7/config/doors_bcps.json` に
  `{"doorName":"RBTSTN","floor":2,"guid":"1VOwJtS_nFAwSwngp2jsDD"}` が実在し、
  **RBTSTN は正規の BCPS ドア名**。doc は正しい。→ 修正せず。
- **`ROBOT_SPEC.md:40` の `wheel_sphere_colliders.py` が `scene/` 配下に見える** —
  実体は `isaac_sim/scripts/wheel_sphere_colliders.py` だが、doc の表記は
  **パス接頭辞なしの素のファイル名**であり「存在しない参照」ではない。誤読しやすいだけ。
  テーマの指摘条件 (参照先が実在しない) を満たさない → 見送り。
- **`PEOPLE_SIM_ROADMAP.md:9` の `spawn_people.py`** — パス自体は確かに陳腐化 (同じく
  `ad5c9021` で環境リポへ移管、`isaac_sim/README.md:88` が移管先を明記) だが、
  **パスだけ直すと doc が悪化する**。:11「どちらも bld10 前提で yc_bld7 では動かない」と
  :18-23 の「建屋ハードコード箇所」(`_env_config_candidates()` が bld10 固定 /
  `_PEOPLE_NODE_RANGE = (1,29)`) は移管時に解消済み (移管先では `_BUILDING` 変数化・
  `_PEOPLE_NODE_RANGE = None` で config 化)。doc の最終更新 `10794aec` は 2026-07-24 で
  移管 (08-14) より前 = 節ごと前提失効。→ **要相談 M32**。

## 要相談 (PR にしない)

### 新規

| ID | 内容 |
|---|---|
| **M30** | `rf_rover/CLAUDE.md:130`「旧 `environments/` シンボリックリンクは**廃止**」が実装と矛盾。`setup:21`(`mkdir -p .../environments`)・`setup:41-42`(`ln -sfn "${rel}/${name}/repo" "$dest"`)・`setup:118-119` が今も張っており、`sb/CLAUDE.md` も「当面残す (撤去はフェーズ3)」と書く。さらに `docs/` の 10 箇所が `environments/<建屋>/config/...` を正本として参照しており、これらは symlink 前提で**現状は正しい**。「廃止」の一文だけが誤り。ただし撤去計画の現況は管理者判断 → 一文削除でよいかの確認が要る |
| **M31** | `docs/EXPERIMENT_YC_BLD7.md:17-24` の手順0 が `cd ~/rover/environments && git clone ...` という**旧内包 clone 方式**。現行は `setup:35` の `env_sync <name>` が `~/ENV/<name>/repo` へ配備し symlink を張る方式で、手順どおりに実 clone すると `setup:36-39` の移行警告 (`[migration] ... rm -rf $dest && ./setup`) を踏む。`yc_bld7` は `setup:22-25` の `ENVIRONMENTS` に登録済なので `./setup` で足りる。手順文の書き換えが必要 = 機械的でない |
| **M32** | `docs/PEOPLE_SIM_ROADMAP.md` の「現状の棚卸し」節 (:9-23) が移管前 (2026-07-24 時点) のまま。移管先 `environment_*/omni/scripts/spawn_people.py` では建屋ハードコードが解消済み。節ごとの書き直し or 「移管前の記録」注記が要る |
| **M33** | `docs/BCPS_NAV_INTEGRATION.md:224,228,237,239` は契約ファイルの正本を `environments/<建屋>/config/` と書き、同 PR で入った `config/building/link.yaml:5-6` は `~/ENV/<建屋>/repo/config/` と書く。**どちらも同じ実体を指すので誤りではない**が表記が二重。統一するかは M30 の方針次第 |
| **M34** | `packages/rf_rover/README.md` が旧構造 (`behavior/`, `interface/`, `robot.py`, `robot_node.py`, `rover_interface.py`, `gen_sequence.py` 等) を丸ごと記述。列挙されたファイル・ディレクトリは**いずれも現存しない**し、`CLAUDE.md:36-47` の現行アーキテクチャとも一致しない。全面書き直しの要否は管理者判断 |
| **M35** | `docs/ROBOT_SPEC.md:26-28` の「robot yaml に書いてよいもの」一覧に `nav:` と `ev:` が無い。実際は `config/robot/megarover2.yaml:101-102` の `nav.robot_radius` を `launcher/launch_nav2.sh:71-76` が planner.yaml へ注入し、`iw_hub.yaml:73-75` 等の `ev:` を `rover_main.py:1567-1569,1611-1613` が読む (`config/building/elevator.yaml:71-72` も言及)。**追記**なので新規文章が要る |
| **M36** | `README.md:90-93` の console 例が `target 4 3 # 4階3番に移動` と書くが、`target` は目標設定のみで発進しない (`rover_main.py:1095` `auto_start=False`、`:1102` が `(standby; 'start' で発進)` を返す)。`start` 行と `p` 行も欠落。手順ブロックの書き換えが要る |
| **M37** | `setup:103` のコメント「起動は `./start_yolo.sh`」に対し 2 行下の `setup:105` は `起動: dup yolo` を案内。`README.md:40-42` / `CLAUDE.md:66` も `dup yolo` が標準・`start_yolo.sh` は代替と書く。**`setup` は「変更は管理者に相談」対象**のため触れない |
| **M38** | `packages/rf_rover/rf_rover/plot_log.py:16` の docstring の traces キー一覧に、実際に `config/plot/default.yaml:14-15` が使い実装 (`:128`, `:133`) も対応している `idx_x` / `idx_y` / `mark_ends` が無い |

### 残存 (前回から)

| ID | 状態 |
|---|---|
| **M24** (drone2 notebook 4 修正) | **未解消**。`FPVCam` は `setup_isaac_yc_bld7.ipynb` / `record_run.ipynb` に残存。drone2 main は基準線から 1 commit も動いておらず手動修正は未着手。NotebookEdit が許可されない限り監査側では直せない |
| **M22** (`NEWTON_MIGRATION.md` の未対応記述) | **未解消**。:84-85 が「EV/自動ドア runtime」「建屋込みの車輪機体走行 (箱床のみ検証)」を未対応とするが、:100-111 が yc_bld7 2F 走行 113% を実測、:105 が `KinematicMirror` でドア通過 3.33m を実測、:107 がキャスター滑り 56%→96% を解決。:140-141 の「残」も同様に失効。ただし :84 の `omni.physx` scene query の部分は生きている可能性があり**部分的失効** = 機械的に直せない |
| **M23** (`NEWTON_RUNBOOK.md` の `scratchpad/`) | **未解消**。:153,159 が `scratchpad/wheel_bld7_test.py` / `run_wheel_bld7.sh` を参照するが `scratchpad/` 自体が無い。リポ外の作業用か入れ忘れかが判別不能 |
| **M25** (scene ファイル列挙の欠落) | **未解消**。`isaac_sim/scripts/scene/readme.md:12-19` が `engine_articulation.py` / `newton_compat.py` / `rtx_lidar.py` / `front_lidar.py` 等を欠く。`debug/` 列挙 (:22-28) は `probe_robot_usd.py` のみ欠落。`CLAUDE.md:130` の列挙も同様。**列挙漏れ = 新規文章が要る** |
| **M26** (drone2 `coop_sl.yaml:215-224`) | **未解消**。「何が変わるか (アセット 6 節 → 生成 12 節)」の解説ブロックが、現行 `segments: 6` (`:245`) と前提が食い違う。drone2 main は不変 |
| M18 / M9 | 残存 |

## 乖離なしと確認した範囲

- **acsl_infra**: 基準線以降の唯一の変更 `6f42af1` (gpull 並列化) は README の追記
  (`ENV_PULL_JOBS` 既定 8) と実装 (`docker/common/scripts/gpull:110` の
  `${ENV_PULL_JOBS:-8}`) が一致。README の相対リンク 3 本 (`commands/README_SYSTEMD.md` /
  `packages/README_ROS.md` / `docker/README_DOCKER.md`) は全て実在。
- **project_drone2**: main が基準線から不変のため新規走査対象なし。
- **rf_rover 相対リンク**: 全 11 件が有効。**リンク切れ 0 件**。
- **PR #440 で入った新 config のキー名・既定値**: `BCPS_NAV_INTEGRATION.md:148-173` の
  抜粋が `config/building/link.yaml:13-43` と `config/building/elevator.yaml:15-32` に
  完全一致 (`door_open_settle_sec: 1.0`, `open_jump: 0.5`, `far_open_frac: 0.10`,
  `state_stale_sec: 5.0`, `confirm_timeout_sec: 20.0` 等)。
  `EXPERIMENT_YC_BLD7.md:104,107,108` の `exit_clear_dist` 1.5 / `exit_hall_reach` 0.8 /
  `exit_notify_timeout_sec` 30s も一致。
  → **PR #440 は 4 commit すべてがコードと doc を同時に更新しており、追従漏れが無かった**。
- `EXPERIMENT_YC_BLD7.md:109` の `check_planner_map.py` のフラグ (`--env-root` / `--map` /
  `--floors`) が `tools/check_planner_map.py:194-204` の argparse と完全一致。
- `MAPPING.md:28-40` の `dup` サブコマンド表が `launcher/launch_nav2.sh` /
  `launch_slam_toolbox.sh` の case と全件対応。console_scripts も `setup.py:26-32` に登録済。
- controller cascade 順 (`CLAUDE.md:45` / `DEVELOPMENT_GUIDE.md:34`) が
  `rover_main.py:344-349` の `add_tool` 順と完全一致。
- `launcher/` → コンテナ `/common/ros_launcher/` の対応が全 launcher で一貫。
  新規 `launch_nav2/wait_for_tf.py` / `planner.yaml` も実在。

## 次回への申し送り

1. 次回基準線: **rf_rover `b024a537` / drone2 `3a53ebb` / acsl_infra `25c3fb9`**。
2. PR 確認対象: 今夜の **rf_rover #441 / #442 / #443** と、**drone2 #225 / #228**
   (#225 は 3 週間以上 OPEN。滞留を報告に明記すること)。
3. **M24 は再調査不要** — NotebookEdit が deny のままなら grep 1 回で状態確認のみ。
4. 新規 M30〜M38 のうち **M30 (environments/ 廃止の可否)** は M31/M33 の前提になるため、
   管理者方針が決まれば 3 件まとめて機械的に直せる可能性がある。
5. **fan-out の結論は必ずメインループで裏取りすること** — 今回 RBTSTN 誤検知は
   サブエージェントの grep スコープ誤りが原因で、環境リポの `doors_bcps.json` を
   読んで初めて棄却できた。環境リポ (`~/GitHub/sb/environment_*`) は targets.conf 外だが
   **裏取り用に Read 可能**で有用。
