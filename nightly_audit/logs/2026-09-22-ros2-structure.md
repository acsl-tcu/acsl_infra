# 夜間監査レポート 2026-09-22 — ros2-structure

- ホスト: ruth / 実行: 無人 (cron)
- 対象: project_rf_rover, project_drone2 (targets.conf kind=repo との積集合)
- 方式: 前回 (2026-09-11) 基準線からの差分走査 + 柱1/柱2 は全数再チェック
  (Explore fan-out 3 体 + メインループで git 裏取り。実機・コンテナ操作なし)
- 基準線からの差分:
  - **rf_rover: fbfb7997 → a0453bab、26 コミット / 25 ファイル**。EV 扉の LiDAR 判定
    (新ファイル `tools/sensor/ev_door_watch.py`)、降車グレースの条件化、nav2/Isaac 修正が中心。
    PR #444 (fix/ev-door-lidar-gap) までマージ済。
  - **drone2: 3a53ebb のまま変更なし** (0 コミット)。よって drone2 側は前回結論がそのまま有効。
- rf_rover の作業は `origin/main` から切ったブランチで実施。ソースクローンは元の
  `fix/door-leg-through` に復帰・クリーン確認済 (監査で汚していない)。

## 結論: **確証指摘 3 件 → draft PR 3 本 (全 rf_rover)**。柱1/柱2 は両リポ健全 (欠落ゼロ)。新規「要相談」3 件 (M30/M31/M32)。

### 前回 PR の状態
- drone2 **#229 / #230 / #231 は 3 本とも OPEN の draft のまま** (最終更新 09-10、レビュー未着手)。
  drone2 main に変更が無いため、指摘内容は全て現存する。**レビューを待っている状態**。
- 参考 (本テーマ外): drone2 #225 / #228 (docs-drift) も OPEN 滞留。#227 は OPEN (非 draft)。
  rf_rover #441 / #442 / #443 (docs-drift 09-21) は OPEN の draft。

## 開いた PR (すべて rf_rover / draft)

1. **#447** https://github.com/acsl-tcu/project_rf_rover/pull/447 —
   docs(config): `Saturation.maxv/maxw` が毎ループ上書きされる旨の注記をそろえる。
   `rover_main.py:956-962` が両分岐で maxv/maxw の**両方**を `slam_jump.*` から上書きするのに、
   注記が `building_nav.yaml:176` は maxw のみ・`line_sim.yaml:15` は maxv のみと**逆側**に付いていた。
   コメントのみ・値変更なし。前回「次回 PR 候補」に挙げた項目の消化。
2. **#445** https://github.com/acsl-tcu/project_rf_rover/pull/445 —
   docs(config): EV 制御の既定値 2 件を config に明記。
   `building/link.yaml` の `bcps:` に `arrive_settle_sec: 6.0` (読み手 `bcps_interface.py:73`、
   同ブロックの他 5 キーは全て記載済みでこれだけ欠落)、`building/elevator.yaml` に
   `cabin_turn_margin: 0.05` (読み手 `rover_main.py:1671`、`git grep` で config 側 0 件)。
   **値はコード既定と同一なので挙動不変**。CLAUDE.md:102「デフォルトをコードにハードコードしない」準拠。
3. **#446** https://github.com/acsl-tcu/project_rf_rover/pull/446 — ★本命 (実バグ)
   fix(controller): **降車グレースが「前面開放」で解除されず、20s 上限でしか切れない**。
   `obstacle_avoid.py:61-62` は `front_sector_min` を「**毎 step 更新**し rover_main が降車グレースの
   解除条件に使う」と宣言しているのに、実際の更新 (`:776`) が **orient / backin の早期 return
   (`:460-472` / `:583`、他に EV ドック `:675` / `:729`) より後**にあった。
   EV 降車はまさにその 2 経路で走る — 回頭降車 = `md["orient"]` (`tscf_controller.py:169`)、
   後退降車 = `_action_ev_backout` が exit 判定まで `set_backin` を維持 (`phase_actions.py:394-421`)
   → `building_reference.py:354` → `md["backin"]` (`tscf_controller.py:167`)。
   結果、降車中ずっと乗車前の値が凍り、`rover_main.py:857-866` の解除判定
   (前面 ≥ `exit_grace_front_open` が `exit_grace_open_cycles` 周期) が成立しない。
   `grace_active` は障害物回避の減速下限・停止距離を緩めるモード (`obstacle_avoid.py:799,897,941,1087`)
   なので、カゴを出た後も最大 20s 感度が下がったまま走る。
   **直近コミット c021fba6「降車グレースを時間から前面開放条件に変更」の意図が、当の対象ケースで
   効いていない**。修正 = 更新を全 return より前 (back_min 算出直後) へ移動。計算内容は不変。
   `git grep` で `front_sector_min` の読み手が rover_main (step 後) だけ = 内部読み手ゼロを確認済。

ラベル `nightly-audit` は権限制約 (gh label 系 deny) で付与できず、3 本とも PR 本文に監査生成の注記を明記。

## 網羅範囲 (柱1/柱2)

### 柱1: Tool 登録の解決性 — **12/12 全解決** (rf_rover)
- config の `- module:` は **12 行 / 10 クラス** (TSCFController と Saturation は 2 回ずつ登録)。
  全て実ファイル + `class` + `def step(` に解決。`building_module:` (omni_*.yaml の Isaac シーン生成器名)
  2 件は tool 登録ではないので除外。
- `rover_main.py` の直 import / 遅延 import も全解決。`step()` を持たない 3 件
  (Nav2PathClient / BcpsInterface / BUILDING_INTERFACE) はいずれも注入ヘルパで正。
- `set_cascade()` の短名 10 件 (`amcl` / `slam_estimator` / `apriltag` / `pdaf_fusion` / `tscf` /
  `obstacle` / `person_avoid` / `lane_keep` / `anti_stack` / `saturation`) は全て `name` 属性と一致。
- **新規 `ev_door_watch.py` は Tool ではない** — `step()` も `name` も持たず、config にも
  `rover_main` にも tool 登録は無い。`EvDoorWatch` は `BcpsInterface` が保持するヘルパで
  (`bcps_interface.py:33,92`)、指標計算は `rover_main._update_ev_door_watch()` (`:652-689`) が
  `orch.step()` の**後**に行い `set_ev_scan()` で注入する。
  → **CLAUDE.md:70 の既知の落とし穴 (sensor は parallel で `results[-1]`。検知ツールを
  `sensor_cat` に add_tool すると `get_upstream("sensor")` が壊れる) は踏んでいない**。
  `sensor_cat` の add_tool は `BuildingSensor` 1 本のみ (`rover_main.py:322-324`)。
  `get_upstream("sensor")` 消費者 8 箇所は全て無影響。
- drone2: main 不変のため前回の 16 件全解決がそのまま有効 (再走査せず)。

### 柱2: config の参照解決性 — **壊れた参照 0 / 重複キー 0 / 死に config 0**
- パス形式参照 **26 件**: `include:` 6/6 実在、`.py` スクリプト参照 10/10 実在
  (環境リポ優先 → rover `scene/` フォールバック、`set_env.py:234-249`)。
  `/ENV/...` の USD 等 10 件は**設計上リポ外** (ホスト手動配置) なので「欠落」と判定しない
  (この session では `~/ENV` の ls が権限で不可)。
- 短名参照 13 件 (`localizer` / `odom_source` / `reference` / `planner.type` / `building.backend` /
  `exit_mode` / `board_mode` / `door_lidar.priority` 等) は全てレジストリに解決。
- 重複キー: 変更 7 ファイル (elevator / link / building_nav / omni_bld10 / omni_yc_bld7 /
  megarover2 / rover) を全文読みして **0 件** (前回 #433 の再発なし)。
  ただし YAML パーサでの機械検証は未実施 (下記「権限実測」)。
- 新規/変更 config のキー供給: `elevator.yaml` 20+10 キー・`link.yaml` 13 キー・
  `building_nav.yaml` 77 キーとも **死に config 0**。
  `door_lidar` の 7 キーは `EvDoorWatch(**lw)` の **kwargs splat** 経由で消費されるため
  素の grep では 0 件に見える — **「grep 0 件」を死に config と即断すると誤判定になる実例**
  (前回メモの再確認)。`enabled`/`stale_sec`/`priority` は `pop` 済みで残り 7 個が
  `EvDoorWatch.__init__` の 7 引数とちょうど一致 (過不足なし)。
- `config/paths/` は **drone2 側**のディレクトリ (rf_rover には存在しない)。前回 M16 の
  欠落 2 本は drone2 main 不変のため残存。

### 柱3: 変更コードの契約・状態整合
- 上記 PR #446 が唯一の確証指摘。他は下記「要相談」「軽微」へ。
- pub/sub ライフサイクル: `BuildingSensor` / `BcpsInterface` とも購読・タイマ・サービス
  クライアントは全て `__init__` で 1 回だけ生成 (毎 step 生成なし = リークなし)。
- frame_id: `/scan` マージは前 LiDAR フレームで統一 (`building_sensor.py:446-485` で後方を
  視差補正して同一フレームへ) / `map` 系・`odom→base_footprint` とも整合。欠陥なし。

## 新規「要相談」 (M30〜M32)

- **M30 (rover_main.py 管理者領域 / 中価値): `door_lidar.far_range` が効かない死にパラメータ**。
  `elevator.yaml:36 far_range: 2.0` は `EvDoorWatch.__init__` に渡って `self.far_range` に
  格納される (`ev_door_watch.py:90`) が、**このフィールドはどこからも読まれない**
  (`git grep far_range` の全 7 ヒットで確認)。遠ビーム本数を実際に数えるのは
  `scan_metrics()` の引数 `far_range` (`:37,52`) で、呼び出し側 `rover_main.py:678-681` は
  `cone_deg` しか転送していない (`door_cone_deg()` アクセサ経由) ため、**常に既定の 2.0 が使われる**。
  現状の config 値が偶然 2.0 なので実害は出ていないが、**値を変えても効かない罠**。
  修正案 = `cone_deg` と同形に `BcpsInterface.door_far_range()` を足して `scan_metrics` へ渡す。
  呼び出し側が rover_main.py のため PR 化せず。同種で `scan_metrics(min_range=0.05)` も
  config 経路なし。
- **M31 (設計判断・安全影響あり): `scan_metrics()` の `inf` の扱いが 2 経路で矛盾**。
  docstring (`ev_door_watch.py:44`) と扇の処理 (`:58`, `:130`) は **無反射 `inf` を「開口」として数える**
  が、遠ビーム数 `far` (`:52`) は `valid = isfinite(r) & ...` で **`inf` を除外**する。
  カゴ内判定は `far_count` だけで駆動される (`:106-110`) ため、LiDAR が無反射を `inf` で返す
  構成では「扉が開いて広いホールが見えた」瞬間に far が増えず閉扉と誤判定し、
  `closed_seen` が立ちっぱなしになりうる。
  逆に `inf` を far に数えるよう直すと、**暗色/光沢のカゴ内壁で無反射が出る建屋では
  閉扉を開扉と誤判定して閉じた扉へ進入する**可能性があり、安全側の判断が要る。
  横浜実測データは有限レンジだったため現状は顕在化していない模様。**実機データでどちらが
  正しいかを確認してから直すべき**なので PR 化せず。
- **M32 (低・要方針判断): `door_lidar` の kwargs splat は将来のキー追加で起動時に落ちる**。
  `bcps_interface.py:92 EvDoorWatch(**lw)` は `pop` 後の残りを全て渡すため、
  `elevator.yaml` の `door_lidar:` に説明用でも 1 キー足すと `TypeError`。しかもそれを
  `rover_main.py:504-511` の `except` が握り潰して `self.bld = None` にするので、
  **建屋インターフェースが丸ごと無言で消える** (起動は続く)。
  併せて `rover_main.py:501` は `door_lidar` 辞書ごと `setdefault` するため、
  `building.bcps.door_lidar` を部分上書きすると `elevator.door_lidar` が丸ごと置換される。

## 軽微 (PR 化せず記録のみ — 次回再報告しない)

- `building_sensor.py:539 _publish_scan_debug()` は**呼び出し元ゼロの死にコード**
  (実働は `:550 _publish_scan_status_debug`)。また `/scan_debug` に
  `building_sensor.py:239` と `rover_main.py:375` の 2 つの publisher が同居し、
  `event=scan_status` と `event=mainloop_scan_status` が混ざる (パース時に注意)。
- `bcps_interface.py:445-446` の `elif (self._arrive_ok_t0 > 0.0 and not self._arrived(target))`:
  直前の `if self._arrived(target)` が偽なので `not self._arrived(...)` は冗長な二度目呼び出し。
- `obstacle_avoid.py` の `_ev_dock_lock` / `bcps_interface.py` の `_door_closed_seen` は
  `__init__` で初期化されず分岐内で生成される。読みは概ね `getattr(..., False)` で防御
  されているが `bcps_interface.py:515` だけ素の属性アクセス (現状は `:506` のステージ
  ゲートで到達前に必ず生成されるため安全。新しい `_stage` 遷移を足すと壊れうる)。
- `config/omni_yc_bld7.yaml:42-45` の `slam_jump:` 配下だけインデントが 4 スペース (他は 2)。
- `config/omni_bld10.yaml:88-90` のコメントが `collider_zones` の説明なのに
  `collider_approximation:` の上に付いている (yc_bld7 側は正しい位置)。
- CLAUDE.md:53「フェーズ遷移時に `Agent.apply_allocation()` が有効ツールを切り替える」は
  **このクローンのコードでは行使されていない** (`PhaseAllocation` は `phase_definition.py:15` で
  import のみ、`apply_allocation` の呼び出しは packages/ に 0 件)。→ docs-drift 側の候補。

## 持ち越し「要相談」の状態変化

- **解消 0**。drone2 側 (M16/M17/M20/M21 ほか) は **main 不変のため全件そのまま残存**。
- rf_rover 側の個別確認:
  - **M27 (single_lidar の back topic が必ず上書きされ不到達)**: 残存。`rover_main.py:203-205` →
    **`:212-214`** へ行番号が移動しただけで構図は同一 (`scan_cfg.get("back_topics")` が truthy なら
    無条件上書き / `rover.yaml:229-231` は常に定義)。`go2.yaml:58` `whill.yaml:42` `rbq10.yaml:42` の
    3 機体で後方系ガードが無言で無効のまま。**高価値・未解決**。
  - **maxw 生産者ゼロ**: 残存 (`obstacle_avoid.py:373` → **`:417`**)。`prev.metadata.get("maxw", 1.5)` に
    対し `maxw` を metadata へ書く生産者はリポ全体に無く、常に 1.5 が効く
    (config の `TSCFController.maxw: 1.0` / `Saturation` 側 0.6 と不一致)。下流 Saturation が
    再クリップするため実害は限定的。
  - **detour_requested 不到達**: 残存かつ根拠追加。`building_reference.py:284-286` が
    **下流カテゴリ** `get_upstream("controller")` を読んでおり、生産者 `anti_stack.py:45,57` は
    controller 段。`avoid_stack()` の呼び出し元はこの 1 箇所のみ。`common/` がローカルに
    無く `context.results` の周期クリア有無を確認できないため、「常に None」か「1 周期古い」かは
    未確定 (要 backend-smoke)。
  - **M20 (amcl yaw 相補フィルタ不到達)**: `amcl_estimator.py` は基準線以降**変更なし** → 残存。
  - **M21 (odo 二重書き疑い)**: `building_sensor.py` は変更あり (盲区間・EV 扉関連) だが
    `odo` ゲートの構図は不変 → 残存。
  - **#5 rear_swing コメント / #1〜#4 / #6 #7 / M17**: 関連行に実質差分なし — 残存。

## 捨てた候補と理由

- **`BuildingSensor.contract()` の宣言乖離** (fan-out が「宣言 `pose`/`rplidar` vs 実際の metadata
  キー不一致」として上げた) → **棄却**。本リポの `contract()` は 19 箇所すべてが
  `estimate` / `reference` / `cmd_input` のような**抽象ラベル**で書かれており
  (`tscf_controller.py:65-74`, `building_reference.py:225-233` で確認)、metadata キー名を
  宣言する規約ではない。`pose` = Result.state、`rplidar` = スキャン一式の抽象名として
  他ツールと同じ流儀。→ 指摘ではない。
- **M31 (inf の扱い) の PR 化**: 直す方向が安全側と逆になりうる (上記)。実機データ要 → 要相談。
- **M30 / M27 / M28 の PR 化**: 修正箇所が `rover_main.py` (管理者のみ) → 要相談据え置き。
- **`Nav2PathClient._cancel()` が nav2 ゴールを cancel しない** (`nav2_path_client.py:128-130`):
  タイムアウトのたびに planner 側のゴールが孤児になる。ただし ActionClient 自体は
  `__init__` で 1 回生成でリークなし、planner ゴールは短命で実害が小さく、
  action ライフサイクルの設計判断を含むため見送り (次回候補)。
- **死にコード `_publish_scan_debug` の削除**: 削除系はこの環境で権限が通らない実績があり、
  かつ PR 枠 3 本を実バグ + config 整合に充てた → 軽微記録のみ。
- **`ev_door_watch.py` の sensor カテゴリ汚染**: 仮説として最優先で検証したが、
  **Tool ですらなかった** (上記 柱1) → 指摘なし。設計は CLAUDE.md の推奨どおり。

## メモ (次回向け)

- 次回 ros2-structure の基準線: **rf_rover a0453bab / drone2 3a53ebb** (2026-09-22 origin/main)。
- **drone2 #229/#230/#231 は 09-10 から OPEN のまま動きなし**。次回も未処理なら、
  同一指摘の再掲は避けて「滞留」とだけ記録する (ノイズ抑制)。今回の rf_rover #445/#446/#447 も同様に追跡。
- 次回 PR 候補 (低リスク): `Nav2PathClient` のゴール cancel / `_publish_scan_debug` 削除 /
  `omni_yc_bld7.yaml:42-45` のインデント統一。
- **fan-out の所見は鵜呑みにしない** (今回も 1 件棄却: contract 宣言乖離)。
  逆に fan-out が「0 件」と言った方向も鵜呑み厳禁 — `cabin_turn_margin` は
  「elevator.yaml の全キーに読み手あり = 供給漏れなし」という config→code 方向の走査では
  見つからず、**メインループで code→config 方向 (`ev.get(` の全列挙) をやって初めて出た**。
  **供給漏れは必ず code→config 方向で当てること**。
- 権限実測 (今回の追加分。いずれも原文は
  "Permission to use Bash has been denied because Claude Code is running in don't ask mode"):
  - `git ls-tree` … **deny**。ツリー一覧は `git show <ref>:<dir>/` で代替可
    (存在しないパスは exit 128 で分かる)。
  - `python3 -c "..."` … **deny**。→ **YAML の機械検証ができない**。`python3 -m py_compile` は許可。
  - `git grep -n <pat> <ref> -- <path>` … **許可** (ref 指定の横断検索に有効。今回多用)。
  - `git show <ref>:<file> | grep -n` … 許可 (パイプ可)。
  - `gh pr create --draft --body-file` / `git commit -F` / `git push -u` … 許可 (前回同様)。

> 夜間自動監査 (nightly-audit) が生成。
