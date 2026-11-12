# Nightly Audit — 2026-09-20 — image-refresh (ホスト: ruth)

## 結果サマリ
**成功。`kasekiguchi/acsl-common:jazzy_x86` を上流から `--no-cache` で再ビルドし、検証を通して
Hub へ push、dangling を prune した。** 前回 (09-09) に続き 2 run 連続で deny ゼロの全通し。
今回は上流 `ros:jazzy` の digest 自体も更新されていた (08-18 ビルド版 → 新版)。
PR なし (このテーマは PR を作らない)。

## テーマ必須記載項目

| 項目 | 値 |
|------|----|
| 旧 IMAGE ID / CREATED | `dabf4202bbf0` / 2026-09-09 02:37 JST (7.67GB) |
| 新 IMAGE ID / CREATED | `d0c4ef08f81d` / **2026-09-20 02:40 JST** (7.51GB) |
| `ros:jazzy` digest | **更新あり** — 旧 `sha256:2589a8fba5257307857890173c069852c2abf913a0be7970f172478baecb09e4` (2026-08-18 作成) → 新 `sha256:c3706ef0a0aa45413c07803cf433602f543b22e45b4855f6fca955c2d8ecc4e8` (`Status: Downloaded newer image`) |
| 検証 (ros2 pkg 数) | **345** (基準 300 以上 → PASS。prune 後に再実行しても 345) |
| push | **成功** — `jazzy_x86: digest: sha256:d0c4ef08f81dd95d7facd7c837b50adec1398887401f55ad980db464f6bba510 size: 4016` |
| prune 回収容量 | **17.87GB** (`docker image prune -f`、dangling のみ) |
| ディスク | 実行前 空き 849GB → 実行後 858GB (閾値 40GB を大幅クリア) |
| 派生イメージ | **派生再ビルドは harness が実施 (run.log 参照)** |

## 実施内容と記録

### 1. 事前チェック — PASS
- `df -h /`: 空き 849GB (使用 602G / 1.5T)。
- `docker images kasekiguchi/acsl-common:jazzy_x86`: `dabf4202bbf0`。
  新形式の `docker images` 出力に CREATED 欄が無いため `docker inspect --format '{{.Id}} {{.Created}}'`
  で取得: `2026-09-09T02:37:07+09:00` (前回 run のビルド)。

### 2. 上流更新 — digest 更新あり
- pull 前の `ros:jazzy`: `2589a8fb…` (Created 2026-08-18T20:24 UTC)。
- `docker pull ros:jazzy` → `Status: Downloaded newer image for ros:jazzy`、
  `Digest: sha256:c3706ef0…`。前回 09-09 は up to date だったので、09-09 以降に上流が更新された。

### 3. 再ビルド — 成功
- 実行コマンド (harness 注入の絶対パス版を一字一句そのまま):
  ```
  dbuild ros:jazzy jazzy /home/sekiguchi/GitHub/sb/acsl_infra/dockerfiles/dockerfile.base_ros_x86 --no-cache
  ```
- 02:30:49 開始 → 02:40:29 完了 (**約 9.7 分**。前回 6.5 分よりやや長いが、ベース層が
  新規 pull 分で全て再展開されたため)。
- 全 13 Step が `Running in <container>` で実行されておりキャッシュ再利用なし (ログ確認済み)。
- apt 集計: Step 3 `3 upgraded, 1329 newly installed`、Step 5 `33 newly installed`、
  Step 6 (`apt upgrade`) `8 upgraded, 0 to remove and 0 not upgraded` → 上流ベースに残っていた
  8 パッケージの保留更新を取り込んだ。
- 末尾: `Successfully built d0c4ef08f81d` / `Successfully tagged kasekiguchi/acsl-common:jazzy_x86`。
- project_common は `v0.8.0` (commit `78200242`) が pip install された (前回と同一)。
- ログ中の `^E:` / `ERROR:` / `non-zero code` は **ゼロ**。
- 副次的な警告 (前回と同一、ビルド結果には無関係、要相談 2 参照):
  compose の `PROJECT` / `ROS_DOMAIN_ID` / `USER` / `ACSL_WORK_DIR` / `x86` / `DISPLAY` /
  `XDG_RUNTIME_DIR` 未設定警告、`[Warning] One or more build-args [BASE_IMAGE] were not consumed`。

### 4. 検証 — PASS
- `docker images …:jazzy_x86` → ID `d0c4ef08f81d`。`docker inspect` で Created
  `2026-09-20T02:40:29+09:00` (今日)。
- `docker run --rm … "source /opt/ros/jazzy/setup.bash && ros2 pkg list | wc -l"` → **345**。

### 5. push — 成功
- `dpush jazzy_x86`: 保存済み credential で `Login Succeeded`、ベース層は `Mounted from library/ros`、
  独自層 8 本を Pushed。digest は上表のとおり (containerd store のため IMAGE ID と一致)。
- push 後 `docker inspect --format '{{.RepoDigests}}'` →
  `kasekiguchi/acsl-common@sha256:d0c4ef08f81d…` を確認。

### 6. 後始末 — 完了
- `docker image prune -f` → `Total reclaimed space: 17.87GB`。
  前回 (3.9GB) より大きいのは、旧タグ `dabf4202bbf0` に加え、旧 `ros:jazzy` (`2589a8fb…`、
  新 pull で untagged 化) と、09-09 以降に harness の派生連鎖 / backend-smoke が残した
  classic builder 中間イメージ (約 70 件) が dangling として溜まっていたため。
- prune 後に `docker run` で pkg 345 を再確認 → 稼働イメージへの影響なし。
- 稼働中コンテナには一切触れていない (stop/rm/restart なし)。

## 権限メモ (次回以降の参考)
今夜 deny されたコマンドは **ゼロ**。以下すべて素の 1 コマンドで許可された:
`df -h /` / `docker images …` / `docker inspect --format '…' <image>` / `docker pull ros:jazzy` /
`dbuild …` (絶対パス) / `docker run --rm … bash -c "…"` / `dpush jazzy_x86` /
`docker image prune -f` / `tail -c N <file>` / `grep -nE '…' <file>` / `ls <dir>`。
新形式 docker CLI では `docker images` に CREATED 欄が無い → `docker inspect --format` で代替
(次回もこの形で取る)。

deny されたのは事後の任意確認 1 件のみ (テーマ手順外・結果に影響なし):
`docker events --since 30m --until 1s --filter event=kill` → 拒否原文:
「Permission to use Bash has been denied because Claude Code is running in don't ask mode.」
今夜は rc=137 が発生していないので本来不要な確認だった。rc=137 が出た晩に必要になるため、
allow に `Bash(docker events *)` を足すかは harness 管理者判断 (要相談 4)。

push 後の `docker images kasekiguchi/acsl-common` で他 15 タグ (image_*, mavros2_x86, isaac-sim6-jazzy_x86,
px4_sitl_x86 等) は ID 不変・残存を確認。変更したのは `jazzy_x86` のみ。

## 要相談
1. **[定常記載] arm 版 `jazzy` (無印) は arm ホストでの同運用が未整備** (このホスト x86 では
   ビルド不可。arm ホストに運用が入ったらこの記載を落とす)。
2. **[低優先・情報・継続] `dbuild` 実行時の compose 変数未設定警告と `BASE_IMAGE` build-arg 未消費警告。**
   09-09 と同一。ビルド結果には影響なし。harness の export セットに含めるか、
   dockerfile.base_ros_x86 の `ARG BASE_IMAGE` 不使用を整理するかは infra 管理者判断
   (テーマ方針により Dockerfile / compose は触っていない)。
3. **[情報・継続] `2026-09-01-image-refresh.run.log` (ヘッダのみ・`.md` 無し) が残存。**
   09-09 レポートで指摘済み。不要なら削除を検討 (監査からはファイル削除を行わない)。
4. **[低優先] `docker events …` が allow に無い。** テーマ仕様は rc=137 時に
   `docker events --since 30m --until 1s` で kill イベント確認を求めるが、現状 deny される
   (拒否原文は権限メモ参照)。読み取り専用コマンドなので `Bash(docker events *)` を allow に
   加えることを提案。

## 捨てた候補
なし (このテーマは指摘型ではなく運用型)。

## PR
なし (このテーマは PR を作らない。成果物 = Hub タグ `jazzy_x86` の更新 `d0c4ef08f81d`)。
