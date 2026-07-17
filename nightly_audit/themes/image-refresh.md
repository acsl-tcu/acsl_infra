# テーマ: image-refresh (Hub ベースイメージの定期再ビルド & push)

> Hub (`kasekiguchi/acsl-common`) のベースタグが古いまま放置されると、派生イメージ
> (image_*, mavros2 等) との間で apt パッケージのスキューが全ホストに波及する。
> 由来: 2026-07 に `jazzy`/`jazzy_x86` が約2ヶ月前のままでスキューが発生した。
> このテーマは rotation で回ってくるたびに **このホストでビルドできるベースタグを
> 上流から作り直して push** する。PR は作らない。成果物は更新された Hub タグとレポート。

## 対象
- `kasekiguchi/acsl-common:jazzy_x86` のみ (このホスト = x86)。
- arm 版 `jazzy` (無印) は arm ホスト or qemu が必要でこのホストでは**ビルド不可**。
  毎回レポートの「要相談」に「arm 側は別ホストでの運用が未整備」と1行残す
  (arm ホストに同運用が入ったらこの記載を落とす)。
- `humble` 系は現行 project (drone2 / rf_rover = jazzy) が使っていないため対象外。

## 手順 (この順で。ハーネスが ACSL_ROS2_DIR / ROS_DISTRO=jazzy / PATH を export 済み)
1. **事前チェック** (どれか失敗なら以降を中止して要相談):
   - `df -h /` — 空き 40GB 未満なら中止 (ビルド中間層で一時的に膨らむ)。
   - `docker images kasekiguchi/acsl-common:jazzy_x86` — 現行の IMAGE ID と CREATED を記録。
2. **上流を更新**: `docker pull ros:jazzy` — digest が変わったか出力から記録
   (Image is up to date でもビルドは続行する。apt レベルの更新はベース digest に現れない)。
3. **再ビルド**:
   `dbuild ros:jazzy jazzy $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_x86 --no-cache`
   - `--no-cache` は必須 (キャッシュが残ると apt update/upgrade 層が古いまま再利用される)。
   - 失敗したら push せず、エラー末尾を添えて要相談。旧タグはそのまま残るので実害なし。
4. **検証** (push 前に必ず):
   - `docker images kasekiguchi/acsl-common:jazzy_x86` — IMAGE ID が変わり CREATED が今日。
   - `docker run --rm kasekiguchi/acsl-common:jazzy_x86 bash -c "source /opt/ros/jazzy/setup.bash && ros2 pkg list | wc -l"`
     — 300 以上であること (desktop 一式が入っている目安)。
5. **push**: `dpush jazzy_x86` (認証はホストの保存済み credential。失敗したら要相談)。
6. **後始末**: `docker image prune -f` (旧タグが dangling 化して 7GB 級で溜まるため必須。
   dangling のみ削除するので稼働中コンテナ・タグ付きイメージには影響しない)。

## レポートに必ず書くこと
- 旧/新 IMAGE ID と CREATED、`ros:jazzy` の digest 更新有無、検証結果 (pkg 数)、
  push 成否、prune で回収した容量。
- 派生イメージ (image_* 等) は**このテーマでは再ビルドしない** (デプロイ時 / setup で
  ベースから作り直される設計)。ベース更新が入った晩は「派生は次回 deploy 時に追従」と記載。

## やらないこと (安全境界・絶対)
- `jazzy_x86` 以外のタグを push しない (image_*, isaac 系, humble, arm 無印を含む)。
- 稼働中コンテナに触らない (docker stop/rm/restart をしない)。
- `docker image prune` は `-f` (dangling のみ) 以外の形で使わない
  (`-a` は全未使用イメージを消すので絶対に使わない)。
- ビルド失敗時に Dockerfile や compose を修正して再試行しない (要相談へ)。

## 検証方法
- 手順 4 がそのまま検証。加えて push 後に `docker images` の DIGEST 欄 (あれば) か
  `dpush` 出力の digest をレポートへ転記する。
