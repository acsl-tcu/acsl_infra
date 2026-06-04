**entrypoint,sh内の colcon build が初回時のみになっているか確認**

# やるべきタスク

[システム構築における原則](https://qiita.com/ROPITAL/items/165bef33492ba27cfbf7)

・ 実験・シミュレーション・解析が「しやすい」システムを構築する
・ 変更が容易なコードを書く
・ メンテナンスが容易なコードを書く
・ テストがしやすいコードを書く

## stage 1 : クリーンコード

- 一貫性がある
- コメントを書くよりも、意味のある変数名、メソッド名、クラス名を使うこと
- コードが適切にインデントされ、スペースが確保されていること
- すべてのテストが実行できること
- 副作用のない純粋な関数を書く
- nullを渡さない

## stage 4 : 設計原則

- 継承よりもcomposition：superクラスを作るのではなく、クラスを合成（他のクラスをpropとして持つ）する。
- 変化するものをカプセル化する：スコープを意識してカプセル化するということか？
- 具象ではなく抽象的なプログラム　：このレイヤーでアーキテクチャを設計する。
- ハリウッドの原則：「呼び出すな、俺たちが呼ぶから」
- SOLIDの原則、特に単一責任の原則
  - Single Responsibilty Principle : "A class or function should only have one reason to change."
  - Open-close principle: "A software artifact should be open for extension but closed for modification.” = Higher level-components are protected from changes to lower level components. 拡張性を持ちつつ修正は内部で完結
  - Liskov-Substition Principle : "To build software systems from interchangeable parts, those parts must adhere to a contract that allows those parts to be substituted one for another." 代替可能であるという原則
  - Interface Segregation Principle : Prevent classes from relying on things that they dont need 不要なものを継承しない
  - Dependency Inversion Principle : Abstractions should not depend on details. Details should depend on abstractions. 抽象クラスは具象に依存せず、具象クラスは抽象クラスに依存させる（しなければ抽象クラスは不要）

- DRY (Do Not Repeat Yourself: 繰り返すな)
- YAGNI (You Aren't Gonna Need It: それ必要ないでしょ→必要になってから実装しろ)

##

- テストできるヒトカタマリをコンポーネントと呼ぶ。
- コンポーネントは他のコンポーネントを必要としない
- コンポーネントはテストに不要なものは含まない!?
- テストできる単位の組み合わせによってシステムを構成する。

## 抽象的なテスト構築フロー

- テストを設計する
- テスト毎のコンポーネント設計する
- コンポーネントを実装する
- 実装が機能していることを確認するためのビジュアル化を実装する。
- テスト実行する

## 具体的なタスク

### 各パーツ・システム機能毎の単体動作テスト

- モーターテスト
- VL（TOF）テスト
- T265テスト
- IMUテスト

### アルゴリズムの動作テスト

- センサー情報の取得
- 座標系の統合
- 推定器
  - 推定モデル更新
  - イノベーションの算出
- リファレンス生成
- 制御入力算出
- フェイルセーフ：各テストに対応してフェイルセーフを設計する

### 機体上での機能テスト

上述の機能単体テスト、アルゴリズムテストは機体上でも試せることが望ましい

## 生じうるリスク

- 電源・導通トラブル
- 配線トラブル
- コネクタトラブル
- ハードウェアトラブル
- アルゴリズムトラブル
- システムトラブル

## テスト構築以外のタスク

- 各フォルダ名の整理、autonomous_system, docker(現dockerフォルダと同じ), ros（rosパッケージ(acs, acsl_interfacesなど)を含むフォルダ）, など
- フォルダ構成の整理＋各設定ファイルのパス関係を修正
- READMEの名前変更 README_SYSTEM, README_DOCKER, README_ROSなど
- humble化
- IP 固定化
- ~~ROS_DOMAIN_IDの固定化~~ → `setrid <1-99>` で変更 + `dup` 日次確認ゲートを実装 (README「RID (ROS_DOMAIN_ID) の管理」参照)
- Command_list.txtを適切なファイルに統合し削除

- 要確認
  - Docker imageの名前は自由に選べるがコンテナ名と一致させるとことにする。
- これはなんのため？
@ docker-compose.yml
 ./../../ros2:/root/ros2_ws/src/ros2 # ros2をコンテナで使えるようにする
ROSパッケージを参照するだけならrosフォルダ化し、このフォルダをバインドでOK
docker内を別途バインドする必要があるのか確認

## 実行したこと

フォルダ名、ファイル名の整理
これに伴い以下のファイル内を修正

> .gitignore
> docker/docker-compose.yml

## 設定の見直し

- common/scripts/run_udev.sh 内のsleep 10はこんなにいるか？
