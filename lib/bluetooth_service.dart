import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class BluetoothService {
    Future<void> ensurePermissions() async {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    }
  final FlutterReactiveBle ble = FlutterReactiveBle();
  DiscoveredDevice? connectedDevice;
  QualifiedCharacteristic? ledCharacteristic;

  static const String serviceUuid = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String charUuid = "0000ffe1-0000-1000-8000-00805f9b34fb";

  Future<List<DiscoveredDevice>> scanForDevices() async {
    await ensurePermissions();
    final foundDevices = <DiscoveredDevice>[];
    final subscription = ble.scanForDevices(
      scanMode: ScanMode.lowLatency,
      withServices: [Uuid.parse(serviceUuid)],
    ).listen((device) {
      // Filtrar por nombre o por serviceUuid
      if (((device.name?.toLowerCase() == "musicled-esp32".toLowerCase()) ||
           device.serviceUuids.contains(serviceUuid)) &&
          !foundDevices.any((d) => d.id == device.id)) {
        foundDevices.add(device);
      }
    });
    await Future.delayed(const Duration(seconds: 8));
    await subscription.cancel();
    return foundDevices;
  }

  StreamSubscription<ConnectionStateUpdate>? _connectionSub;

  Future<bool> connectToDevice(DiscoveredDevice device) async {
    // Mantener la conexión activa durante el uso de la app
    _connectionSub?.cancel();
    final completer = Completer<bool>();
    _connectionSub = ble.connectToDevice(id: device.id).listen((update) async {
      if (update.connectionState == DeviceConnectionState.connected) {
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
                completer.complete(true);
                return;
              }
            }
          }
        }
        completer.complete(false);
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        ledCharacteristic = null;
        connectedDevice = null;
        completer.complete(false);
      }
    });
    // Esperar resultado de conexión o timeout
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () => false);
  }

  Future<void> sendColor(Color color) async {
    if (ledCharacteristic != null) {
      // Cambia a modo manual y aplica color
      final cmd = 'MANUAL,${color.red},${color.green},${color.blue}\n';
      await ble.writeCharacteristicWithResponse(
        ledCharacteristic!,
        value: cmd.codeUnits,
      );
    }
  }

  Future<void> sendMusicConfig({required double beatThreshold, required int musicSubmode, required double musicStepMs}) async {
    if (ledCharacteristic != null) {
      // Cambia a modo música y aplica configuración
      final cmd = 'MUSIC,${beatThreshold.round()},$musicSubmode,${musicStepMs.round()}\n';
      await ble.writeCharacteristicWithResponse(
        ledCharacteristic!,
        value: cmd.codeUnits,
      );
    }
  }

  Future<void> sendRainbowConfig({required double rainbowSpeed, required double rainbowBrightness}) async {
    if (ledCharacteristic != null) {
      // Cambia a modo arcoíris y aplica configuración
      final cmd = 'RAINBOW,${rainbowSpeed.round()},${rainbowBrightness.round()}\n';
      await ble.writeCharacteristicWithResponse(
        ledCharacteristic!,
        value: cmd.codeUnits,
      );
    }
  }

  void disconnect() {
    _connectionSub?.cancel();
    connectedDevice = null;
    ledCharacteristic = null;
  }
}
