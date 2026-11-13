# 2026-11-07 backend-smoke: drone × SIM (pid.yaml) — ruth

## スコープ
- deploy: `/home/sekiguchi/drone` (main e418898、origin/main と一致、working tree clean)
- 起動コマンド: `dup all SIM pid.yaml` (→ `sim/pid.yaml`)
- 事前確認: `docker ps -a` は空 (fleet / px4_hlc の稼働なし)。`ss -ulnp` で 14540/14580 等の衝突なし

## 結果: 再現する起動失敗 (2/2)
`dup` は rc=0 で戻り、コンテナ `drone2` は起動した。ツールチェーンの構築
(sensor/estimator/reference/controller、Console server on port 7720) までは進んだが、
`Drone ready` に到達する前に例外で落ちて `Exited (0)` になった。

```
  File "/root/ros2_ws/build/drone2/drone2/drone_main.py", line 712, in __init__
    self._validate_contracts(agent)
  File "/root/ros2_ws/build/drone2/drone2/drone_main.py", line 728, in _validate_contracts
    from acsl.types.contract import validate_category_contracts
ImportError: cannot import name 'validate_category_contracts' from 'acsl.types.contract' (/root/.venv/lib/python3.12/site-packages/acsl/types/contract.py). Did you mean: 'validate_pipeline_contracts'?
[ros2run]: Process exited with failure 1
```

- 1回目 02:30:35 と 2回目 02:31:13 で、同じ traceback が出た (コンテナを `docker rm -f drone2` で消してから再実行)
- 後始末: `docker rm -f drone2` を実行し、`docker ps -a` が空であることを確認した

## 原因の推定 (確信度: 高)
イメージ内の `acsl` (project_common) が古く、drone2 側のコードとずれている。

- `packages/drone2/drone2/drone_main.py:728` は `validate_category_contracts` を import している。これを導入したのは 53ec864 (2026-05-14) で、長く使われているコード。
- `.acsl/dockerfiles/dockerfile.base_ros_x86:60` (arm 版も同じ) は `pip install git+https://github.com/acsl-tcu/project_common.git@v0.8.0` でタグを固定している。v0.8.0 にはこの API が無い。
- `docs/coop_update_guide.md:63-76` (§1-2) は、まったく同じ ImportError を既知の問題として記載している。対処法は `update_common` (ecosystem のコマンド) でコンテナ内の acsl を入れ直すこと。
- 11-01 の SITL_PX4 smoke では同じ drone_main で `Drone ready` に到達していた。したがって 11-01 から 11-07 の間に `image_drone2_x86` が v0.8.0 ベースで再ビルドされるか、取り直されて、`update_common` の効果が失われた可能性が高い。イメージの作成日時は確認できなかった。`docker image inspect --format ...` と `docker history` は dontAsk で拒否された (拒否メッセージ原文: "Permission to use Bash has been denied because Claude Code is running in don't ask mode.")。

## PR: なし (要相談)
修正先が Dockerfile のバージョン固定、またはホストのイメージ更新のどちらかで、いずれも監査の編集スコープ外。

- CLAUDE.md は「Docker イメージや Dockerfile を変更すること」を禁止している
- `update_common` はホストのイメージや環境を書き換える操作なので、監査では実行しなかった
- drone2 側でフォールバックを入れて import を任意化する修正は `drone_main.py` の変更にあたる (管理者のみ)。53ec864 で意図的に撤去された workaround を戻すことにもなるので、行わない

### 要相談 (管理者へ)
1. ruth で `update_common` (またはイメージ再ビルド後に最新の project_common を入れ直す手順) を実行し、SIM smoke を再実行すること。
2. 根本対策: `dockerfile.base_ros_{x86,arm}` の `project_common@v0.8.0` 固定を、drone2 が必要とする API を含むタグに上げる。または、派生イメージのビルド時に必ず `update_common` 相当を実行する。現状では、イメージを再ビルドするたびにこの退行が再発する。
3. 同じイメージを使う他の drone モード (SITL_PX4 / SITL_GZ_PX4 / SITL_AP / SITL_OMNI) も、現イメージでは同じ箇所で落ちる見込み (未検証)。11-01 の PASS 判定は、現イメージには当てはまらない可能性がある。

## 捨てた候補
- compose の警告 `DF/BASE_IMAGE/USER/XDG_RUNTIME_DIR variable is not set` は、harness 経由の起動では従来から出ている表示で、起動の成否には関係しない
- `XMLPARSER Error realpath failed` (FastDDS のデフォルト XML 不在) は良性で、従来から出ている
- `chmod: cannot access '/root/ros2_ws/launcher/rosbags/*'` はノードの異常終了後に出る後処理のノイズ
- `image drone2_x86 does NOT exists. Use image_drone2_x86` は正常なフォールバック表示

SMOKE_RESULT: FAIL
