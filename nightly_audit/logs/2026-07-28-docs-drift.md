# Nightly Audit 2026-07-28 — docs-drift

- ホスト: ruth / テーマ: docs-drift (ドキュメント/コメントと実装の乖離)
- スコープ: acsl_infra, project_rf_rover, project_drone2 (targets.conf の repo 行 × テーマ対象、全3リポ存在)
- 手法: Explore サブエージェント3並列で新規走査 + 07-17 レポートの持ち越し指摘の現状確認。
  高確度候補は駆動側が Read/grep で反証チェックしてから PR 化。

## ✅ ハーネス権限: git/gh の「全 deny」は誤診と確定 — PR パイプライン初稼働

driver 0.5 の実測 (07-19) どおり、**素の1コマンドなら git/gh は許可**される。今夜、
`git checkout -b audit/* origin/main` → Edit → `git add` → `git commit` → `git push -u origin audit/*`
→ `gh pr create --draft --body-file <file>` の**全行程が headless で成功** (draft PR 3本作成)。
過去レポート (07-17〜07-19) の「git 全 deny」は `git -C` / compound コマンドの前綴不一致による誤診。

今夜観測した deny (拒否メッセージ原文の要旨付き):
- `git branch -D <branch>` → "Permission to use Bash with command git branch -D ... has been denied"
  (destructive)。**`git branch -d` (safe) は許可** — 実際にこれで不要ブランチ削除に成功。
- `gh pr create --draft --title ... --body "<複数行の長文>"` → don't ask mode の汎用 deny。
  **`--body-file /tmp/<file>.md` 形式の単行コマンドなら許可** (今後の定石とする)。
- `gh label create nightly-audit ...` → don't ask mode の汎用 deny (リポ設定変更のため妥当)。
  **3リポとも `nightly-audit` ラベルが未定義**のため、driver の「label を付ける」は実施不能。
  → 管理者へ: 各リポに `nightly-audit` ラベルの手動作成を依頼 (作成後は `gh pr edit --add-label` を試す)。

## 前提の変化: 07-17/07-18 の持ち越し指摘は全て管理者適用済み

- acsl_infra: A1〜A4 → commit d8a3150 で修正済み (origin/main で Read 確認)。
- rf_rover: B1〜B4 → commit 47d2f9d6 で修正済み (AGENTS.md / README / isaac_sim README を grep 確認)。
- drone2: C1〜C2 → PR #150 (56c8e75) で修正済み。ros2-structure の契約 inputs 7件も PR #149 で解消。
- メモリ (git-perm-gap / ros2-structure-pending) を解消済みに更新した。

## 確証指摘と draft PR (今夜の新規検出、3本)

### PR 1: project_drone2 — https://github.com/acsl-tcu/project_drone2/pull/153
ブランチ `audit/docs-drift-sbc-dbuild-and-roadmap-path`
1. `docs/ROADMAP_GAZEBO_SITL.md:110` — `./gazebo_sitl/launcher/launch_px4_sitl.sh` は不在
   (実体 `launcher/launch_px4_sitl.sh`)。56c8e75 が :55 を直した際の :110 取り残し。
2. `docs/sbc_onboard_setup.md:124,125,131` — `dbuild` 第3引数に `dockerfile.drone2` 等を渡すと
   dbuild の補完ロジック (acsl_infra `commands/scripts/dbuild:46-51` が `dockerfile.${DF}` を探す) で
   解決不能。`setup:35-37` と同じ stem 形式 (`drone2` / `mavros2`) へ追従。
- 検証: 参照先実在を ls、dbuild の引数解決を Read で確認。docs のみの変更。

### PR 2: project_rf_rover — https://github.com/acsl-tcu/project_rf_rover/pull/223
ブランチ `audit/docs-drift-bcps-keys-and-paths`
1. `docs/BCPS_NAV_INTEGRATION.md:78,106` — config キー `elevator_id`+「elevator/list 先頭を自動採用」は
   旧仕様。実キー `elevator_name: "ELV1"` (`config/rover.yaml:133`, `bcps_interface.py:61`)、
   自動採用は不使用 (`bcps_interface.py:81` コメントで明記)。
2. `docs/BCPS_NAV_INTEGRATION.md:93,111` — `approach_dist` (5m/5.0) → 実値 2.0 (`rover.yaml:141`)。
   :99 ブロックは「config (rover.yaml)」= 実ファイルの写しを名乗るため実値へ追従 (07-17 B3 と同判定)。
3. `docs/EXPERIMENT_YC_BLD7.md:80` — `docs/ev-radius-unverified` は不在。実体は
   `isaac_sim/scripts/scene/gen_yc_bld7.py:90` の `EV_XY_RADIUS = 3.0`。
4. `docs/EXPERIMENT_YC_BLD7.md:83-84` — `elevator_id` 前提の号機固定手順を、bridge 側
   `packages/bcps_ros2_bridge/bcps_bridge/config/params.yaml:17,20` (`elevator_ids`/`elevator_names`) の
   実仕様へ追従。
- 検証: キー名・値・パスを実ファイルと突合。docs のみの変更。

### PR 3: acsl_infra — https://github.com/acsl-tcu/acsl_infra/pull/56
ブランチ `audit/docs-drift-bashrc-source-and-setup-arg`
1. `README.md:124,246-247` / `for_new_project.md:30` — `bash setup.sh $PROJECT` 直後の
   `source ~/.bashrc` は誤り。setup が書くのは `$ACSL_ROS2_DIR/bashrc` のみ
   (`set_bashrc:19,22,27` は `./bashrc` 固定。ホスト側で `~/.bashrc` に書くコードはリポ内に無し。
   `set_unique_var` は呼び出し元ゼロのデッドコード)。リポ自身の正規案内 (`README.md:202,225`,
   `dup:105`) と同形の `source $ACSL_ROS2_DIR/bashrc` へ追従。dd94f76 で bashrc が非追跡生成物に
   なったため参照の正確さが重要化。仮に外部 hook がある環境でも常に正しい安全側の書き換え。
2. `commands/README_SYSTEMD.md:19` — `./setup.sh` は引数必須 (`setup.sh:10` `$# -ge 1`、無指定は
   `:26` "Require PROJECT name")。`./setup.sh <PROJECT>` へ追従 (`README.md:123` と整合)。
- 検証: 書き込み先・引数ゲートをスクリプト本体で確認。docs のみの変更。

## 要相談 (修正先が一意でない / 仕様解釈・実装側変更が必要)

### 今夜の新規
| # | 場所 | 内容 | 理由 |
|---|------|------|------|
| N1 | rf_rover `docs/BCPS_NAV_INTEGRATION.md:44-56`, `tools/phase/PHASE_FLOW.md:26-27,31-32`, `docs/EXPERIMENT_YC_BLD7.md:4,71` | EV 待機の「orient 保持」記述が現実装と逆。03ee19bc で「回頭後 orient **解除** + gid=nan の standby 静止待機」に変更済み (`phase_actions.py:96-103,130-139` のコード+コメントで確証) | 挙動仕様セクションの書き直しになり「仕様を解釈して書き換える」に該当。提案文言: 「回頭完了/打ち切り後は orient を解除し gid=nan の standby 停止で静止待機 (orient 継続は yaw 推定ノイズでふらつくため)」 |
| N2 | rf_rover `docs/BCPS_NAV_INTEGRATION.md:28-29,136-138` | 「omni_bld10.yaml が `building.backend: action` を明示指定」は旧状態。実ファイルは building セクション無し (bcps 既定を継承、`omni_bld10.yaml:15-17`) | :136-138 の段落削除を含み「行をまとめて削除」に該当 |
| N3 | rf_rover `config/rover.yaml` (building.bcps) | コードが読む `arrive_settle_sec` (既定 6.0、`bcps_interface.py:68,277-279`) が rover.yaml に無い。CLAUDE.md は「デフォルト値はコードにハードコードしない。すべて rover.yaml に明記」と規定 | ドキュメントでなく config (実装側) への追加。値は 6.0 でほぼ確実だが規約準拠の判断は管理者へ |
| N4 | drone2 `docs/sbc_onboard_setup.md:125` | mavros2 の dbuild ベースタグが doc は `jazzy`、`setup:37` は `image_drone2` | どちらが正か (ABI ずれ対策の注記とも絡む) 実装意図の確認要。PR #153 は第3引数のみ修正 |
| N5 | drone2 docs 全般 | `dup mocap` を案内する doc (`sbc_onboard_setup.md:138` 等) があるが、前提の `./setup mocap` (cf66066 で追加、dockerfile.mocap は dup 自動ビルド対象外) がどの .md にも無い | 追記位置・文言の判断要 (欠落補完であり追従でない) |
| N6 | drone2 `docs/PHASE4_TEST_GUIDE.md:19,22` | isaac-sim イメージを `6.0.0-dev2` に固定記載。`setup:68` は `6.0.1` でビルド (ただし `setup:64` のコメントは `6.0.0-dev2` のまま) | リポ内でも値が競合しており意図が確定不能 |
| N7 | acsl_infra `README.md:94` / `for_new_project.md:8` | clone URL が旧リポ名 `acsl-tcu/ros2.git` (実体 `acsl_infra.git`、`.git/config:7`)。ただし GitHub リダイレクトで clone 自体は成功し、生成 dir `~/ros2` は後続の全 `cd ~/ros2` と整合 | 修正が一意でない: URL だけ変えると dir 名が壊れる。`git clone <新URL> ~/ros2` か全パス書換かは方針判断 |

### 07-17 からの継続 (残存を今夜確認)
- acsl_infra `README.md:317` — `packages/acs` 不在 (残存)。
- acsl_infra `packages/README_ROS.md:13-33` — 旧モノレポのパッケージ一覧 (残存)。
- acsl_infra `docker/README_DOCKER.md:25,28,138-153,269` — `ros2_autoware/`・`env.**` 前提の構成図/手順 (残存。env ファイル自体が docker/ に無く、正しい姿は生成 bashrc 前提の書き直しで設計判断要)。
- acsl_infra `commands/setup.sh:20` — 不在の `commands/project_launch.sh` を cp するフォールバック (コード側バグ、残存)。
- drone2 `docs/ROADMAP_GAZEBO_SITL.md:68` — `launcher/launch_gazebo_sitl.sh` 不在 (残存。実体が launch_mavros2.sh か launch_px4_sitl.sh か確定不能)。

## 捨てた候補 (誤検知として棄却)

- acsl_infra の新規4コミット (bashrc 分離・実行ビット・FASTRTPS passthrough・max_msg_size) 起因の
  新規ドリフト — なし (生成物パス `$ACSL_ROS2_DIR/bashrc` は不変で全参照が有効のまま)。
- rf_rover の elevator 系定数 (`exit_clear_dist` 1.5m / `exit_notify_timeout_sec` 30s /
  `orient_timeout_sec` 8s / `poll_sec` / `hold_door_sec` / `arrive_timeout_sec`) — docs と rover.yaml 一致。
- rf_rover `odom_calib.scale_w` 1.03 較正 — rover.yaml コメント・omni 系 override とも整合。
- drone2 mocap イメージ (cf66066) の dockerfile/launcher 参照、`dup mocap` の usage — 実体と一致
  (doc 欠落は N5 として要相談へ)。
- drone2 `ROADMAP.md:179` "ros-humble-mavros" — 歴史記述 (Phase 6 成果表) であり実在主張でない。

## PR まとめ

| リポ | PR | 内容 |
|------|----|------|
| project_drone2 | https://github.com/acsl-tcu/project_drone2/pull/153 | ROADMAP パス取り残し + dbuild 第3引数 |
| project_rf_rover | https://github.com/acsl-tcu/project_rf_rover/pull/223 | elevator_name キー + approach_dist 実値 + EV_XY_RADIUS 実パス |
| acsl_infra | https://github.com/acsl-tcu/acsl_infra/pull/56 | source 先 $ACSL_ROS2_DIR/bashrc + setup.sh 必須引数 |

いずれも draft・docs のみの変更・`nightly-audit` ラベルは未付与 (ラベル未定義 + `gh label create` deny)。

## 次回への引き継ぎ

- **PR パイプラインは稼働可** — 静的テーマは「検出+レポート止まり」運用を撤廃。定石:
  素の1コマンド分解 / PR 本文は `--body-file` / ブランチ削除は `-d` (`-D` は deny)。
- 各リポへの `nightly-audit` ラベル作成を管理者に依頼中 (上記)。
- ローカル audit ブランチ 3本 (push 済み・merge 待ち) が各ソースクローンに残る。merge 後に
  `git branch -d` で整理可 (branch-cleanup テーマの対象)。
- acsl_infra のローカル main は origin/main より 6 コミット遅れ (ハーネスの fast-forward 未実施)。
  監査は origin/main 基準なので実害なしだが、ハーネス側で `git pull --ff-only` を検討。
- driver 手順4 のコミットテンプレは `Co-Authored-By: Claude Opus 4.8 (1M context)` だが、実行モデルは
  Fable 5 のため `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` を使用した (テンプレ更新推奨)。
