# 2026-10-02 docs-drift (host: ruth)

## 調べた範囲 (前回基準線以降の差分のみ)

| リポ | 前回基準線 | 今回 origin/main | 差分 |
|---|---|---|---|
| project_rf_rover | `b024a537` | **`69464b74`** | 約 75 commits (#448〜#462)。doc 変更 6 ファイル + console / launcher / config / tools 多数 |
| project_drone2 | `3a53ebb` | `3a53ebb` | **変化なし** (3 回連続で 1 commit も動いていない) |
| acsl_infra | `25c3fb9` | `25c3fb9` | 変化なし |

rf_rover で照合したもの:
- 基準線以降に更新された doc の記述 → 実装: `CLAUDE.md` (console 行)、`docs/BCPS_NAV_INTEGRATION.md` (door_lidar の
  `priority`/`cone_deg`/`open_jump`/`open_width_min`)、`docs/DEVELOPMENT_GUIDE.md` (`dup rover gtlog`、
  `rover_gtlog:/tmp/gt_log.csv`、`warn_err` 0.30、`summary_sec`)、`docs/MAPPING.md` (`ros2 run rf_rover map_correct` と
  `--bags/--occ/--base/--floor-map/--cov-max/--switch-grace/--ev-protect`、setup.py の entry point)、
  `docs/ROBOT_SPEC.md` (`ev:` のキーと全 7 機体の `creep_v`)、`docs/EXPERIMENT_YC_BLD7.md` (`save <name>`)
- 実装側の変更 → doc の取り残し: console の `s` を save から stop に変えた件 (#460)、AMCL `recovery_alpha` の
  有効化から無効化への戻し (#451→#461)、`amcl_overrides.yaml` の新設
- 上記以外 (BCPS / gtlog / map_correct / door_lidar / ROBOT_SPEC の数値) は実装と一致。

## 確証指摘 → draft PR (2 本、rf_rover、どちらもドキュメントのみ)

| # | 内容 | 証拠 | PR |
|---|---|---|---|
| D1 | `ROBOT_SPEC.md` の `ev:` 節が全キーを「`_ev_align_overrides` が拾い、未指定なら ObstacleAvoid の既定」と説明していた。実際には `board_front_margin` / `min_wall_gap` を `rover_main.py` が直接読み、未指定時は elevator.yaml の値 (0.08) と 0.02 を使う | `robot_spec.py:79-101` (4 キーのみ) / `rover_main.py:1724-1727, 1768-1771` / `elevator.yaml:112-117` | https://github.com/acsl-tcu/project_rf_rover/pull/463 |
| D2 | gt_logger の CSV は 13 列目に `est_age` を持つが、docstring と `DEVELOPMENT_GUIDE.md:213` の列一覧から抜けていた | `gt_logger.py:85-86` (ヘッダ) と `_tick` の書き出し | https://github.com/acsl-tcu/project_rf_rover/pull/464 |

検証: D1 は参照先 3 ファイルの実在と該当行を `git grep` で確認。D2 は `python3 -m py_compile gt_logger.py` が OK で、
差分は docstring と md のみ。ラベル `nightly-audit` は付けていない (ラベル系は従来から deny のため未試行。タイトル末尾に (nightly-audit) を付けた)。

## 新規 要相談

- **M39 (優先・小)** `console:110` の `do_plot` 失敗時の案内が `Save first: s <name>` のまま。#460 で `s` は **stop** に
  変わったので、案内どおりに打つと save されずに停止が送られる (安全側だがログが残らない)。正しくは
  `save <name>` で直し方は一意だが、**`console` は CLAUDE.md で「管理者に相談」の対象**のため PR にしていない。
  同じ #460 で `show_help` (:59-61) と CLAUDE.md:92 / EXPERIMENT_YC_BLD7.md:95 は追従済みで、残っているのはこの 1 行だけ。
- **M40** `config/nav2/amcl_overrides.yaml:19-20` のコメントに「併せて alpha1 (回転→回転) も少し絞る」とあるが、
  ファイルの作成時 (4f04bd5e) から `alpha1` は一度も設定されていない (上書きしているのは `alpha4` と `recovery_alpha_*` だけ)。
  コメントを消すべきか、`alpha1` の設定が抜けているのかは設計判断が要る。
- **既存 PR #442 が main と衝突し、内容も古くなった**: #442 は CLAUDE.md:92 を `... / stop / s <log> / p [log] [plotcfg]` に
  直す PR だが、main 側は #460 で同じ行を `stop|s / save <log>` に書き換えた。**#442 の版のまま衝突を解消すると、
  廃止された `s <log>` (=save) の記述が戻ってしまう**。この行は「main の行に `/ p [log] [plotcfg]` を足すだけ」に
  するのが正しい。PR ブランチの更新は今夜は行っていない (他 2 hunk は今も有効)。

## 持ち越し状況

- rf_rover の audit PR: **#441 / #442 / #443 (09-21) と #445 / #446 / #447 (09-22) はすべて OPEN のまま**。
  その間に #448〜#462 の 15 本はマージ済みなので、レビュー待ちで止まっている。
- drone2: **#225 (08-29 提出、5 週間 OPEN)**、#228 と #229-231 も OPEN のまま。main が動いていないため新しい drift はない。
- M24 (drone2 notebook): `FPVCam` が残存 (`record_run.ipynb` ×2、`setup_isaac_bld10.ipynb` ×1、`setup_isaac_yc_bld7.ipynb` ×1)。状態は変わっていない。
- M30 (environments/ symlink 廃止の記述矛盾): CLAUDE.md:130 は変わっておらず、方針は未決。M31 / M33 も保留のまま。
- M22 / M23 / M25 / M26 / M18 / M9 / M32 / M34-M38: 対象ファイルが今回の差分に入っていないので再調査していない。

## 捨てた候補

- `gt_logger.py` docstring の `docker cp rover:/tmp/gt_log.csv`: launch_rover.sh:184 は `rover_gtlog` だが、docstring 側は
  「rover コンテナ内で手動 `ros2 run`」する手順なので矛盾しない。
- `amcl_overrides.yaml` ヘッダの「基盤側 (common/...) は触らない」と、同じ PR 群で `launcher/launch_nav2/localization.yaml` に
  beamskip が追加された件: どのマウントが基盤側に当たるかの解釈が要るので、指摘にしない。

## 権限メモ

- 拒否された 3 件 (メッセージ原文は 3 件とも同一):
  「Permission to use Bash has been denied because Claude Code is running in don't ask mode.」
  1. バッククォートを含む正規表現を渡した `git grep -nE`
  2. `git grep -nE "save|console" ... -- README.md AGENTS.md CLAUDE.md docs/README*.md`
  3. `gh pr diff 442`
- 2 は `git grep -n -e save -e "./console" ...` に分けると通った。3 は `git diff <base> origin/<branch>` で代わりに見られた。
- 許可されたもの: PR パイプライン一式 (`checkout -b` / `add` / `commit -F` / `push -u` / `gh pr create --draft --body-file`)、
  `gh pr view --json`、`git show <ref>:<dir>/`。

## 次回基準線
rf_rover **`69464b74`** / drone2 `3a53ebb` / acsl_infra `25c3fb9`
