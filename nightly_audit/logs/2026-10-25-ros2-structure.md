# 2026-10-25 ros2-structure (host: ruth)

## 調べた範囲
前回 (2026-10-14) の基準線から、差分だけを見た。

- **project_rf_rover** `69464b74` → `b54d134c` (PR #466-470)
  - 変わったのは `docs/` (setup.md と pandoc 用ファイル) と `setup` だけ。`setup` は管理者ファイル。
  - tools/ と config/ は変更なし。柱1-3 とも前回のまま。
- **project_drone2** `608e9a6` → `5a97194` (約 170 コミット、PR #243/#245/#246、coop 協調 SL)
  - config 10 本、tools 13 本 (hlc_sl 系、ekf_sl_dynamics、sl_state_adjust、sl_coop_reference、
    sl_takeoff_reference、omni_actuator / omni_sensor、vehicle_params) を見た。

### 柱1 (module: の解決)
- coop 系 config の `module:` は 7 件 (hlc_sl_controller / hlc_controller / direct_estimator /
  sl_state_adjust / ekf_sl_dynamics / sl_coop_reference / sl_takeoff_reference、settle と landing の参照)。
- 全てファイル + クラスに解決した。追加・改名された module: は無い。

### 柱2 (yaml 参照の解決)
- `coop_sl.yaml` の参照は全て実在した。
  - extends `sitl_sl.yaml`、include 2 本、phase reference 4 本。
  - isaac の scene_setup_scripts のうちリポ内の 3 本と、コメントで参照するスクリプト
    (set_rope_collision / set_payload_force / diag_coop_stance / diag_coop_com / lib/rope_chain.py)。
- 解決したものは他に 2 種類ある。
  - phase の短名 `sl_state_adjust` / `ekf_sl_dynamics` / `direct_estimator` / `hlc_controller` は、
    各クラスの `name` 属性と一致した。
  - `vehicle: PF2_sl_coop` / `PF2_nominal` は実在した。

### 柱3 (宣言と使用の一致)
- **config → code**: 新規・変更キーは全てコードが読んでいる。
  - hlc_sl_coop (poles23 / cable_anchor_h / ext_force_tangential_only / load_mass_*、その他)
  - sl_coop_omni (taut_ratio / td / vel_lp_alpha / cable_anchor_h / R_angvel / dst_q / mL_init_*、その他)
  - sl_coop_flight (preload.regulate.* / regulate_z.* / start_align.* / settle.*)
  - coop_sl `omni.thrust_error`
- **code → 上流供給**: 下流が読む metadata は、全て上流から供給されている。
  - reference が読む `pL_blend` / `pL_raw` は sl_state_adjust (:260/:270) が出す。最終段の EKF は
    上流 metadata を `setdefault` で中継する (ekf_sl_dynamics_estimator.py:1030-1034)。
  - controller が読む `preload_dst` / `preload_dir` は sl_coop_reference (:703/:710) が出す。
    takeoff 側は preload_dir を出さないが、これは意図どおり
    (hlc_sl_controller.py:320「preload_dir が無い区間は dst を使わない」)。
  - `thrust_error` は drone_main の `_create_actuator` が omni ブロックと drone_id を付けて渡す
    (drone_main.py:760-762)。
  - start_align が使う `context.time.wall_time` は、稼働 checkout の common に定義があった
    (`~/drone/common/acsl/types/context.py:12`、`orchestrator.py:144` で供給)。

## 確証指摘 → PR
| # | リポ | 内容 | PR |
|---|------|------|----|
| 1 | project_drone2 | `config/vehicle/PF2_sl_coop.yaml` のコメント 2 点 (下記) | https://github.com/acsl-tcu/project_drone2/pull/248 (draft) |

PR #248 の中身:
- **:11 P の並び**: 旧 9 要素 `dstx, dsty` を、10 要素 `Fx, Fy, Fz` に直した。
  - 根拠は 6ab6373 と vehicle_params.py:73-88。
- **:18-19 loadmass 内訳**: 鎖 0.24 / Hook 0.05 を、0.05 / 0.24 に直した。
  - 根拠は 2d3603d、coop_sl.yaml:302/:336、同じファイルの :31。

検証:
- `git diff` で、変わったのがコメント行だけ (+4/-3) であることを確認した。`git diff --check` も問題なし。
- ラベル `nightly-audit` は付けていない (gh のラベル系は従来の実測で deny)。

## 要相談 (新規)
- **M49** sl_coop_flight.yaml / sl_takeoff_coop.yaml の数値が、cableL 3.09 (cc308b9) と合わない。
  - 対象箇所:
    - flight :11-12「機体は吊り点から外へ 0.31m」
    - flight :25「2.74/7.75 = 0.35 m/N」
    - takeoff :26「= 0.31m」
  - コードの目標 `_pre_d_blend` は 3.09·sin(atan(0.88/(0.79·9.81))) = **0.349m** になる。
  - ただし、物理ケーブル長と付け根の位置のどちらを基準にするかで「正しい数」が変わる。
    機械的には直せないので PR にしていない。
- **M50** sl_landing_coop.yaml:20「上限 = factor * cableL = 2.4m」の実値は 0.8×3.09 = 2.47m。
  - :10「0.5 × cableL」は load_offset 1.5 のまま (0.5×3.0 の名残)。
  - 軽微。直すかは作者の判断に任せる。
- **M51** PF2_sl_coop.yaml の残り 2 点 (PR #248 で扱わなかったもの):
  - :8「牽引物 m0=0.6kg / N=4 → 0.15kg」(現行は 2.0/4)
  - :39-47「3.0 -> 2.74」の経緯注記 (現値 3.09)
  - どちらも経緯や例示として書かれている。
- **M45 は解消**: 「2 倍」の注記と比較表は、039bbeb の整理で hlc_sl_coop.yaml から消えた。

## 滞留 PR の再確認 (今の main で正しいか)
- **drone2 #242 (mL_q の撤回注記) は close を推奨。** 前提がもう main に無い。
  - a5fa931 で mL_q は 0.1 になり、コメント「0.01->0.1」と値が一致した。
  - その注記自体も 039bbeb で削除された。
- **drone2 #231** (`mL is None` のとき `return self._P` で dst と予張力を捨てる) の欠陥は、main に残っている
  (hlc_sl_controller.py:606-607)。
  - 協調の現設定 `use_estimated_load_mass: false` では、この経路を通らない。
- 以下は全て OPEN/DRAFT のまま:
  - drone2 #225/#228/#229/#230/#231/#241/#247
  - rf_rover #441-447/#463-465
- 前回からの要相談 (M41/M42/M30-32/M27/M20/M21/drone2 M16・M17、#446 の実バグ) は、
  rf に変更が無いので全て残っている。

## 捨てた候補
- `config/omni/coop_sl.yaml:101-104`「Isaac 側の制御 cableL は 2.74」と、:85「load_mass ≈ mass/N」は
  docs-drift の領分 (M47 と同系統)。今夜は扱わない。
- `_u_prev` (付け根モーメント FF の前ステップ推力) がフェーズを跨いでもリセットされない件。
  - 影響は、landing から次の takeoff へ移った最初の 1 step だけ。
  - 実害を確証できないので捨てた。
- `payload.test_force: [1.0,0,0]` は、スクリプトを手で実行しない限り効かない試験値 (10-24 と同じ判断)。

## 権限メモ
- `git grep -n -A25 ...` は deny された。拒否メッセージ原文:
  「Permission to use Bash has been denied because Claude Code is running in don't ask mode.」
  - `git grep -n` に変えて行番号を取り、Read で読んだ。
- `grep -rn` で `~/drone/common` を検索するのは許可された。
- 一時ファイル `logs/.tmp-2026-10-25-commit-msg.txt` / `.tmp-2026-10-25-pr-body.md` は、
  commit の `-F` と `--body-file` に使った。削除系のコマンドは deny されるため残してある。

## 次回の基準線
rf_rover `b54d134c` / drone2 `5a97194`
