# 夜間監査レポート 2026-07-18 — ros2-structure

- ホスト: ruth / テーマ: ros2-structure (柱1: module 解決性, 柱2: yaml 参照解決性, 柱3: 契約整合)
- 対象: project_rf_rover, project_drone2 (targets.conf `kind=repo` との積集合)
- 走査方法: Explore fan-out 5本 (柱1×2リポ, 柱2×2リポ, 柱3×1)。試走メモの落とし穴対策
  (文字クラス `[A-Za-z0-9_]`, class 照合は .py のみ, heredoc 不使用) を適用。
- **前提の注意**: 本テーマの前回 run (07-10) は `claude: command not found` (rc=127) で監査本体が
  未実行だった。**今回が 2026-06 試走以来の初の本走査**。
- **ブランチ注意**: rf_rover のソースクローンは作業ブランチ `chore/yolo-compose-into-dockerfiles`
  のまま (ハーネスは local main を ff 更新したが working tree は不変)。git 全 deny のため
  checkout 不能で、rf_rover の走査結果は同ブランチの working tree に基づく。drone2 は main (ff pull 済)。
- **権限制約**: git は `git status` 含め全 deny (07-17 に続き 07-18 も再確認) → **draft PR 作成不能**。
  確証指摘は提案 diff 付きで本レポートに記載 (git allowlist 追加後に PR 化可能)。

---

## 結果サマリ

| 柱 | rf_rover | drone2 |
|---|---|---|
| 柱1 module 解決性 | **12/12 全解決** (+`building_module` 2/2) | **有効 104/104 全解決** (一意 29 クラス、全て file+class+`step()` O) |
| 柱2 yaml 参照解決性 | **11/11 全解決** (include 3 + `estimator/<localizer>.yaml` 自動ロード 8) | **有効 184/184 全解決** (config 起点 172 + `extends:` 相対 6 + `config_file:` 6) |
| 柱3 契約整合 | 指摘ゼロ (add_tool 崩し無し・cascade 先頭違反無し) | **確証 7 件** (契約 inputs 宣言漏れ) + 要相談 2 件 |

- 柱1 は 2026-06 試走 (計 26 件) から **計 116 有効件** に増加していたが、健全性は維持。
  コメントアウト 2 行 (drone2 `estimator/ekf_sl.yaml:11,13`) は判定対象外 (参照実体は存在)。
- 柱2 の短名形式 (レジストリ解決) は drone2 58 件 / rf_rover 12 件を列挙のみ (解決先が
  `drone_main.py`/`common/` = 編集不可領域のため、テーマ仕様どおり実在検証せず)。不審な値は無し。
- rf_rover の `{floor}` プレースホルダ入り map/floor_map 6 件は静的展開不能のためフラグ列挙のみ。

**開いた PR: 0 本** (git 全 deny のため作成不能。下記の確証指摘 1 グループが PR 候補)。

---

## 確証指摘 (PR 候補 #1): drone2 — `@tool_contract` の inputs 宣言と実使用の不一致 7 件

全件、契約が inputs を宣言していない (または宣言に無いステージを読む) のに、`step()` が
`context.get_upstream()` で上流を読んでいる。全て監査側で一次ソース裏取り済み。

| # | ファイル:行 | 読んでいる上流 | 契約の現状 |
|---|---|---|---|
| 1 | `packages/drone2/drone2/tools/reference/waypoint_reference.py:55` | estimator | outputs のみ (15-21行) |
| 2 | `packages/drone2/drone2/tools/reference/sl_flight_reference.py:94` | estimator | outputs のみ (38-46行) |
| 3 | `packages/drone2/drone2/tools/reference/sl_takeoff_reference.py:106` | estimator | outputs のみ (43-49行) |
| 4 | `packages/drone2/drone2/tools/reference/sl_settle_reference.py:95,142` | sensor, estimator | outputs のみ (43-51行) |
| 5 | `packages/drone2/drone2/tools/reference/sl_ref_adjust.py:154` | estimator | outputs のみ (88-94行) |
| 6 | `packages/drone2/drone2/tools/estimator/ekf_sl_estimator.py:92` | sensor (cascade フォールバック) | outputs のみ (39-49行) |
| 7 | `packages/drone2/drone2/tools/controller/thrust2rc.py:163` | reference (地面効果補正) | inputs 宣言あり (50-56行) だが `reference` 未宣言 |

### なぜ問題か
プロジェクト規約 (CLAUDE.md「@tool_contract で I/O 型を宣言」) と IntegrityChecker
(`common/acsl/framework/integrity_check.py:31-72`) による整合レポートの前提が崩れる。
宣言が空だと checker はこれらの実依存を検証できず、契約レポートが実態と乖離する。

### 修正案 (機械的・挙動を変えないことをフレームワークソースで確認済み)
`optional: True` 付きで宣言を追加する。根拠:
- `common/acsl/types/contract.py:83,159-182` — `optional` な input は上流欠落時に
  missing 判定を**スキップ**する。よって `sensor/none.yaml` 等の上流無し構成でも
  整合チェック結果は変わらない。
- `common/acsl/tools/base.py:24-60` — `tool_contract` は契約 dict を構築するだけで
  実行時の `step()` 挙動には一切影響しない。
- コードは全箇所で None 許容 (フォールバック実装) → `optional: True` が実態を正確に表現する。

提案 diff (代表例。#1-#5 は同型):

```python
# waypoint_reference.py / sl_flight / sl_takeoff / sl_ref_adjust (estimator のみ)
@tool_contract(
    inputs={
        "estimator": {"path": "estimator.state", "dtype": "ndarray",
                      "optional": True, "desc": "13-dim state (未接続許容)"},
    },
    outputs={...},  # 既存のまま
)

# sl_settle_reference.py — sensor と estimator の両方
    inputs={
        "sensor": {"path": "sensor.state", "dtype": "ndarray", "optional": True},
        "estimator": {"path": "estimator.state", "dtype": "ndarray", "optional": True},
    },

# ekf_sl_estimator.py — cascade 主入力 + sensor フォールバック
    inputs={
        "state": {"path": "cascade.state", "dtype": "ndarray", "optional": True},
        "sensor": {"path": "sensor.state", "dtype": "ndarray", "optional": True},
    },

# thrust2rc.py — 既存 inputs に追加
        "reference": {"path": "reference.state", "dtype": "ndarray",
                      "optional": True, "desc": "地面効果補正用 (未接続時 th_offset)"},
```

- スコープ: 全ファイル `tools/` 配下 = 編集可領域。宣言のみの追加で実行コード不変。
- 確信度: 高 (不一致自体は静的事実。修正が挙動を変えないこともフレームワーク実装で確認)。
- 検証計画 (PR 化時): `python -m py_compile` 対象 7 ファイル + `colcon build --packages-select drone2`
  + SIM backend での bringup (dup all SIM)。**今夜は git deny のため未適用・未検証**
  (working tree を汚さないため編集自体を見送り)。
- ブランチ案: `audit/ros2-structure-contract-inputs` (1 PR にまとめる。7 件は同一クラスの指摘)。

---

## 要相談 (PR 化せず。設計判断・実行時確証が必要)

### 要相談 A: drone2 — sensor(parallel) の `results[-1]` 意味論と RC/GPS 末尾配置の緊張
フレームワークの parallel カテゴリは**最後に非 None を返したツールの Result** を
`results["sensor"]` に載せる (`common/acsl/framework/tool_category.py:129-139`,
`pipeline_engine.py:65-76`)。以下の 4 config は 13-dim 主状態センサーが末尾でない:

| config | tools 順 (drone_main.py:400-412 で fc_sensor が先頭に追加され、config の tools が後続) |
|---|---|
| `config/sensor/mocap_rc.yaml` | MocapSensor → **RCSensor** (state=RC 10ch, `rc_sensor.py:145-146`) |
| `config/sensor/mocap_mavros_rc.yaml` | MocapMavrosSensor → **RCSensor** |
| `config/sensor/vio_rc.yaml` | VIOSensor → **RCSensor** |
| `config/sensor/gps_mocap.yaml` | MocapSensor → **GPSSensor** (state=ENU 3-dim) |

静的には決着できない両説が併存する:
- **意図的説**: `tools/phase/phase_actions.py:27-31` が RC の arm/mode/land エッジを
  `results["sensor"].metadata["edges"]` から読む = RC が末尾で results["sensor"] を
  占有するのは設計意図。
- **危険説**: EKF のデフォルト observation は source "fc" = `results["sensor"]` を読む
  (`ekf_estimator.py:252-263,280-291`)。RC 有効時は state が 10ch RC 値になり、
  `_init_from_sensor` / 観測抽出が 13-dim 前提と衝突しうる。しかも RCSensor は
  `_valid=False` でも `Result(state=None)` を返す (None ではない) ため、
  「末尾が None ならフォールスルー」の緩和も効かない。
- 付随する不整合: `ekf_estimator.py:11` の docstring は「source = `results["sensor"]` 内の
  キー (tool 名の dict)」と記すが、現行実装の `results["sensor"]` は単一 Result であり
  dict ではない。**契約意味論のどちらが正か管理者確認が必要**。
- 対象 4 config は全て EXP 系 (mocap/実機 RC 必須) のため **backend-smoke (SIM/SITL) では
  再現不能**。実機安全則により実行検証はしない。→ 管理者に「RC 末尾は意図か」を確認したい。

### 要相談 B: drone2 — `sl_landing_reference.py:81` の未宣言 sensor 読み (契約継承ケース)
`SLLandingReference(LandingReference)` は独自 `@tool_contract` を持たず親契約
(inputs=`estimator.state` のみ, `landing_reference.py:22-24`) を継承するが、
`sensor.metadata["pL"]` を追加で読む (81-84行)。修正には「親契約の複製 + sensor 追加」か
「契約継承のフレームワーク対応」の選択が要り、確証指摘 #1-#7 と違い設計判断を含むため要相談。

---

## 捨てた候補とその理由

1. **rf_rover の「意味名契約」と get_upstream ステージ名の不一致** (tscf_controller,
   building_actuator 等) — rf_rover は `@tool_contract` 不使用で `contract()` メソッド +
   意味名 inputs (`estimate`/`cmd_input` 等) という**別規約**。ステージ名照合は非適用であり
   不具合ではない (偽陽性)。
2. **drone2 の outputs 宣言 vs `return Result(...)` の食い違い** — 抜き取り確認で違反ゼロ。
3. **cascade 先頭に `get_cascade_input()` 依存ツール** — 両リポともゼロ
   (`ekf_sl.yaml` の単一先頭 EKFSuspendedLoad は sensor フォールバック実装があり違反でない)。
4. **rf_rover sensor の add_tool 崩し** — `rover_main.py:176-178` は BuildingSensor 単一
   add_tool のみ。検知系は独立ノード購読方式 (CLAUDE.md どおり) でクリーン。
5. **rf_rover `building_module:` の「未実装 (Phase 2)」コメント** (omni_yc_bld7.yaml:38) —
   ファイル `isaac_sim/scripts/scene/gen_yc_bld7.py` は実在し解決する。コメント鮮度の問題は
   docs-drift テーマの範囲。

## 運用メモ (ハーネス向け)

- 07-10 の本テーマ run はハーネス起因 (rc=127, `claude` 不在) で未実行だった。今回で回収。
- git 全 deny 継続 (07-18 再確認)。allowlist が入れば本レポートの PR 候補 #1 は
  `audit/ros2-structure-contract-inputs` ブランチで即 PR 化可能。
- rf_rover ソースクローンが作業ブランチのまま放置されている点は、次回以降の静的監査でも
  「origin/main と異なる working tree を走査する」リスクとして残る。
