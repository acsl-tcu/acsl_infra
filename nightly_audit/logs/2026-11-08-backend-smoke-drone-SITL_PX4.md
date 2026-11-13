# 2026-11-08 backend-smoke: drone × SITL_PX4 (sitl_quadsim.yaml) — ruth

## スコープ
- deploy: `/home/sekiguchi/drone` (main e418898、working tree clean)
- 起動コマンド: `dup all SITL_PX4 sitl_quadsim.yaml` (→ `px4/sitl_quadsim.yaml`)
- 事前確認: `docker ps` は空 (fleet / px4_hlc の稼働なし)。`ss -ulnp` で 14540/14580/8888 等の衝突なし
- 安全: SITL のみ。console 操作 (arm 等) は一切送っていない

## 結果: 再現する起動失敗 (2/2)
`dup` はコンテナ `quadrotor_sim` と `drone2` を起動した (イメージはどちらも `image_drone2_x86`)。

- `quadrotor_sim`: `QuadrotorSim ready: dt=0.005, hz=200` に到達し、正常に動作した
- `drone2`: ツールチェーンの構築 (px4_sensor / direct / HoverReference / pid_controller -> saturation、Console server on port 7720) までは進んだ。しかし `Drone ready` に到達する前に例外で落ち、`Exited (0)` になった

```
  File "/root/ros2_ws/build/drone2/drone2/drone_main.py", line 712, in __init__
    self._validate_contracts(agent)
  File "/root/ros2_ws/build/drone2/drone2/drone_main.py", line 728, in _validate_contracts
    from acsl.types.contract import validate_category_contracts
ImportError: cannot import name 'validate_category_contracts' from 'acsl.types.contract' (/root/.venv/lib/python3.12/site-packages/acsl/types/contract.py). Did you mean: 'validate_pipeline_contracts'?
[ros2run]: Process exited with failure 1
```

- 1回目 (02:30:35) と2回目 (02:30:44) の traceback は同一だった。2回目の前に `docker rm -f drone2 quadrotor_sim` で両コンテナを削除している
- 後始末として `docker rm -f drone2 quadrotor_sim` を実行し、`docker ps -a` が空であることを確認した

## 原因 (確信度: 高。2026-11-07 SIM smoke の FAIL と同一)
イメージ `image_drone2_x86` に入っている `acsl` (project_common) が v0.8.0 に退行している。

- `.acsl/dockerfiles/dockerfile.base_ros_x86:60` が `project_common.git@v0.8.0` に固定されている。v0.8.0 には `validate_category_contracts` が存在しない
- 11-07 のレポートで予告していた「他の drone モードも同じ箇所で落ちる見込み」が、SITL_PX4 で実際に確認された。backend に依存しない問題で、`drone_main` の初期化時点で落ちる
- 11-07 以降、`update_common` もイメージの更新も実施されていない

## PR: なし (要相談。11-07 から継続)
修正先は Dockerfile のバージョン固定か、ホスト上のイメージ更新になる。どちらも監査の編集スコープ外。
`drone_main.py` に import のフォールバックを入れる案も、管理者専用ファイルの変更になるため行わない。

### 要相談 (管理者へ)
1. ruth で `update_common` (または同等の acsl 入れ直し) を実行し、smoke を再実行すること
2. 根本対策: `dockerfile.base_ros_{x86,arm}` の `@v0.8.0` 固定を引き上げる。または、派生イメージのビルド時に最新の acsl を入れ直す
3. 現イメージでは、drone のどのモードも PASS しない見込みが高い。イメージを修正するまでは drone の backend-smoke を回しても同じ FAIL が出るだけになる。ローテーションを一時停止することも検討してほしい

## 捨てた候補
- compose の `DF/BASE_IMAGE/USER/XDG_RUNTIME_DIR variable is not set` 警告、FastDDS の `XMLPARSER Error realpath failed`、`chmod: ... rosbags/*`、`image ... does NOT exists. Use image_drone2_x86` は、いずれも従来から出ている良性の表示

SMOKE_RESULT: FAIL
