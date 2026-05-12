class DeviceSession {
  DeviceSession({
    required this.deviceId,
    required this.deviceName,
    required this.model,
    required this.platform,
    required this.appVersion,
    required this.active,
    required this.createdAtMs,
    required this.lastSeenAtMs,
  });

  final String deviceId;
  final String deviceName;
  final String model;
  final String platform;
  final String appVersion;
  final bool active;
  final int createdAtMs;
  final int lastSeenAtMs;

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'model': model,
      'platform': platform,
      'appVersion': appVersion,
      'active': active,
      'createdAtMs': createdAtMs,
      'lastSeenAtMs': lastSeenAtMs,
    };
  }
}

