import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter/material.dart';

class BluetoothService {
  final FlutterReactiveBle ble = FlutterReactiveBle();
  DiscoveredDevice? connectedDevice;
  QualifiedCharacteristic? ledCharacteristic;

  static const String serviceUuid = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String charUuid = "0000ffe1-0000-1000-8000-00805f9b34fb";

  Future<List<DiscoveredDevice>> scanForDevices() async {
    final foundDevices = <DiscoveredDevice>[];
    final subscription = ble.scanForDevices(
      withServices: [Uuid.parse(serviceUuid)],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      if (!foundDevices.any((d) => d.id == device.id)) {
        foundDevices.add(device);
      }
    });
    await Future.delayed(const Duration(seconds: 4));
    await subscription.cancel();
    return foundDevices;
  }

  Future<bool> connectToDevice(DiscoveredDevice device) async {
    final connection = ble.connectToDevice(id: device.id).listen((_) {});
    // Esperar a que la conexión se establezca
    await Future.delayed(const Duration(seconds: 2));
    connectedDevice = device;
    final services = await ble.discoverServices(device.id);
    for (var s in services) {
      if (s.serviceId.toString() == serviceUuid) {
        for (var c in s.characteristics) {
          if (c.characteristicId.toString() == charUuid) {
            ledCharacteristic = QualifiedCharacteristic(
              serviceId: s.serviceId,
              characteristicId: c.characteristicId,
              deviceId: device.id,
            );
            await connection.cancel(); // Cancelar listener de conexión
            return true;
          }
        }
      }
    }
    await connection.cancel();
    return false;
  }

  Future<void> sendColor(Color color) async {
    if (ledCharacteristic != null) {
      await ble.writeCharacteristicWithResponse(
        ledCharacteristic!,
        value: [color.red, color.green, color.blue],
      );
    }
  }

  void disconnect() {
    // No hay método directo, pero se puede dejar de escuchar la conexión
    connectedDevice = null;
    ledCharacteristic = null;
  }
}
