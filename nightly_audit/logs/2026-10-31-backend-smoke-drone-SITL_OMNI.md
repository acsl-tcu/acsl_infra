# 2026-10-31 backend-smoke: drone × SITL_OMNI (ホスト: ruth)

## 対象
- deploy: `~/drone` (HEAD `12e8ce4` = origin/main, PR #250 マージ後)、ワークツリーはクリーン
- mode: `SITL_OMNI` のみ (他の backend/mode は回していない)

## 事前確認
- `docker ps`: 稼働中コンテナなし (fleet / px4_hlc などとの衝突なし)
- `docker inspect -f '{{.State.Running}}' isaac-sim` → `error: no such object: isaac-sim`

## 実施内容
`dup all SITL_OMNI` を素のコマンドで 2 回実行した。結果は 2 回とも同じ:

```
DUP 8:  : all : SITL_OMNI
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

- ガードは `project_launch.sh:354-383` の SITL_OMNI 分岐 (isaac-sim コンテナの存在チェックで exit 1)。
  前回 (2026-09-17) から変わっていない。
- drone2 コンテナは起動しない → `Drone ready` まで進む経路がない。
- 実行後の `docker ps -a` も空。片付けるコンテナはない。

(補足: `bash -c '... source .acsl/bashrc && dup ...'` と単独の `source .acsl/bashrc` は
dontAsk モードで拒否された。拒否メッセージは "Permission to use Bash has been denied because
Claude Code is running in don't ask mode."。素の `dup all SITL_OMNI` は許可され、PATH 上で
解決できた。)

## 判定
- 構造的に BLOCKED。前提の Isaac Sim (`disaac` = `docker run -it` と X GUI、scene 構築は人手の
  GUI 操作) を無人で用意できない。2026-07-24 / 09-17 に続いて 3 回目の同じ結果。
- 確証のある指摘: なし。PR: なし。
- 実機安全: EXP 系は起動していない。console 操作や駆動指令も送っていない。

## 要相談 (継続・未解決)
1. SITL_OMNI を rotation.txt / targets.conf の modes から外すか (推奨)。headless の bringup 経路
   (`disaac` の headless 版 + scene 構築を GUI なしで実行 + ガードの緩和) を整備するか。
   このまま毎回 BLOCKED が続くと、drone deploy の「全許可 mode PASS」による昇格が恒久的に止まる。
   素材として、ホストの `~/isaacsim/python.sh` を使う `isaac_sim/tests/run_sim.sh` がある (coop 検証用)。
2. ガードのメッセージにある「手順3: bridge を手動実行」は古い (scene_setup の末尾にある
   omni_bringup.py が bridge を自動で exec する)。`project_launch.sh` は管理者専用なので修正していない。

SMOKE_RESULT: BLOCKED
