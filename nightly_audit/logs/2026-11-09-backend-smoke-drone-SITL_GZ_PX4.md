# 2026-11-09 backend-smoke: drone × SITL_GZ_PX4 (host: ruth)

## 範囲
- deploy: `/home/sekiguchi/drone` (main @ e418898, clean, origin/main と一致)
- 起動コマンド: `dup all SITL_GZ_PX4 sitl_gazebo.yaml` を2回 (各回のあと `docker rm -f drone2 mavros2 px4_sitl` で片付け)
- 事前確認: `docker ps -a` は空 (fleet / px4_hlc の稼働なし)。`ss -ulnp` で 14540/14580 の衝突なし
- 使用イメージ: `image_drone2_x86` (71ed265e90d2, 2026-11-03 作成) / `mavros2_x86` (49cf96fd151d) / `px4_sitl_x86` (e7f6dee4e7e1)

## 結果: FAIL (2/2 で再現)
2回とも `drone2` が起動直後に traceback で終了した (`Exited (0)`)。`Drone ready` には到達しなかった。

```
  File "/root/ros2_ws/build/drone2/drone2/drone_main.py", line 712, in __init__
    self._validate_contracts(agent)
  File "/root/ros2_ws/build/drone2/drone2/drone_main.py", line 728, in _validate_contracts
    from acsl.types.contract import validate_category_contracts
ImportError: cannot import name 'validate_category_contracts' from 'acsl.types.contract' (/root/.venv/lib/python3.12/site-packages/acsl/types/contract.py). Did you mean: 'validate_pipeline_contracts'?
[ros2run]: Process exited with failure 1
```

traceback に至るまでは正常だった: config 読込 → required_sensors (mavros_state / mavros_odom) の readiness 登録 → ツールチェーン構築 → Console server 7720 → MavrosActuator warmup。
- px4_sitl: `Ready for takeoff!` に到達した。`Preflight Fail: Yaw estimate error` の WARN は出たが、PX4 SITL の通常の範囲。
- mavros2: `Got HEARTBEAT` を受信し、mission/rallypoint/geofence も受信した。正常。

### 原因 (既知・11/7 SIM, 11/8 SITL_PX4 と同じ)
`.acsl/dockerfiles/dockerfile.base_ros_x86:60` が `project_common.git@v0.8.0` に固定されている。11/03 に再ビルドされた `image_drone2_x86` には古い acsl が入っている。その acsl に、`drone_main.py:728` が要求する `validate_category_contracts` が無い。
- 3晩連続・3モードで同じ症状。モードには依存しない。drone2 側のコードは原因ではない。
- 修正には Dockerfile (base の pin 引き上げ) か、ホスト上の `update_common` + イメージ再ビルドが必要。どちらも監査の編集スコープ外 (dockerfiles / common)。そのため **PR は作成していない**。

## 確証指摘 / PR
- 指摘: 上記 ImportError (2/2 で再現、ログ付き)
- PR: なし (修正がスコープ外のため)

## 要相談
1. **【最優先】acsl v0.8.0 pin の退行**: drone のすべての smoke モードが Ready 前に落ちる。管理者に次のどちらかを依頼したい。
   - (a) `dockerfile.base_ros_{x86,arm}:60` の pin を `validate_category_contracts` を含むタグへ引き上げる
   - (b) `update_common` を実施する
   いずれかが済むまで、drone の smoke はすべて FAIL が続く見込み。
2. **project_launch.sh が誤った `[READY] ARM-READY` を表示する**: drone2 が traceback で死んでいても `[READY] SITL_GZ_PX4 ARM-READY -- PX4 preflight passed.` を表示する。判定材料が px4_sitl の `Ready for takeoff!` だけだから。直前の `drone2 warmup status unclear after 35s; continuing` も、drone2 の死亡を見逃している。READY 表示の前に、drone2 コンテナが生存しているかの確認を足すべき。project_launch.sh はデプロイインフラなので要相談。
3. (既知・継続) 14540 待ちで 90 秒を空費: 2回とも `WARNING: UDP 14540 not listening in px4_sitl after 90s` が出た。memory の既知事項 (PX4 は 14580 を bind) と一致する。

## 捨てた候補
- `XMLPARSER Error realpath failed` (FastDDS のデフォルト XML 不在): 毎回出るが良性のため除外。
- `chmod: cannot access .../rosbags/*`: drone2 異常終了後の後処理で出る派生症状のため除外。
- compose の `DF/BASE_IMAGE/USER/XDG_RUNTIME_DIR not set` WARN: 既存の表示で、起動には影響しないため除外。

## 権限メモ
`source .acsl/bashrc && dup ...` (リダイレクトあり/なしとも)、`docker run --rm ... pip show acsl`、`ls <acsl_infra path>` は拒否された。拒否メッセージ原文: "Permission to use Bash has been denied because Claude Code is running in don't ask mode."
`cd /home/sekiguchi/drone` を単独で実行したあと、素の `dup all SITL_GZ_PX4 sitl_gazebo.yaml` は許可された。dup はログインシェルの PATH 上にあり、bashrc の source は不要だった。

## 後始末
`docker rm -f drone2 mavros2 px4_sitl` を実行し、`docker ps -a` が空になったことを確認した。

SMOKE_RESULT: FAIL
