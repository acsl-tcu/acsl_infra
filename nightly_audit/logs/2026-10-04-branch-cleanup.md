# 2026-10-04 branch-cleanup (host: ruth)

## 結論
- **自動整理 0 件** (5 checkout すべてで `git branch --merged origin/main` に main 以外の候補なし。
  非 main 在圏は infra src のみで、未マージ + 汚れのため不触)。
- detached HEAD なし。
- 稼働コンテナ: `isaac-sim` (Up 34 hours, **unhealthy**) のみ。rf_rover / drone2 の ROS コンテナは 0 本
  (前回 09-23 は rf_rover 系 9 本稼働 → 全停止)。
- PR は作っていない (本テーマの規定どおり)。

## 調べた範囲
| checkout | branch | 汚れ | origin/main との関係 |
|---|---|---|---|
| ~/GitHub/sb/acsl_infra | `fix/dup-image-ref-normalize` | ?? 51 (監査ログ) | ahead 1 (c44bfb0, PR #66 OPEN) |
| ~/GitHub/sb/project_rf_rover | `main` | なし | = origin/main 69464b74 |
| ~/GitHub/sb/project_drone2 | `main` | なし | = origin/main 3a53ebb |
| ~/rover (deploy) | `main` | M40 / ??6 | **behind 74** (b024a537) |
| ~/drone (deploy) | `main` | M3 / ??1 / stash 1 | **ahead 4** (main に直接 commit) |

## 前回 (09-23) からの差分
- **解消**: rf_rover src の `fix/door-leg-through` (未 push 18 commit) → origin に push され、main へマージ済み
  (`origin/fix/door-leg-through` が `git branch -r --merged origin/main` に出る)。ローカル枝も消え、src は main・クリーン。
- **解消 (実質)**: ~/rover の大汚れは今や origin/main のミラー。`git diff --stat origin/main` で
  差分は 6 ファイルのみ。そのうち untracked の 3 ファイル (`config/nav2/amcl_overrides.yaml`,
  `tools/debug/gt_logger.py`, `tools/mapping/map_correct.py`) は src (= origin/main 69464b74) と
  `diff -q` で**完全一致**。
- **新規 (要注意)**: ~/drone の **ローカル main が origin/main より 4 commit 先行** (下記)。

## 要相談 (変更は何も加えていない)

### 1. ~/drone: ローカル main に未 push の commit が 4 本 (最重要・新規)
`git log origin/main..HEAD` (`git branch -r --contains HEAD` は空 = どのリモート枝にも無い):
```
52a68bd 2026-10-02 feat: coop で推定荷物質量を有効にする (use_estimated_load_mass: true)
5b672a9 2026-10-02 feat: 推定荷物質量に変化率の上限 (load_mass_rate) を追加する
e38e224 2026-10-02 feat: 牽引物を 2.0kg にし loadmass をケーブル込みの物理値へ追従させる
f7ad034 2026-10-02 feat: 生成ケーブルを 12 節 / 鎖 0.24kg に戻す (1リンク 0.0200kg 維持)
```
親は origin/main 3a53ebb (#226 マージ)。この作業は deploy checkout にしか存在しない。main へ直接 push は
禁止なので、`feature/...` 枝を切って push → PR を推奨 (#221 feat/coop-load-mass-estimator と関連する可能性あり)。
加えて未コミット: `M config/controller/hlc_sl_coop.yaml`, `M config/omni/coop_sl.yaml`,
`M isaac_sim/notebooks/setup_isaac_coop_drone.ipynb` (計 +39/-41)、`?? launcher/launch_speech_recognition.sh`。
このため次回 `gpull`/ff は止まる。

### 2. ~/drone: stash@{0} (5 run 連続)
`stash@{0}: WIP on feature/omni-sl-align: ed08094 ...`。`origin/feature/omni-sl-align` はマージ済み。
中身を残すか捨てるかを手動で判断する必要がある。

### 3. ~/drone: 未マージのローカル作業ブランチ (削除不可・情報)
| branch | PR |
|---|---|
| feat/coop-load-mass-estimator | #221 OPEN |
| fix/coop-ext-force-units | #227 OPEN |
| feat/hlc-firmware-c | PR なし |
| feature/voice_recognition | PR なし |
| fix/coop-notebook-newlines (新規, 10-01) | **PR なし** (voice_recognition の "Add packages" 6d35e4d の上に作られている) |

`fix/coop-notebook-newlines` は voice_recognition に積まれているので、PR にすると無関係な "Add packages" も入る。注意。

### 4. acsl_infra src: `fix/dup-image-ref-normalize` に滞在中 (継続)
PR #66 OPEN (2026-09-18〜)。untracked の監査ログが **51 件** (前回 40) — 2026-08-14 以降の
`nightly_audit/logs/*.md` が未 commit のまま。#66 マージ後に main へ戻して、ログを commit (要判断)。

### 5. ~/rover: behind 74 (汚れで ff 不可・継続)
origin/main との実差分は次だけ:
- `config/omni_yc_bld7.yaml`: map コメントが短い旧版で、`map:` 直下に、意図の不明な行 `  # ` がある
- `isaac_sim/scripts/maps/gen_occupancy_from_usd.py`: 同じ箇所のコメントが旧版 (コードの差は無し)
- `isaac_sim/notebooks/setup_isaacsim_yc_bld7.ipynb`: 大差分 (1773 行)。実質的に残る唯一の差
- untracked: `isaac_sim/config/layouts/workspace_ss.json`, `isaac_sim/notebooks/Untitled.ipynb`, `rosbag/` (260925_* ほか 6 件)

→ notebook と rosbag/ の扱いを決めれば、残りを捨てて ff すれば最新化できる (本テーマは restore/clean しない)。
コンテナは停止中なので、作業するなら今がタイミング。

### 6. isaac-sim コンテナが unhealthy で 34 時間稼働
情報として記載。deploy 切替の判断材料にしてほしい。

### 7. リモートにマージ済みのまま残る枝 (情報のみ・削除していない)
- project_rf_rover (src): 20 本 (前回 6 → 増加)。fix/door-leg-through, fix/ev-* 系 8 本, fix/amcl-*, fix/console-s-stop ほか
- project_drone2 (src): 1 本 (`feature/coop-cable-rope-chain`、#226 マージ済み)
- acsl_infra: 0 本
- ~/drone の remote-tracking には 25 本が見えるが、src では消えている枝が大半。deploy 側の fetch が prune されていないため
  (`git fetch --prune` で解消。ローカル操作なので無害だが、本テーマ規定外のため実施せず)

## 滞留 PR (参考)
- rf_rover: audit PR 9 本がローカル枝として残存 (#441-447, #463-465 系。いずれも未マージなので -d 対象外)
- drone2: #225 / #228-231 OPEN

## 権限
deny 1 件: `git hash-object <files>` (~/rover)。原文:
> Permission to use Bash has been denied because Claude Code is running in don't ask mode.

代わりに src clone との `diff -q` で裏取りした (許可された)。他の deny はゼロ。
