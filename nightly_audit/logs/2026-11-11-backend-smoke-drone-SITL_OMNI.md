# 2026-11-11 backend-smoke: drone × SITL_OMNI (host: ruth)

## 対象
- deploy: drone (`/home/sekiguchi/drone`, main @ e418898 #255)
- mode / config: `dup all SITL_OMNI sitl.yaml` (omni/sitl.yaml)

## 事前確認
- `docker ps -a`: 空 (fleet / px4_hlc など利用者のコンテナとは衝突しない)
- `ss -ulnp`: PX4/MAVLink 系のポート (14540/14580 等) は使われていない
- `docker inspect -f '{{.State.Running}}' isaac-sim` → `error: no such object: isaac-sim`

## 実行結果 (2 回とも同じ結果)
`dup all SITL_OMNI sitl.yaml` を 2 回実行した。2 回とも `project_launch.sh:390` の SITL_OMNI ガードで終了した。
```
 [ERROR] isaac-sim container is not running.
   Isaac Sim は GUI 操作前提のため dup では自動起動できません。
   別端末で先に以下を実行してください:
     1. disaac
     2. ./isaac_sim/run_scene_setup.sh omni/sitl.yaml
     3. Isaac Sim 内で omni_drone_bridge.py を実行
```
- drone2 コンテナは起動しなかった。そのため `Drone ready` の判定は行っていない。
- 後始末: 起動したコンテナは無い (`docker ps -a` が空であることを確認済み)。

## 判定
過去 4 回 (07-24 / 09-17 / 10-31 / 今回) と同じく、構造的な理由で BLOCKED。
SITL_OMNI は Isaac Sim の GUI を人が起動し、scene 構築も人が実行する前提になっている。そのため無人の夜間監査では前提条件を満たせない。
これはコードの不具合ではないので、PR は作成していない。標準手順から外れる独自の headless 起動も行っていない。

## 確証指摘 / PR
- なし

## 要相談 (継続)
1. **SITL_OMNI の扱い**: rotation と targets.conf の `modes` から外すことを推奨する。外さない場合は、headless で bringup できる経路を整備する必要がある (disaac の headless 変種、scene 構築の非 GUI 実行、ガードの緩和)。ruth には `~/isaacsim/python.sh` があり、`isaac_sim/tests/run_sim.sh` は headless 起動の素材になる。このままだと、昇格台帳の「全許可 mode PASS」条件を SITL_OMNI が恒久的にブロックする。
2. **ガードメッセージが古い**: 手順 3「Isaac Sim 内で omni_drone_bridge.py を実行」は、実際には scene_setup 末尾の `omni_bringup.py` が自動で exec している。`project_launch.sh` は管理者専用のファイルなので修正していない。
3. **参考**: 11-07〜11-10 の SIM / SITL_PX4 / SITL_GZ_PX4 / SITL_AP は、いずれも acsl v0.8.0 退行による ImportError (`validate_category_contracts`) で FAIL している。Isaac Sim を用意して SITL_OMNI を起動できたとしても、drone2 は同じ ImportError で落ちる可能性が高い (今回は drone2 が起動していないため未確認)。`update_common` の実行、または base Dockerfile の v0.8.0 固定の引き上げが必要。

SMOKE_RESULT: BLOCKED
