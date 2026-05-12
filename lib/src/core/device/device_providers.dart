import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_service.dart';

final deviceInfoProvider = Provider<DeviceInfoPlugin>((ref) {
  return DeviceInfoPlugin();
});

final deviceServiceProvider = Provider<DeviceService>((ref) {
  return DeviceService(ref.watch(deviceInfoProvider));
});

final deviceIdentityProvider = FutureProvider<DeviceIdentity>((ref) async {
  return ref.watch(deviceServiceProvider).getIdentity();
});

