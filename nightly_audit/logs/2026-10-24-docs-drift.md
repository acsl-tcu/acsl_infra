# 2026-10-24 docs-drift (host: ruth)

## 調べた範囲
- 前回 (2026-10-13) の基準線から差分だけを見た。
  - acsl_infra `25c3fb9`: **変化なし**
  - project_rf_rover `69464b74` → `b54d134c`: PR #466-470。新規 `docs/setup.md` (+ pandoc 用の
    copybutton.html / github.theme / qiita.css) と `setup` の ROBOTS を megarover2 だけにする変更
  - project_drone2 `608e9a6` → `5a97194`: 約 125 コミット (PR #243/#245/#246、coop 協調 SL)。
    ドキュメントに当たるのは新規 `docs/coop_pretension_state.md`、`hlc_sl/README.md`、config コメント、
    新規 isaac_sim スクリプト (diag_coop_com / diag_coop_masses / set_payload_force) の docstring
- rover `docs/setup.md` で確認したもの:
  - 実在した: `config/robot/*.yaml` の `sim.usd` 7 件 (表記と一致)、notebook 2 本のセル 0/1 の内容、
    `config/{local,exp,exp_yc_bld7,omni_bld10,omni_yc_bld7}.yaml`、`./setup` の full/isaacsim/yolo 分岐と
    full のイメージ一覧、`env_sync` の引数なし一括 pull、`disaac`、関連ドキュメント 6 本、`env_setup_guide.txt`
  - 実在しなかった: 1 件 (要相談 M46)
- drone2 で確認したもの: `coop_pretension_state.md`「現在の構成」の preload.force 0.88 (2 か所)、
  use_estimated_* false、taut_ratio 0.99、P 10 要素。いずれも config と一致した。
  削除済みキー (coop_peer_link / ext_force_share / internal_force / wl_gain 等 12 個) の残り参照も検索した。

## 確証指摘 → PR
| # | リポ | 内容 | PR |
|---|------|------|----|
| 1 | project_drone2 | `config/omni/coop_sl.yaml:87-88` payload コメントの「鎖 0.24 + Hook 0.05」→「鎖 0.05 + Hook 0.24」。根拠は `2d3603d` で入れ替えた後の実値 (:302 `rope_mass: 0.05` / :336 `hook_mass: 0.24`)。合計 0.29/0.79 は不変 | https://github.com/acsl-tcu/project_drone2/pull/247 (draft) |

- 検証: `git diff` でコメント 2 行だけの変更であることを確認した。py での yaml ロード確認は deny された
  (`python3 -c ...`。拒否メッセージ原文: 「Permission to use Bash has been denied because Claude Code is
  running in don't ask mode.」)。キーと値には触れていない。
- ラベル `nightly-audit` は付けていない (gh のラベル系は従来の実測で deny)。

## 要相談 (新規)
- **M46** rover `docs/setup.md:281` が `docs/experiment_checklist.md` を参照しているが、rover にこのファイルは無い
  (rover 全体を `git grep checklist` で検索してもこの 1 行だけ)。drone2 には `docs/experiment_checklist.md` がある
  (drone2 の setup.md を写したときの残りとみられる)。削除するか、rover 版を作るかは判断が要る。
- **M47** drone2 `config/omni/coop_sl.yaml` の isaac_sim.rope ブロックの :266「12 節 + 0.24kg … (現設定)」/
  :271「鎖全体 0.24kg + Hook 0.05kg」/ :275 / :307「rope_mass 0.24 は実ケーブル由来なので触らない」が、
  現在の rope_mass 0.05 と食い違っている。作者が :279-283 に `★2026-10-09` の変更注記を追記する形で残しているため、
  履歴として残しているのか直し忘れなのかが分からない。PR にはしていない。
- **M48** drone2 `ekf_sl_dynamics_estimator.py:50` の「sl_coop_flight.yaml の internal_force の役目」:
  `internal_force` は 039bbeb で削除された (coop_pretension_state.md の「削除したもの」)。いまどこがその役を
  担うのか (予張力 / 外へのずれのレギュレータ) は解釈が要るので、PR にしていない。

## 滞留 PR の再確認 (今の main で正しいか)
- **drone2 #241** (coop_update_guide の segments 6→12 / 分担荷物 2.0/4): 変更する 2 点は今の main
  (segments 12, payload.mass 2.0) でも正しい。ただし同じ yaml 抜粋の `rope_mass: 0.24 # ★12 節で 1リンク
  0.0200kg` が、今の main の 0.05 と食い違うようになった。#241 は壊れていないが、その抜粋は依然として部分的に古い。
  ガイドの文脈は「ケーブルを重くした」経緯の説明なので、0.05 に直すのは書き換えになる (M47 と同じ扱い)。
- **drone2 #228**: 前回と同じく close を推奨 (逆向き)。
- **M43** (guide の R23 説明): `hlc_sl_coop.yaml:79` の R23 は 10.0 になり、さらに離れた。
- **M44** (coop_sim k_cable 8 の near-taut): 変化なし。
- rover #441/#442/#443/#445/#446/#447/#463/#464/#465、drone2 #225/#228/#229/#230/#231/#242 はすべて OPEN/DRAFT のまま。
- 既存の要相談 M9〜M45 に変化なし。

## 捨てた候補
- `ekf_sl_dynamics_estimator.py:62`「観測 (MATLAB と同じ ["p","q","pL","pT"])」: R_angvel (ジャイロ) は
  オプションとして :395-404 に説明があり、既定値 (None) では記述どおり。drift ではない。
- `coop_pretension_state.md` の (歴史) 節の行番号参照・旧キー: 文書が自分で「歴史。上と食い違うところは上が正」
  と宣言しているので対象外。
- `coop_scene_spec.md:55`「既定 0.24kg/本」: `rope_chain.py:217` のコード既定値 0.24 と一致する。
- `set_payload_force.py` docstring「既定 [0, 0, 0] = 外す」: キーが無いときのコード既定値のこと。config の
  `test_force: [1.0,0,0]` は試験値 (スクリプトを手で実行しない限り効かない)。drift ではない。
- rover `docs/setup.md:59`「`megarover3_*`」: `megarover_description` を厳密には含まない略記。意味は通るので捨てた。

## 次回の基準線
rf_rover `b54d134c` / drone2 `5a97194` / acsl_infra `25c3fb9`
