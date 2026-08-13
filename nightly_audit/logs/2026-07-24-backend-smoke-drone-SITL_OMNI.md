# Nightly Audit: backend-smoke (drone × SITL_OMNI)

- 実行日: 2026-07-24 / ホスト: ruth
- 対象: deploy=drone (`~/drone`, project drone2) / mode=SITL_OMNI (targets.conf の許可 mode に含まれることを確認)
- 結果: **BLOCKED** — SITL_OMNI の bringup は GUI 手動操作が前提であり、無人監査では検証チェーンを開始できない。

## 事前状態

- `~/drone` は `main` で `origin/main` と一致 (`git status`: "Your branch is up to date with 'origin/main'")。
- 未コミットのユーザー作業変更あり (coop_sl 系 config 7 ファイル + notebook + untracked `launcher/launch_dev.sh` 等)。
  いずれも今回の既定 config `config/omni/sitl.yaml` とは別ファイル。**一切触っていない** (stash もしない)。
- 監査開始時 `docker ps` は空 (ホスト未使用)。

## 実施内容と証拠

1. `dup all SITL_OMNI` を実行 (2 回、結果は同一・決定的):
   ```
   [ERROR] isaac-sim container is not running.
     Isaac Sim は GUI 操作前提のため dup では自動起動できません。
     別端末で先に以下を実行してください:
       1. disaac
       2. ./isaac_sim/run_scene_setup.sh omni/sitl.yaml
       3. Isaac Sim 内で omni_drone_bridge.py を実行
     その後もう一度: dup all SITL_OMNI [config]
   ```
   ガードは `project_launch.sh:354-383` (SITL_OMNI 分岐)。isaac-sim コンテナ未起動なら
   drone2 コンテナを起動する前に exit 1 する設計。**コンテナは 1 つも起動されなかった**
   (`docker ps -a` 空を確認済み、後始末不要)。

2. 前提ステップが無人実行不可能であることをコードで裏取り:
   - `disaac` (`~/drone/.acsl/commands/scripts/disaac:46-64`): `docker run --name isaac-sim -it --gpus all ... runapp.sh` —
     **TTY (-it) + X ディスプレイ (xhost/DISPLAY/.Xauthority) 前提の GUI 起動**。cron/非 TTY からは起動できない。
   - `isaac_sim/run_scene_setup.sh:1-3,113-119`: 生成した scene-setup バンドルは
     **VSCode 拡張 "Isaac Sim VS Code Edition" の Run、または GUI の Script Editor で人が実行**する設計。
   - `project_launch.sh:357-358` 自身が「Isaac Sim は GUI コンテナと GUI 内ブリッジ実行が手動操作前提のため
     dup では全自動化できない」と明記。
   - 独自の headless 起動 (ISAAC_SIM_LAUNCH 上書き等) は標準シーケンスから逸脱し、失敗しても
     基盤の指摘にならないため実施しなかった (安全側)。

3. bringup 到達可否の静的確認 (参考): `Drone ready` ログはノード init 完了時に出る
   (`packages/drone2/drone2/drone_main.py:699-701`、sim clock タイマー登録後・tick 前) ため、
   isaac-sim さえ立っていれば /clock 未 publish でも bringup 判定自体は可能な構造。今回はそこまで到達できず。

## 確証指摘 / PR

なし (PR 0 本)。dup のガード動作は仕様どおりで、再現する起動失敗ではない。

## 要相談 (設計判断が要るためレポートのみ)

1. **SITL_OMNI は無人 backend-smoke と構造的に非互換。** targets.conf の drone `modes` に
   SITL_OMNI が入っているため rotation に載るが、GUI 手動前提のため夜間監査では恒久的に
   BLOCKED になり、昇格台帳の「全許可 mode PASS」条件を満たせなくなる。選択肢:
   (a) SITL_OMNI を smoke rotation から外し手動検証専用と明記する、
   (b) headless bringup 経路を整備する (disaac の headless kit 変種 + code_editor
   エンドポイント :8226 への script push 等)。管理者判断が必要。
2. **ガードメッセージの手順 3 が現行フローとややズレ。** `project_launch.sh:379` は
   「3. Isaac Sim 内で omni_drone_bridge.py を実行」と案内するが、現行の
   `config/omni/sitl.yaml` の `scene_setup_scripts` 末尾 `omni_bringup.py` が bridge を内部で
   exec する (`isaac_sim/scripts/omni_bringup.py:6,26`) ため、手順 2 実行で bridge まで立つ。
   `project_launch.sh` は管理者専用ファイルのため PR にせず報告のみ。

## 権限メモ (driver 0.5 準拠)

- `ls <path>` が deny された。拒否メッセージ原文: "Permission to use Bash has been denied because
  Claude Code is running in don't ask mode." → Read/Grep 系で代替。`git status` / `git log` /
  `docker ps` / `dup` / `grep` は素の 1 コマンドで許可された。

SMOKE_RESULT: BLOCKED
