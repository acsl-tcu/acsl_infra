# テーマ: ros2-structure (ROS2 / パイプライン構造の健全性)

> ★スタブ — 壁打ちで育てる。観点は叩き台。

## 対象リポ
- project_rf_rover, project_drone2

## 観点 (チェックリスト / 叩き台)
- [ ] Tool 契約: 各 Tool が `step(context) -> Result` を満たすか。`@tool_contract` の
      inputs/outputs 宣言と実際の get_upstream/get_cascade_input の使い方が整合するか
- [ ] sensor の parallel で `results[-1]` 前提が崩れる add_tool をしていないか
      (rf_rover CLAUDE.md の既知の落とし穴)
- [ ] cascade の各段が前段出力を正しく受け渡しているか (取りこぼし/型不一致)
- [ ] config 登録と実 Tool クラスの import パスが一致するか (drone_main/rover_main は触らない)
- [ ] QoS / topic 名 / frame_id の不一致、purブリッシャ未破棄、コールバックの重い処理
- [ ] ament/package.xml と実依存の齟齬

## 「指摘」とみなす条件 (要・壁打ち)
- <TODO: 静的に確証できるものだけ。実行時にしか分からない疑いは backend-smoke 側へ回す>

## 自動修正してよい範囲 (要・壁打ち)
- <TODO: tools/ と config/ は編集可。drone_main.py / rover_main.py の登録ロジックや
  common/ は不可。どこまで機械修正を許すか要相談ライン込みで決める>

## 検証方法
- colcon build --packages-select <pkg> / colcon test
- 可能なら該当ノードを SIM backend で起動して例外なく回るか
