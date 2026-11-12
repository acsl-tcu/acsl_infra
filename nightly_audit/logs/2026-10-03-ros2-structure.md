# 2026-10-03 ros2-structure (ruth)

## 範囲
- 基準線: rf_rover **a0453bab → 69464b74** (#448-#462 の 67 コミット / 41 ファイル、+2925/-139) / drone2 **3a53ebb → 3a53ebb (0 コミット)**
- drone2 は前回から main が変わっていない。前回の結論と要相談はそのまま有効なので、再走査していない。
- rf_rover の走査は main ループ (git diff と git grep) と Explore 2 本 (柱1/2・柱3) で行った。fan-out の結論はメインループで裏を取った。

## 結果
### 柱1 (module 解決): 12/12 解決
estimator/amcl・slam (4 件)、controller/building_nav (6 件)、line_sim (2 件)。全件で `.py` の実在、`class` の定義、自クラスの `def step(` を確認した。基底クラスに頼るものはない。

### 柱2 (yaml 参照): 壊れた参照 0
- include 6 件 (rover.yaml 4 / line.yaml / sitl_line.yaml) は全て実在する。
- `reference:` に .yaml 形式はなく、`config_file:` もない。
- launcher (launch_nav2.sh / launch_rover.sh / project_launch.sh) の yaml・py・rviz 参照は全て実在する (新規の `config/nav2/amcl_overrides.yaml`・`launch_nav2/localization.yaml` を含む)。
- setup.py console_scripts は 9/9 が `def main` に解決する (新規の gt_logger:196 / map_correct:310 を含む)。
- 重複キー: 14 ファイルで 0 件。

### 柱3 (code→config 供給・契約)
- **typo 不一致 0**。ObstacleAvoid の 48 キー、elevator.yaml・link.yaml・rover.yaml の `planner:`/`recovery:`、robot `ev:`/`drive:`、door_lidar、estimator を全て突合した。
- 新規の `_require` 6 キーは config に全て在る: `board_approach_maxv`、`goal_reach_cov_max`、`exit_align*` の 4 つ。
- PhaseContext の属性読みは全てフィールドに在る (AttributeError の芽なし)。`check_est_trusted` は phase_definition:39 に配線済み。`reseed_barrier`/`last_cov_std` は amcl_estimator に実在する。

## 確証指摘 → draft PR (1 本)
- **#465** https://github.com/acsl-tcu/project_rf_rover/pull/465 — `PersonAvoid.center_deadband_deg` は死にパラメータ。
  - 証拠: building_nav.yaml:230 / person_avoid.py:54。読み手は 0 件。
  - 経緯: 6084cf6d (07-29) で `_avoid_plan` の正面判定が `abs(bearing)<1e-3` 固定になった (:253,:258) が、コメント「これ以内は正面扱い」は残った。
  - 修正: コメントのみ「未使用」に直した (値・挙動は不変)。
  - 検証: py_compile OK。yaml はコメント行だけの差分。
  - ラベル `nightly-audit` は付けていない。既知のとおりラベル系は deny されるため、試行もしていない。

## 前回 PR の状態
- rf **#445/#446/#447 は OPEN の draft のまま**。#446 は `mergeable=MERGEABLE / CLEAN`。
- **#446 の実バグは main でも残っている**。`front_sector_min` の唯一の代入は obstacle_avoid.py:980 で、早期 return の :594/:598 (orient) と :749 (backin) より後にある。
- 今回 main に早期 return が 2 つ増えた: :886 (dock-lock) と :942 (EV docking takeover)。これらは乗車側の経路なので、降車グレースへの影響は orient/backin と同じ構図。merge 時は、代入がセンサブロック直後 (:554-567 付近) に来ることを再確認すること。
- drone2 #229-231 は滞留 (09-10 から)。

## 要相談 (新規)
- **M41 PersonAvoid.steer_gain は yaml 1.2 とコード既定 1.6 が乖離**。6084cf6d が「広めに避ける」ため既定を 1.2→1.6 に上げたが、building_nav.yaml:226 が 1.2 のまま上書きするので、意図した変更が実際には効いていない。どちらを正とするかは設計判断 (実機の人回避挙動が変わる) なので PR にしない。
- **M42 launcher/launch_april.sh:6** は `/common/ros_launcher/launch_april/*` をコピーするが、`launcher/launch_april/` は存在しない。`|| true` で失敗が見えない。launcher/ はスコープ外 (テーマの編集可は tools/ と config/)。
- 軽微: obstacle_avoid.py:20 の `@config_params` に、読み手のない `escape_side_clear` / `escape_center_gain` がある (config 側にはない)。削除はコード整理の判断になるので記録だけ残す。

## 残存 (前回から継続・解消 0)
- M30 (door_lidar.far_range 死に) は ev_door_watch の更新後も `self.far_range` を update() で使っておらず、継続。
- M31 (scan_metrics の inf 扱い) は、新しいグリッド化後も far は isfinite で、扇は inf を開口とする構図が同じなので継続。
- M32 (`EvDoorWatch(**lw)` の TypeError で無言消失) は継続。今回 `diff_*` の 6 キーが __init__ に追加されたが、config 側は既存キーのみで不一致なし。
- M27 / maxw 生産者ゼロ / detour_requested / M20 / M21 / drone2 M16・M17 ほか。
- config 未記載デフォルト 2 件 (`cabin_turn_margin` rover_main:1796 / `arrive_settle_sec` bcps_interface:73) は #445 未 merge のため継続。

## 捨てた候補
- rover_main の target 再シード時、`amcl_estimator` が無いと「_amcl_seed_timer 不在」の警告が出る (文言が実態とずれる)。rover_main は管理者領域で、軽微なので捨てた。
- recovery の `.get(..., 既定)` (rover_main:622-634) は CLAUDE.md の「既定はコードに置かない」に反する形だが、rover.yaml に 6 キー全てが在るため実害なし。

## 権限
deny 1 件。`python3 -c "import yaml; ..."` (yaml の parse 確認) に対する拒否メッセージ原文: "Permission to use Bash has been denied because Claude Code is running in don't ask mode." これは既知の deny。yaml の確認は git diff の目視に切り替えた。そのほかの git checkout/add/commit -F/push/gh pr create --body-file は全て通った。

## 次回基準線
rf_rover 69464b74 / drone2 3a53ebb
