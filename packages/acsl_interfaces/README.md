# Autonomous control system library's interfaces (acsl_interfaces)
カスタムメッセージ型を定義しているパッケージ

## 定義されているメッセージ
| Message Type                                       | Description |
| -------------------------------------------------- | ------------- |
| [Attitude.msg](./msg/Attitude.msg)                 | Mavlink_driverから姿勢角と角速度を出力するための型 |
| [EscTelemetry1To4.msg](./msg/EscTelemetry1To4.msg) | ESCの電圧，回転数などのデータを格納する型 |
| [Heartbeat.msg](./msg/Heartbeat.msg)               | FCUのバージョンなどを格納する型 |
| [Mav.msg](./msg/Mav.msg)                           | FCUの制御モード，Arm状況などを格納する型 |
| [RcChannels.msg](./msg/RcChannels.msg)             | プロポの信号状況を格納する型 |