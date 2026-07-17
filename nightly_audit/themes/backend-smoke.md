# テーマ: backend-smoke (バックエンド1つを現バージョンで実起動検証)

> ローテ粒度=★1 backend=1晩で確定 (harness が deploy×mode を注入)。修正スコープ (下の TODO) は
> まだ壁打ち中。Docker/GPU/ROS2 が要るので稼働 checkout がある環境限定 (実 `dup` 起動が必要)。
> drone-SIM で初回試走済み (2026-06): bringup→"Drone ready"→teardown まで通った。下記の
> 「実行手順」「指摘条件」はその試走の実ログを反映した実戦版。

## ★ 安全境界 (driver.md の実機安全則を厳守)
**実機に触れない。アクチュエーションを伴う一切をしない。**
- 動かすのは targets.conf の `modes` にある **SIM / SITL のみ**。EXP 系は回さない。
- HITL は受動検証 (bringup・トピック publish 確認) まで。arm/takeoff/モーター/cmd 送出は禁止。
- 検証は「立ち上がるか」「トピックが出るか」まで。**機体を動かすコンソール操作はしない**。

## 対象 (targets.conf の deploy 行)
- `~/rover` (project rf_rover) / `~/drone` (project drone2)。実起動・修正・PR はこの稼働
  checkout で行う (実際に再現できる場所で直す)。+ 共有基盤 acsl_infra のコマンド/イメージ。

## ★1 backend = 1晩 (deploy ごとではなく backend ごと)
複数 backend を一度に回すと重い & 切り分け困難。**その晩は1 deploy×1 mode (=1 backend) だけ**動かす。
- **粒度は backend 単位**。deploy 単位ではない。drone と rover が両方 `isaacsim` を持てば、
  `backend-smoke-drone-isaacsim` と `backend-smoke-rover-isaacsim` で**別々の2晩**になる。
- **今夜の対象 (deploy と mode) は harness が決めてこの仕様の下に注入する**。
  自分で別の backend を選ばない。注入された1つだけを検証する。
- ローテーションは `rotation.txt` が `backend-smoke-<deploy>-<mode>` を1行=1晩で列挙して決める。
  許可 mode は targets.conf の `modes` 由来 (安全なものだけ)。harness が許可外 (EXP 等) を実行前に弾く:
  - rover: `SIM` / `isaacsim`
  - drone: `SIM` / `SITL_PX4` / `SITL_GZ_PX4` / `SITL_AP` / `SITL_OMNI`

## 実行手順 (試走で確立・このとおり叩く)
稼働 checkout で ecosystem を source してから `dup`。注入された deploy/mode を使う。
```bash
cd ~/<deploy> && source .acsl/bashrc        # dup/dps/dlogs/drm を PATH に入れる
dup all <MODE> > /tmp/smoke.log 2>&1         # ★ -d で detached。rc=0 で即返る (= 起動成功とは限らない)
# ↓ 起動の実判定は「コンテナのログ」を見る。CONTAINER 名は dps で確認 (drone は "drone2" 等)
docker logs --tail 100 <container>           # ★ dlogs は使わない (follow で固まる → 監査停止)
```
- [ ] `dup all <MODE>` がコンテナを起動するか (`docker ps` に出る)
- [ ] コンテナログにツールチェーン構築と **`... drone_node]: Drone ready: ... backend=<...>`**
      (rover は対応する ready ログ) が出て、**Python traceback / 例外が無い**か
- [ ] (任意・受動) 期待トピックが publish されるか: コンテナ内 `din <c>` から `ros2 topic list/hz`
- [ ] 依存バージョン更新 (ROS2 distro / base image / Python pin) で壊れた箇所

### ★ 運用の落とし穴 (試走で判明)
- **`dlogs` / `docker logs -f` は follow するので使わない** — 監査が固まる (試走で 2 分タイムアウト)。
  必ず非 follow の **`docker logs --tail N <container>`** でスナップショットを取る。
- `dup all <MODE>` は `-d` で detached 起動 = **rc=0 でも中で例外死している可能性**がある。
  判定は必ずコンテナログで行う。`dup` の rc だけで成功と判断しない。
- イメージ名: ログに `image drone2_x86 does NOT exists. Use image_drone2_x86` と出るが、これは
  harness の正常なフォールバック表示 (`image_<tag>` を使う)。**これ自体は指摘ではない**。

## 「指摘」とみなす条件
- **再現するビルド/起動失敗** = コンテナ起動せず / ログに traceback / `Ready` ログに到達しない /
  期待トピック未 publish 等の明確な機能欠落。**コンテナログを添える**。
- 環境依存のフレーク (1回失敗) は指摘にしない。**最低2回再現**を確認する。
- `Contract: <tool> missing=[...] / mismatched=[...]` の **WARN** は注意して扱う:
  試走では `saturation missing=['cascade.state']` が出たが node は `Drone ready` に到達した
  (cascade 入力は実行時に揃う init 時チェックの可能性大 = 多くは良性)。**自動修正しない**。
  契約宣言は `@tool_contract`/`common` 側に絡むので **要相談**で残し、ros2-structure 柱3 と突き合わせる。

## 自動修正してよい範囲 (要・壁打ち)
- <TODO: バージョン pin の追従・明白な設定漏れまで。設計に踏み込む修正は要相談>
- 安全境界は上の「★ 安全境界」が絶対則。EXP 系は対象外、HITL は受動検証のみ。
  実駆動につながる検証・修正は行わず、必要ならレポートに「要相談」で残す。

## レポート必須: 機械可読の結果行 (正式イメージ昇格の台帳に使う)
レポート (`logs/<date>-<theme>.md`) の**最終行**に、次のいずれかを**単独行**で必ず書く:
- `SMOKE_RESULT: PASS`    … bringup 検証を完遂し、再現する起動失敗が無かった (要相談どまりは可)
- `SMOKE_RESULT: FAIL`    … 再現する起動失敗があった (指摘として記載したもの)
- `SMOKE_RESULT: BLOCKED` … ホスト使用中・環境ギャップ等で検証自体を実施できなかった
harness がこの行を読んで昇格台帳 (`state/`) を更新し、deploy の全許可 mode が
現 base 由来で PASS すると派生イメージ群が dpush = 正式イメージになる。
**迷ったら PASS にしない** (誤 PASS は壊れた正式イメージの配布につながる)。

## 検証方法
- 失敗 → 修正 → **同じ `dup` シーケンスで 2 回**通ることを確認してから draft PR。
- 後始末 (必須): 起動したコンテナを**片付けてから終了**する。試走では `docker rm -f <container>`
  で対象だけ surgical に削除し `docker ps` が空になるのを確認した。`drm all` は他用途の
  コンテナも消すので、対象が1つと分かっているなら名前指定の `docker rm -f` を優先する。
