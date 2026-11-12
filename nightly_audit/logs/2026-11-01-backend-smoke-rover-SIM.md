# Nightly Audit 2026-11-01 — backend-smoke-rover-SIM (host: ruth)

## ★ 再実行 (14:18 / 14:19 JST, HEAD 47153458) — PASS (これが最新判定)

午前の FAIL (下に残す) の後、main が 47153458 (`fix: setup に bcps_bridge を追加し SIM の rplidar 起動を削除 (#472)`) に進んだ。
ruth の `image_rf_rover_x86` には rf_rover / bcps_bridge が入った状態になっていた。
この状態で `dup all SIM` を **2回** 実行し、どちらの回も全コンテナが起動・生存した。

| container | image | 判定 (2回とも同一) |
|---|---|---|
| rf_tf | image_rf_rover_x86 | `robot_state_publisher: Robot initialized` |
| bcps_bridge | image_rf_rover_x86 | Up。モック BOS (127.0.0.1:8090) に connection refused で 5s ごとにリトライ (要相談 1) |
| rover | image_rf_rover_x86 | **`Building nav ready: rid=1, floor=4, cid=15`** に到達。traceback なし |
| nav2 | nav2_x86 | map_server/amcl が active (`Managed nodes are active`)。planner_server も作成済み |

- rplidar_front/back は #472 で SIM から外れたので、起動されなくなった。午前の要相談 3 は解消。
- 約 40 秒後に再確認したが、遅れて死んだコンテナはなかった。
- 後始末: 各回 `docker rm -f rover nav2 bcps_bridge rf_tf` を実行し、`docker ps -a` が空であることを確認した。
- 実機安全: SIM のみ。console への送信なし。
- 確証指摘: なし。PR なし。

### 要相談 / 観測 WARN (自動修正なし)

1. **local SIM でモック BOS (bcps_sim_server) を誰も起動していない**
   - `project_launch.sh:237-243` は SIM で bridge を `sim` params で起動する。しかし 8090 で待ち受けるサーバがいないので、bridge は初期化リトライを続ける。
   - `project_launch.sh:235` に「bridge 不在でも rover 側は接続リトライで待つ」とあり、起動失敗ではない。
   - ただし local SIM では EV/ドア連携が機能しない見込み。SIM でもモック BOS を立てるかは設計判断。
2. **rover: `[BcpsInterface] doors_bcps.json が見つからない (env=bld10)`**
   - launch_bcps_bridge.sh も `elevators_file=` / `doors_file=` を表示しなかった。よって bld10 環境リポに `*_bcps.json` が無いとみられる。
   - 秘匿規約により /ENV の中身は確認していない。結果として開扉確認は常に「不明」になる。
3. `EV exit auto 判定不能 (cabin_size なし) — orient で続行`: フォールバックが設計済みの WARN。良性。
4. FastDDS `XMLPARSER Error: realpath failed` (全コンテナ): 既知の問題 (FASTRTPS_DEFAULT_PROFILES_FILE がホストパスのまま)。起動は阻害していない。
5. 任意の受動トピック確認は未実施。
   - `docker exec rover bash -lc "source /opt/ros/jazzy/setup.bash; ros2 topic list"` が拒否された。
   - 拒否メッセージ原文: `Permission to use Bash has been denied because Claude Code is running in don't ask mode.`

---

## (履歴) 午前の実行 02:30 / 02:32, HEAD b54d134c — FAIL

### 結論
**FAIL (2回再現)。rover / rf_tf / bcps_bridge コンテナが起動直後に終了し、rover ノードが立ち上がらない。**
原因はコードではなく**ホスト上のイメージ `kasekiguchi/acsl-common:image_rf_rover_x86` に
colcon build 済みワークスペース (`/root/ros2_ws/install`) が入っていない**こと (推定・下記証拠)。
修正にはイメージの再ビルド (`./setup` → `build_project`) が必要で、監査の自動修正範囲外のため **PR なし**。

- 対象: deploy=rover (`/home/sekiguchi/rover`, origin/main = b54d134c と一致・作業ツリー clean)、mode=SIM
- 実施: `dup all SIM` ×2 (02:30 / 02:32)。各回 `docker ps -a` + `docker logs --tail N` で判定
- 後始末: 2回とも対象6コンテナを `docker rm -f` で名前指定削除。最終 `docker ps -a` は空
- 実機安全: SIM のみ。console 操作・駆動指令の送出なし

## 起動結果 (2回とも同一)
| container | image | 結果 |
|---|---|---|
| nav2 | nav2_x86 | Up。map_server/amcl が active (`Managed nodes are active`) |
| rover | image_rf_rover_x86 | **Exited (0)** — `Package 'rf_rover' not found` |
| rf_tf | image_rf_rover_x86 | **Exited (0)** — `package 'rf_rover' not found, searching: ['/opt/ros/jazzy']` |
| bcps_bridge | image_rf_rover_x86 | **Exited (0)** — `package 'bcps_bridge' not found, searching: ['/opt/ros/jazzy']` |
| rplidar_front/back | rplidar_x86 | Exited — `Error, unexpected error, code: 80008004` (実機 LiDAR 無し。下記 要相談) |

rover コンテナログ (run 2, `docker logs --tail 20 rover`):
```
===== Ready! =====
[launch_rover] use_sim_time_value=true
[launch_rover] use_sim_time_arg=use_sim_time:=true
[launch_rover] config_path=config_path:=local.yaml
The daemon has been started
Package 'rf_rover' not found
chmod: cannot access '/root/ros2_ws/launcher/rosbags/*': No such file or directory
```

## 原因の推定 (証拠)
- `.acsl/docker/common/scripts/entrypoint.sh:59-62` は `/root/ros2_ws/install` があれば source する。
  rf_tf の検索パスが `['/opt/ros/jazzy']` だけ = **イメージ内に install が無い (または空)**。
- コンテナに mount されるのは `packages/` → `src/ros_packages` のソースだけ (`docker-compose.yml:103`)。
  install はイメージ側にしか無く、`build_project` (`.acsl/commands/scripts/build_project`) が
  build コンテナを `dcommit` してイメージへ焼き込む設計。
- `docker images`: `image_rf_rover_x86` の CONTENT SIZE 1.71GB はベースの `jazzy_x86` (1.71GB) と同じ。
  build 済みに見えるのは `image_drone2_x86` (1.73GB) の方 → rover イメージはビルド前のベースのままである可能性が高い (状況証拠)。
- イメージの作成日時やレイヤ・中身 (`docker image inspect` / `docker run --rm ... ls`) は確認できなかった。拒否メッセージ原文:
  `Permission to use Bash has been denied because Claude Code is running in don't ask mode.`
  過去ログ (07-25 / 08-05) は使用中ゲートで skip だったので、rover-SIM が実際に bringup したのは今回が初めて。いつから壊れていたかは分からない。

## 管理者への依頼 (要相談)
1. **ruth で rover イメージを再ビルド**: `cd ~/rover && ./setup` (既定ケースで `build_project ... rf_rover rf_interfaces`)。
   その後 `dup all SIM` を再実行すれば rover-SIM を再判定できる。bcps_bridge も同じイメージを使うので、
   `build_project` 対象に bcps_bridge パッケージが入っているかも確認すること (`setup:103` の列挙には無い)。
2. **イメージ再生成経路の確認 (acsl_infra)**: image-refresh / `gpull common` 等でベースから `image_<project>_x86`
   を作り直す処理が `build_project` を通らずに走ると、こうなる (install 無しのイメージができる)。
   該当経路があるなら、再生成後に build_project を自動で走らせるか、smoke 前に install の有無を検査するのが良い。
   (今回は経路を特定できていない。)
3. **SIM で rplidar_front/back を起動している件** (`project_launch.sh:42-43`): 実機 LiDAR が無いホストでは
   毎回 `80008004` で落ちる。机上で実 LiDAR を使う「ローカル SIM」の想定なら意図どおりなので、
   設計判断として**要相談** (自動修正しない)。
4. 細かい点 (実害なし): `launch_rover.sh:47` は `$2` (`config_path:=local.yaml`) をそのままパスとして解決するため、
   `config_path=config_path:=local.yaml` と表示される。既定分岐では `extra_params` が `-p config_path:=local.yaml`
   として正しく渡るので動作に影響は無い。

## 開いた PR
なし (原因はホストのイメージ状態。修正はイメージの再ビルドで、Docker イメージの変更は監査の範囲外)。

## 捨てた候補
- `DF`/`BASE_IMAGE`/`USER`/`XDG_RUNTIME_DIR` 未設定の compose WARN: 毎回出るが起動に影響なし。
- `image <x> does NOT exists. Use image_rf_rover_x86`: テーマ仕様にある正常なフォールバック表示。
- `chmod: cannot access '/root/ros2_ws/launcher/rosbags/*'`: 終了処理で出るだけで無害。

(午前の FAIL は、イメージの再ビルドと #472 で解消した。最新判定は冒頭の再実行結果 = PASS)

SMOKE_RESULT: PASS

---
**昇格台帳**: base `037652007143` — 残り mode: isaacsim (全 PASS で昇格 = gpull common 展開可)
