/// 应用常量配置
class AppConstants {
  // 应用信息
  static const String appName = 'LanTransfer';
  static const String appVersion = '1.0.0';

  // 网络配置
  static const int discoveryPort = 41270;
  static const int transferPort = 41271;
  static const int maxConcurrentTransfers = 3;
  static const int bufferSize = 64 * 1024; // 64KB buffer

  // 协议消息类型
  static const String msgTypeDiscovery = 'DISCOVERY';
  static const String msgTypeAnnounce = 'ANNOUNCE';
  static const String msgTypeRequest = 'REQUEST';
  static const String msgTypeAccept = 'ACCEPT';
  static const String msgTypeReject = 'REJECT';
  static const String msgTypeComplete = 'COMPLETE';
  static const String msgTypeCancel = 'CANCEL';
  static const String msgTypePing = 'PING';
  static const String msgTypePong = 'PONG';

  // 协议版本
  static const String protocolVersion = '1.0';

  // 设备类型
  static const String deviceTypeDesktop = 'desktop';
  static const String deviceTypeMobile = 'mobile';

  // 文件尺寸限制 (10GB)
  static const int maxFileSize = 10 * 1024 * 1024 * 1024;

  // 自动发现间隔 (秒)
  static const int discoveryInterval = 3;

  // 设备超时时间 (秒)
  static const int deviceTimeout = 15;

  // mDNS 服务名
  static const String mdnsServiceType = '_lantransfer._tcp.';
  static const String mdnsServiceName = 'LanTransfer';
}