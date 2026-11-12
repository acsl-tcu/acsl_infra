# Nightly Audit — 2026-09-09 — image-refresh (ホスト: ruth)

## 結果サマリ
**成功。`kasekiguchi/acsl-common:jazzy_x86` を上流から `--no-cache` で再ビルドし、検証を通して
Hub へ push、dangling を prune した。** 07-16 以降 7 run 連続で deny されていたビルド手順が、
harness 注入の絶対パス展開コマンドで初めて全通しした (deny ゼロ)。旧タグは 07-17 ビルドで
約 8 週間のスキューがあったが、今回で解消。PR なし (このテーマは PR を作らない)。

## テーマ必須記載項目

| 項目 | 値 |
|------|----|
| 旧 IMAGE ID / CREATED | `04cd06a81929` / 2026-07-17 10:30 JST (7.54GB) |
| 新 IMAGE ID / CREATED | `dabf4202bbf0` / **2026-09-09 02:37 JST** (7.67GB) |
| `ros:jazzy` digest | `sha256:2589a8fba5257307857890173c069852c2abf913a0be7970f172478baecb09e4` — **更新なし** (Image is up to date、08-29 と同一) |
| 検証 (ros2 pkg 数) | **345** (基準 300 以上 → PASS。prune 後に再実行しても 345) |
| push | **成功** — `jazzy_x86: digest: sha256:dabf4202bbf08cae8fa9798ae28dcfdd5a1b990276c9c5479ee4c13a87942c44 size: 4016` |
| prune 回収容量 | **3.888GB** (`docker image prune -f`、dangling のみ) |
| ディスク | 実行前 空き 920GB → 実行後 918GB (閾値 40GB を大幅クリア) |
| 派生イメージ | **派生再ビルドは harness が実施 (run.log 参照)** |

## 実施内容と記録

### 1. 事前チェック — PASS
- `df -h /`: 空き 920GB。
- `docker images kasekiguchi/acsl-common:jazzy_x86`: `04cd06a81929`、CREATED 2026-07-17 10:30:00 JST。

### 2. 上流更新 — digest 変化なし
- `docker pull ros:jazzy` → `Status: Image is up to date`。digest `2589a8fb…` は 08-29 記録と同一。
- テーマ仕様どおり digest 不変でも apt レベル更新の取り込みのため再ビルドを続行。

### 3. 再ビルド — 成功
- 実行コマンド (harness 注入の絶対パス版を一字一句そのまま):
  ```
  dbuild ros:jazzy jazzy /home/sekiguchi/GitHub/sb/acsl_infra/dockerfiles/dockerfile.base_ros_x86 --no-cache
  ```
- 02:30:42 開始 → 02:37:07 完了 (**約 6.5 分**。想定 30〜60 分より大幅に短い。apt ミラー・
  pip が高速だったため。ログ上は全 13 Step が `Running in <container>` で実行されており
  キャッシュ再利用ではない)。
- 末尾: `Successfully built dabf4202bbf0` / `Successfully tagged kasekiguchi/acsl-common:jazzy_x86`。
- project_common は `v0.8.0` (commit `78200242`) が pip install された。
- 副次的な警告 (ビルド結果には無関係、要相談 2 参照):
  - compose の `PROJECT` / `ROS_DOMAIN_ID` / `USER` / `ACSL_WORK_DIR` / `x86` / `DISPLAY` /
    `XDG_RUNTIME_DIR` 未設定警告 (cron 環境のため。ブランク既定で続行)。
  - `[Warning] One or more build-args [BASE_IMAGE] were not consumed`。

### 4. 検証 — PASS
- `docker images …:jazzy_x86` → ID `dabf4202bbf0`、CREATED 2026-09-09 02:37:07 (今日)。
- `docker run --rm … "source /opt/ros/jazzy/setup.bash && ros2 pkg list | wc -l"` → **345**。

### 5. push — 成功
- `dpush jazzy_x86`: 保存済み credential で `Login Succeeded`、ベース層は `Mounted from library/ros`、
  独自層 8 本を Pushed。digest は上表のとおり (containerd store のため IMAGE ID と一致)。

### 6. 後始末 — 完了
- `docker image prune -f` → `Total reclaimed space: 3.888GB`。
  旧タグ `04cd06a81929` (dangling 化) と classic builder の中間イメージ (`571116ac5cc3` /
  `089f48631e06` 等) が対象。prune 後に `docker images` で新タグの ID/digest 不変、
  `docker run` で pkg 345 を再確認 → 稼働イメージへの影響なし。
- 稼働中コンテナには一切触れていない (stop/rm/restart なし)。

## 権限メモ (次回以降の参考)
今夜 deny されたコマンドは **ゼロ**。以下すべて素の 1 コマンドで許可された:
`df -h /` / `docker images … --format` / `docker pull ros:jazzy` / `dbuild …` (絶対パス) /
`docker run --rm … bash -c "…"` (引用符内のパイプは可) / `dpush jazzy_x86` /
`docker image prune -f` / `tail -n 40 <file>` / `ls <dir>`。
07-16〜08-29 の 6 run 空振りの真因は `$ACSL_ROS2_DIR` 入りコマンド文字列 (permission 不一致) で
確定 (08-29 レポートの「headless で docker build をさせない意図」という推測は誤り)。

## 要相談
1. **[定常記載] arm 版 `jazzy` (無印) は arm ホストでの同運用が未整備** (このホスト x86 では
   ビルド不可。arm ホストに運用が入ったらこの記載を落とす)。
2. **[低優先・情報] `dbuild` 実行時の compose 変数未設定警告と `BASE_IMAGE` build-arg 未消費警告。**
   ビルド結果には影響していないが、cron 環境で `ACSL_WORK_DIR` 等が export されていないため
   compose が空文字で解決している。harness の export セットに含めるか、dockerfile.base_ros_x86 の
   `ARG BASE_IMAGE` 不使用を整理するかは infra 管理者判断 (テーマ方針により Dockerfile / compose
   は触っていない)。
3. **[情報] `2026-09-01-image-refresh.run.log` がヘッダ 1 行のみで `.md` レポートも無い。**
   同日は branch-cleanup が正規テーマで走っており、image-refresh 側は手動テスト起動の残骸と思われる。
   不要なら削除を検討 (監査からはファイル削除を行わない)。

## 捨てた候補
なし (このテーマは指摘型ではなく運用型)。

## PR
なし (このテーマは PR を作らない。成果物 = Hub タグ `jazzy_x86` の更新 `dabf4202bbf0`)。
