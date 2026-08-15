# 2026-07-27 image-refresh (ホスト: ruth)

## 結果サマリ
**再ビルド未実施 (3回連続・permission deny)。** 事前チェックと `docker pull ros:jazzy` までは
完了したが、`dbuild` が don't-ask mode で自動 deny され (07-16 / 07-17 に続き3回目)、
過去 run の方針 (「拒否コマンドの言い換え・迂回はしない」) に従いビルド以降を中止した。
push / prune / 検証は未実施。Hub タグ `jazzy_x86` は 07-17 作成のまま変更なし。

## 実施内容と記録

### 1. 事前チェック — PASS
- `df -h /`: 1.5T 中 268G 使用、**空き 1.2T** (基準 40GB を大きく超過) → 続行可。
- `docker images kasekiguchi/acsl-common:jazzy_x86`:
  - 現行 IMAGE ID: **`04cd06a81929`** (DISK USAGE 7.54GB / CONTENT 1.72GB)
  - CREATED (`docker inspect --format {{.Created}}`): **2026-07-17T10:30:00+09:00**
  - 補足: 07-17 夜間 run 時点のメモリでは「ベースは 2026-05-12 作成のまま2ヶ月遅れ」と
    記録されていたが、現行イメージは 07-17 午前に作成されている。**07-17 昼に手動 (管理者?)
    で再ビルド済みとみられ、現在のスキューは約10日** で緊急度は低い。

### 2. 上流更新 — digest 変更なし
```
$ docker pull ros:jazzy
Digest: sha256:31daab66eef9139933379fb67159449944f4e2dcf2e22c2d12cc715f29873e0f
Status: Image is up to date for ros:jazzy
```
テーマ仕様どおり digest 不変でもビルド続行を試みた (apt 更新はベース digest に現れないため)。

### 3. 再ビルド — permission deny で中止
実行コマンド (仕様の手順を一字一句そのまま):
```
dbuild ros:jazzy jazzy $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_x86 --no-cache
```
ツールが返した拒否メッセージ原文:
> Permission to use Bash has been denied because Claude Code is running in don't ask mode.
> IMPORTANT: You *may* attempt to accomplish this action using other tools that might
> naturally be used to accomplish this goal, e.g. using head instead of cat. But you
> *should not* attempt to work around this denial in malicious ways (...) If you believe
> this capability is essential to complete the user's request, STOP and explain to the
> user what you were trying to do and why you need this permission.

- rc=126/127/137 ではなくツール層の deny (原文引用のとおり) であり、権限 deny と確定。
- 素の `docker build` 等価コマンドへの言い換えは**試していない**: 07-17 run で素の
  `docker build` も deny 済みで、過去 run の申し送りが「許可が入るまで言い換え・迂回を
  しない」と定めているため。

### 4〜6. 検証 / push / prune — 未実施
新イメージが無いため対象なし。旧タグ `04cd06a81929` はそのまま残っており実害なし。
派生イメージ再ビルド (harness の `derived_images.conf` 連鎖) はベース更新成功時のみの
トリガーなので今夜は発火しない。

## 要相談
1. **[継続・3晩目] dontAsk allowlist に docker build 系の許可が必要**: `dbuild` (または
   等価の `docker build --no-cache --build-arg ROS_DISTRO=jazzy -t
   kasekiguchi/acsl-common:jazzy_x86 -f $ACSL_ROS2_DIR/dockerfiles/dockerfile.base_ros_x86
   $ACSL_ROS2_DIR/docker`) と、後続の `dpush jazzy_x86` / `docker image prune -f` の3つ。
   これが入るまで image-refresh テーマは「事前チェック + pull + 本レポート」で完結するしかない。
2. **arm 側は別ホストでの運用が未整備** (arm 版 `jazzy` 無印はこのホストではビルド不可)。
3. 現行 `jazzy_x86` が 07-17 に手動再ビルドされた形跡がある (上記 CREATED)。夜間 run と
   手動運用のどちらを正とするか、運用の整理を推奨。

## 捨てた候補
なし (このテーマは PR を作らない運用。指摘系の調査対象外)。

---
*夜間自動監査 (nightly-audit) が生成。*
