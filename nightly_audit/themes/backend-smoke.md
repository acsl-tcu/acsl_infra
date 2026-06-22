# テーマ: backend-smoke (バックエンド1つを現バージョンで実起動検証)

> ローテ粒度=★1 backend=1晩で確定 (harness が deploy×mode を注入)。修正スコープ (下の TODO) は
> まだ壁打ち中。Docker/GPU/ROS2 が要るので稼働 checkout がある環境限定 (実 `dup` 起動が必要)。

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

## 観点 (チェックリスト / 叩き台)
- [ ] 現バージョンのイメージで `./setup <variant>` 相当のビルドが通るか
- [ ] `dup all <MODE>` でコンテナ起動 → ノードが例外なく立ち上がるか (dlogs で確認)
- [ ] 期待トピックが publish されるか (`ros2 topic hz/echo`)
- [ ] 既知の初期化シーケンス (arm/takeoff 等) が phase 通りに進むか (可能な範囲・無人で安全な範囲)
- [ ] 依存バージョン更新 (ROS2 distro / base image / Python pin) で壊れた箇所

## 「指摘」とみなす条件
- **再現するビルド/起動失敗**、またはトピック未publish 等の明確な機能欠落。ログを添える。
- 環境依存のフレーク (1回失敗) は指摘にしない。**最低2回再現**を確認する。

## 自動修正してよい範囲 (要・壁打ち)
- <TODO: バージョン pin の追従・明白な設定漏れまで。設計に踏み込む修正は要相談>
- 安全境界は上の「★ 安全境界」が絶対則。EXP 系は対象外、HITL は受動検証のみ。
  実駆動につながる検証・修正は行わず、必要ならレポートに「要相談」で残す。

## 検証方法
- 失敗 → 修正 → **同じ `dup` シーケンスで 2 回**通ることを確認してから draft PR。
- 後始末: `drm all` 等でコンテナを片付けてから終了 (次回・他用途への影響を残さない)。
