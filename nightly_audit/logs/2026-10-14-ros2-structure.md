# 2026-10-14 ros2-structure (host: ruth)

## 調べた範囲 (差分監査。前回基準線からの変化のみ)
- **project_rf_rover**: 基準線 69464b74 から 0 コミットのため、再走査はしていない。
- **project_drone2**: 3a53ebb..608e9a6 の 22 コミット (#237-240、coop 協調搬送の DOB / settle / 推定器)。15 ファイル、+1799/-113。
  - 柱1: `module:` の追加・変更は無い (hlc_sl_coop.yaml の 2 件は既存のパスで、解決済み)。
  - 柱2: include / reference / config_file の参照に変更は無い。壊れた参照は 0。
  - 柱3 (config→code): 新規キー 19 個を全てコード側で照合し、未解決は 0。
    - hlc_sl_controller `@config_params` (6 キー): wl_lp_tau / load_mass_rate / use_estimated_ext_force / ext_force_key / ext_force_max / ext_force_tau
    - ekf_sl_dynamics `config.get` (9 キー): mL_init_on_taut / mL_init_P / ext_force_mode / dob_tau / dob_notch / dob_notch_zeta / dob_max / dob_model_mL / dst_freeze_phases
    - sl_coop_reference `settle.get` (4 キー): stop_time / stall_grace / touchdown_sanity / touchdown_near
  - 柱3 (契約): DOB が読む上流 metadata `hb`="pL=meas" と `lifted` は、sl_state_adjust.py:213-252 が出している。新設の `reload_params` 2 件 (estimator / reference) は `_cfg` を `__init__` の先頭で保持していて、注入値も取りこぼさない。

## 確証指摘 / 開いた PR
1. **drone2 #242** (draft) https://github.com/acsl-tcu/project_drone2/pull/242
   `config/estimator/sl_coop_omni.yaml` の mL_q は値 0.01 だが、コメントは「0.01 -> 0.1」「mL_q を上げる」のまま食い違っていた。
   5cbe0d5 の revert で値は 0.01 に戻ったが、同じ revert で戻した他の 4 項目と違い、mL_q だけ撤回の注記が抜けていた。コメント 2 行を追加しただけで、値は変えていない。確信度は高。
   - ラベル `nightly-audit` は付けていない (ラベル系は deny 実績があるため、打たずに見送った)。

## 捨てた候補 / 要相談
- **M45 (軽微・要相談)**: hlc_sl_coop.yaml のコメント内で食い違いがある。「推定を試すとき」節は load_mass_max を「0.79 の 2 倍で頭打ち」と書くが、実値 1.0 の注記は「1.3 倍」。
  - さらに 2026-10-07 の比較表は「mL 固定 0.79 + dst 有効 <- 最良 (採用)」と書くが、現在の use_estimated_ext_force は false (10-08 に撤回)。
  - どちらも経緯ログ形式のコメントで、どこまでを現況として書き直すかは作者の判断が要るので PR にしない。
- hlc_sl_controller `_effective_P` で、推定 mL 不在のとき dst の反映を飛ばす件: 既存 drone2 #231 と同じなので重複起票しない。main ではまだ残っているが、現 config は両機能 false なので潜在。
- hlc_sl_controller `_wL_filt` のリセットが use_estimated_load_mass=true の分岐の中にしかない: wl_lp_tau=0 で現状は無効。潜在のため軽微として記録だけ残す。
- coop_sl.yaml の k_cable 8 / "near-taut" コメント: 既存の M44 (docs-drift) と同じ。
- rf_rover の前回からの PR 候補 (Nav2PathClient の cancel 欠落 / `_publish_scan_debug` の死にコード / omni_yc_bld7.yaml の `slam_jump` 4 スペースインデント):
  - インデントは YAML として有効で、動作は変わらない。
  - rf_rover には nightly PR が 9 本滞留しているので、ノイズを抑えるため今回は見送った。

## 既存 PR の状態
- rf_rover の #441-447 / #463-465 は OPEN のまま滞留。#442 は CONFLICTING、#446 の実バグは main で残存。
- drone2 の #225/#228-231/#241 は OPEN のまま滞留。

## 次回基準線
- rf_rover 69464b74 / drone2 608e9a6
