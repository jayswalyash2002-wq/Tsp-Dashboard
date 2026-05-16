import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceIdentity {
  DeviceIdentity({
    required this.deviceId,
    required this.model,
    required this.platform,
    required this.appVersion,
  });

  final String deviceId;
  final String model;
  final String platform;
  final String appVersion;
}

class DeviceService {
  DeviceService(this._deviceInfo);

  final DeviceInfoPlugin _deviceInfo;

  Future<DeviceIdentity> getIdentity() async {
    final pkg = await PackageInfo.fromPlatform();
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      // androidId is stable per device+user; good enough for "one-time login per device".
      final androidId = info.id;
      return DeviceIdentity(
        deviceId: androidId,
        model: '${info.manufacturer} ${info.model}'.trim(),
        platform: 'android',
        appVersion: '${pkg.version}+${pkg.buildNumber}',
      );
    }
    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      final id = info.identifierForVendor ?? '${info.name}-${info.model}';
      return DeviceIdentity(
        deviceId: id,
        model: '${info.name} ${info.model}'.trim(),
        platform: 'ios',
        appVersion: '${pkg.version}+${pkg.buildNumber}',
      );
    }
    // Fallback for unsupported platforms (desktop/web) in development.
    return DeviceIdentity(
      deviceId: 'unknown-device',
      model: 'Unknown device',
      platform: Platform.operatingSystem,
      appVersion: '${pkg.version}+${pkg.buildNumber}',
    );
  }
}

