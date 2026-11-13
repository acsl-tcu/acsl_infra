# 2026-10-13 docs-drift (host: ruth)

## 調べた範囲
- 前回 (2026-10-02) の基準線から差分のみを見た。
  - project_rf_rover `69464b74`: **変化なし** (origin/main HEAD = 69464b74)
  - acsl_infra `25c3fb9`: **変化なし**
  - project_drone2 `3a53ebb` → `608e9a6`: 23 コミット (#237〜#240 coop 協調搬送の調整)。
    15 ファイルが変わり、そのうちドキュメント/コメントに当たるのは `docs/coop_update_guide.md` と
    config 4 本 (omni/coop_sl, vehicle/PF2_sl_coop, reference/sl_coop_flight, controller/hlc_sl_coop) のコメント。
- 新規コメントが参照している関数/キーの実在を確認した: `sl_coop_reference._build_settle_stop` (:367)、
  `rope_chain.py` の 100 倍 WARNING (:408-428)、`isaac_sim.rope.hook_mass` (coop_sl.yaml:275)、
  `coop_sim_node.py`。いずれも実在する。

## 確証指摘 → PR
| # | リポ | 内容 | PR |
|---|------|------|----|
| 1 | project_drone2 | `docs/coop_update_guide.md:102` `segments: 6` → 12 (実 config :258 と同じブロックの rope_mass コメントに一致)、`:118` 分担荷物 `0.6/4 = 0.15kg` → `2.0/4 = 0.50kg` (payload.mass 2.0 は coop_sl.yaml:108) | https://github.com/acsl-tcu/project_drone2/pull/241 (draft) |

- 検証: 修正後の値を `git grep` で config と突き合わせた。ドキュメント 2 行のみの変更。
- ラベル `nightly-audit` は付けていない (gh のラベル系は前回までの実測で deny)。

## 要相談 (新規)
- **M43** `docs/coop_update_guide.md` 2-4 の `R23: 0.01 → 0.1` (帯域 0.56Hz の説明) が、現在の
  `hlc_sl_coop.yaml:80 R23: 0.00001` (2026-10-06 の Q23/R23 再調整) と合わない。ゲイン設計の説明を
  書き換えることになるため PR にしていない。
- **M44** `config/omni/coop_sl.yaml` の coop_sim ブロックで、`k_cable: 8` 等のコメント
  `(near-taut)` と `substeps` の「高剛性の安定化」は、800→8 へ下げた後の値と意味が合わない。
  作者の意図を解釈する必要があるため対象外とした。
- **#228 は逆向きになった**: drone2 の監査 PR #228 (coop_scene_spec を 6 節 / 0.12kg に揃える) は、
  main が 12 節 / 0.24kg に戻ったため、いまマージすると正しい docs を壊す。**close を推奨**
  (ただし attach_path_template の注記部分は別途再検討の余地あり)。

## 持ち越し状況
- rover の監査 PR #441/#442/#443/#445/#446/#447/#463/#464/#465 はすべて OPEN のまま。
- drone2 の #225/#228/#229/#230/#231 も OPEN のまま (#228 は上記のとおり陳腐化)。
- 既存の要相談 M9〜M42 に変化なし (rover/infra のコードは不変)。

## 権限メモ
- 拒否された操作: `gh pr diff 228 --name-only`。拒否メッセージ原文は「Permission to use Bash has been
  denied because Claude Code is running in don't ask mode.」。代わりに
  `git diff --stat origin/main...origin/audit/...` で確認できた。

## 次回の基準線
rf_rover `69464b74` / drone2 `608e9a6` / acsl_infra `25c3fb9`
