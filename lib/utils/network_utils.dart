import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

/// 网络工具类
class NetworkUtils {
  static final NetworkInfo _networkInfo = NetworkInfo();

  /// 获取设备本地 IP 地址
  static Future<String?> getLocalIp() async {
    try {
      final ip = await _networkInfo.getWifiIP();
      return ip;
    } catch (e) {
      // 备用方案：直接遍历网络接口
      return await _getLocalIpFallback();
    }
  }

  /// 备用方案：遍历网络接口获取 IP
  static Future<String?> _getLocalIpFallback() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback &&
              address.type == InternetAddressType.IPv4) {
            return address.address;
          }
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 获取设备的广播地址
  static Future<String?> getBroadcastAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback &&
              address.type == InternetAddressType.IPv4) {
            // 通常广播地址是 x.x.x.255
            final parts = address.address.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}.255';
            }
          }
        }
      }
    } catch (e) {
      // ignore
    }
    return '255.255.255.255'; // 全网广播作为备选
  }

  /// 验证 IP 地址格式
  static bool isValidIp(String ip) {
    try {
      final parts = ip.split('.');
      if (parts.length != 4) return false;
      for (final part in parts) {
        final num = int.parse(part);
        if (num < 0 || num > 255) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 验证端口号
  static bool isValidPort(int port) {
    return port > 0 && port <= 65535;
  }

  /// 从地址提取 IP
  static String extractIp(String address) {
    if (address.contains(':')) {
      return address.split(':').first;
    }
    return address;
  }

  /// 从地址提取端口
  static int extractPort(String address) {
    if (address.contains(':')) {
      final parts = address.split(':');
      if (parts.length == 2) {
        return int.tryParse(parts[1]) ?? 0;
      }
    }
    return 0;
  }

  /// 检查是否是有效目标地址
  static bool isValidTarget(String address) {
    final ip = extractIp(address);
    final port = extractPort(address);
    return isValidIp(ip) && isValidPort(port);
  }

  /// 解析 IP:Port 格式
  static (String, int)? parseAddress(String address) {
    final ip = extractIp(address);
    final port = extractPort(address);
    if (isValidIp(ip) && isValidPort(port)) {
      return (ip, port);
    }
    return null;
  }

  /// 检查两设备是否在同一局域网
  static bool isSameNetwork(String ip1, String ip2, String subnetMask) {
    try {
      final parts1 = ip1.split('.').map(int.parse).toList();
      final parts2 = ip2.split('.').map(int.parse).toList();
      final maskParts = subnetMask.split('.').map(int.parse).toList();

      for (int i = 0; i < 4; i++) {
        if ((parts1[i] & maskParts[i]) != (parts2[i] & maskParts[i])) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}