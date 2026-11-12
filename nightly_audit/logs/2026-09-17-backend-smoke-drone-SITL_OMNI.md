# Nightly Audit: backend-smoke (drone × SITL_OMNI)

- 実行日: 2026-09-17 / ホスト: ruth
- 対象: deploy=drone (`~/drone`, project drone2) / mode=SITL_OMNI (targets.conf の drone `modes` に含まれることを確認)
- 結果: **BLOCKED** — 2026-07-24 と同じ理由。SITL_OMNI の bringup は Isaac Sim GUI コンテナの手動起動と
  GUI 内 scene 構築が前提で、無人監査では検証チェーンを開始できない。状況は 7/24 から変わっていない。

## 事前状態

- `docker ps` / `docker ps -a`: 空 (ホスト未使用。9/15 に衝突した `px4_hlc` 等の host-network コンテナも無し)。
- `ss -ulnp`: 14540/14580 等の PX4/ArduPilot 系 UDP bind 無し。
- `~/drone` は利用者ブランチ `feat/hlc-firmware-c` (HEAD eb6f106、working tree clean)。origin/main は 3a53ebb。
  **checkout は切り替えていない** (稼働 checkout は利用者作業中の可能性があるため)。
  今回の判定対象 `project_launch.sh` は `git diff origin/main -- project_launch.sh` が空 = main と同一内容なので、
  この branch で検証しても main の挙動と等価。

## 実施内容と証拠

1. `dup all SITL_OMNI` を 2 回実行 (結果は同一・決定的)。dup の出力:
   ```
   ========= ACSL: ==========
   DUP 8:  : all : SITL_OMNI
   ==========================
   drone2_x86
   8
   ==================================================================
    [ERROR] isaac-sim container is not running.
      Isaac Sim は GUI 操作前提のため dup では自動起動できません。
      別端末で先に以下を実行してください:
        1. disaac
        2. ./isaac_sim/run_scene_setup.sh omni/sitl.yaml
        3. Isaac Sim 内で omni_drone_bridge.py を実行
      その後もう一度: dup all SITL_OMNI [config]
   ==================================================================
   ```
   ガードは `project_launch.sh:371-383` (SITL_OMNI 分岐)。`docker inspect -f '{{.State.Running}}' isaac-sim` は
   `error: no such object: isaac-sim` (rc=1) で、ガード条件を直接再現。**drone2 コンテナは 1 つも起動されず**
   (`docker ps -a` 空を再確認)。後始末対象なし。

2. 前提ステップが無人実行不可であることを現行コードで再裏取り:
   - `disaac` (`~/drone/.acsl/commands/scripts/disaac:11,48-66`): `xhost +local:` → `docker run --name isaac-sim -it
     --gpus all --rm --network=host ... -e DISPLAY=$DISPLAY -v $HOME/.Xauthority ... runapp.sh`。
     **TTY (-it) + X ディスプレイ前提の GUI 起動**で、cron/非 TTY からは起動できない。
   - `isaac_sim/run_scene_setup.sh:118-124`: 生成バンドルは **VSCode 拡張 "Isaac Sim VS Code Edition: Run"
     か GUI の Script Editor で人が実行**する設計 (変わらず)。
   - `project_launch.sh:357-358` 自身が「GUI コンテナと GUI 内ブリッジ実行が手動操作前提のため dup では
     全自動化できない」と明記。

3. 7/24 以降の変化 (headless 経路の実現性に関わる新情報):
   - main に `isaac_sim/tests/run_sim.sh` (9d5ad1d, 2026-09-09) と `isaac_sim/tests/run_offline.sh` が入り、
     **ホスト側インストール `~/isaacsim/python.sh` で Isaac をヘッドレス起動**するテスト経路がある
     (`--real-bridge` で実物 bridge も回せる)。ruth には `~/isaacsim/python.sh` が実在する (`test -x` rc=0)。
   - ただしこれは coop 鎖の物理検証専用 (`sim_coop_rope.py`) で、`dup all SITL_OMNI` の標準シーケンス
     (isaac-sim **コンテナ** + `omni/sitl.yaml` の scene 構築 + bridge) とは別物。ガードはコンテナ名
     `isaac-sim` の存在を見るため、ホスト側 Isaac をヘッドレスで立てても dup は通らない。
     標準シーケンスから逸脱した独自起動は基盤の指摘にならず、失敗しても切り分け不能なので実施しなかった (安全側)。

## 確証指摘 / PR

なし (PR 0 本)。dup のガード動作は仕様どおりで、再現する起動失敗ではない。

## 要相談 (設計判断が要るためレポートのみ・7/24 と同内容、状況変化なし)

1. **SITL_OMNI は無人 backend-smoke と構造的に非互換。** rotation に載る限り恒久 BLOCKED となり、
   昇格台帳の「全許可 mode PASS」条件を drone は満たせない。選択肢:
   (a) targets.conf の drone `modes` から SITL_OMNI を外し、手動検証専用と明記する (推奨: 即効・安全)。
   (b) headless bringup 経路を整備する。9/9 以降 `~/isaacsim/python.sh` ベースのヘッドレス実行が
       テストで実績があるので、`disaac` の headless 変種 (`-it`/DISPLAY 無し、`--no-window`) +
       scene 構築スクリプトの非 GUI 実行 (code_editor エンドポイントへの push か `python.sh` 直接実行) +
       `project_launch.sh` ガードの緩和、の 3 点が必要。いずれも管理者専用ファイル。
2. **ガードメッセージの手順 3 が現行フローとズレたまま。** `project_launch.sh:379` は「3. Isaac Sim 内で
   omni_drone_bridge.py を実行」と案内するが、`config/omni/sitl.yaml:37-43` の `scene_setup_scripts` 末尾
   `omni_bringup.py` が bridge を内部 exec する (`isaac_sim/scripts/omni_bringup.py:6,26`) ため、手順 2 で
   bridge まで立つ。`project_launch.sh` は管理者専用のため PR にせず報告のみ。

## 権限メモ (driver 0.5 準拠)

- deny された素コマンド: `cat <file>`, `ls <dir>`, `find <dir> -name ...`, `grep -rn ... <acsl_infra 配下>`
  (拒否メッセージ原文: "Permission to use Bash has been denied because Claude Code is running in don't ask mode.")。
  いずれも Read ツール等で代替した。
- 許可された素コマンド: `git status` / `git log` / `git diff` / `git show` / `docker ps` / `docker images` /
  `docker inspect` / `dup` / `ss -ulnp` / `which` / `test -x` / `grep` (drone 配下)。

SMOKE_RESULT: BLOCKED
