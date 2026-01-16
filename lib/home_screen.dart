
import 'package:flutter/material.dart';
import 'color_wheel_picker.dart';
import 'bluetooth_service.dart';

class ColorMode {
  final String name;
  final IconData icon;
  const ColorMode(this.name, this.icon);
}

final List<ColorMode> modes = [
  ColorMode('Manual', Icons.palette),
  ColorMode('Música', Icons.music_note),
  ColorMode('Arcoíris', Icons.gradient),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedMode = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Controlador RGB')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Barra de modos
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(modes.length, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ElevatedButton.icon(
                    icon: Icon(modes[i].icon, size: 16),
                    label: Text(modes[i].name, style: const TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedMode == i ? Colors.blue : Colors.grey[300],
                      foregroundColor: selectedMode == i ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: const Size(80, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setState(() => selectedMode = i),
                  ),
                )),
              ),
              const SizedBox(height: 32),
              if (selectedMode == 0) ManualControlSection(),
              if (selectedMode == 1) MusicControlSection(),
              if (selectedMode == 2) RainbowControlSection(),
            ], // <-- cierre correcto del array children
          ),
        ),
      ),
    );
  }
}



class ManualControlSection extends StatefulWidget {
  const ManualControlSection({Key? key}) : super(key: key);
  @override
  State<ManualControlSection> createState() => _ManualControlSectionState();
}

class _ManualControlSectionState extends State<ManualControlSection> {
  Color selectedColor = Colors.blue;
  String statusMsg = '';
  BluetoothService btService = BluetoothService();
  bool isConnected = false;

  Future<void> connectBluetooth() async {
    setState(() { statusMsg = 'Buscando dispositivos...'; });
    var devices = await btService.scanForDevices();
    if (devices.isNotEmpty) {
      bool ok = await btService.connectToDevice(devices.first);
      setState(() {
        isConnected = ok;
        statusMsg = ok ? 'Conectado a ${devices.first.name}' : 'No se pudo conectar';
      });
    } else {
      setState(() { statusMsg = 'No se encontraron dispositivos.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Control Manual', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
        const SizedBox(height: 16),
        ColorWheelPicker(
          initialColor: selectedColor,
          onColorChanged: (color) => setState(() => selectedColor = color),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isConnected ? null : connectBluetooth,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(80, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Conectar Bluetooth', style: TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: isConnected
                  ? () async {
                      await btService.sendColor(selectedColor);
                      setState(() { statusMsg = 'Color enviado: #${selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}'; });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(80, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Aplicar color', style: TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(statusMsg, style: const TextStyle(color: Colors.purple, fontFamily: 'PressStart2P', fontSize: 10)),
      ],
    );
  }
}



class MusicControlSection extends StatefulWidget {
  const MusicControlSection({Key? key}) : super(key: key);
  @override
  State<MusicControlSection> createState() => _MusicControlSectionState();
}

class _MusicControlSectionState extends State<MusicControlSection> {
  double beatThreshold = 400;
  int musicSubmode = 0; // 0 = monocolor, 1 = multicolor
  double musicStepMs = 200;
  BluetoothService btService = BluetoothService();
  String statusMsg = '';
  bool isConnected = false;

  Future<void> connectBluetooth() async {
    setState(() { statusMsg = 'Buscando dispositivos...'; });
    var devices = await btService.scanForDevices();
    if (devices.isNotEmpty) {
      bool ok = await btService.connectToDevice(devices.first);
      setState(() {
        isConnected = ok;
        statusMsg = ok ? 'Conectado a ${devices.first.name}' : 'No se pudo conectar';
      });
    } else {
      setState(() { statusMsg = 'No se encontraron dispositivos.'; });
    }
  }

  Future<void> sendMusicConfig() async {
    if (btService.ledCharacteristic != null) {
      String msg = 'MUSIC,${beatThreshold.round()},$musicSubmode,${musicStepMs.round()}';
      await btService.ble.writeCharacteristicWithResponse(
        btService.ledCharacteristic!,
        value: msg.codeUnits,
      );
      setState(() { statusMsg = 'Configuración enviada'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Modo Música', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.surround_sound, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text('Sensibilidad Beat', style: const TextStyle(fontSize: 12, fontFamily: 'PressStart2P')),
          ],
        ),
        Slider(
          min: 0,
          max: 2000,
          value: beatThreshold,
          onChanged: (v) => setState(() => beatThreshold = v),
          label: beatThreshold.round().toString(),
        ),
        Text('Umbral actual: ${beatThreshold.round()}', style: const TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 300) {
              // Pantallas pequeñas: botones uno debajo del otro
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() => musicSubmode = 0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: musicSubmode == 0 ? Colors.blue : Colors.grey[300],
                      foregroundColor: musicSubmode == 0 ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: const Size(70, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Monocolor', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: () => setState(() => musicSubmode = 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: musicSubmode == 1 ? Colors.blue : Colors.grey[300],
                      foregroundColor: musicSubmode == 1 ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: const Size(70, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Multicolor', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
                  ),
                ],
              );
            } else {
              // Pantallas normales: botones en fila, más pequeños
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() => musicSubmode = 0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: musicSubmode == 0 ? Colors.blue : Colors.grey[300],
                      foregroundColor: musicSubmode == 0 ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: const Size(70, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Monocolor', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => setState(() => musicSubmode = 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: musicSubmode == 1 ? Colors.blue : Colors.grey[300],
                      foregroundColor: musicSubmode == 1 ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: const Size(70, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Multicolor', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
                  ),
                ],
              );
            }
          },
        ),
        if (musicSubmode == 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Duración paso multicolor', style: const TextStyle(fontSize: 12, fontFamily: 'PressStart2P')),
            ],
          ),
          Slider(
            min: 5,
            max: 5000,
            value: musicStepMs,
            onChanged: (v) => setState(() => musicStepMs = v),
            label: musicStepMs.round().toString(),
          ),
          Text('${musicStepMs.round()} ms', style: const TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isConnected ? null : connectBluetooth,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(80, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Conectar Bluetooth', style: TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: isConnected ? sendMusicConfig : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(80, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Aplicar configuración', style: TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(statusMsg, style: const TextStyle(color: Colors.purple, fontFamily: 'PressStart2P', fontSize: 10)),
      ],
    );
  }
}



class RainbowControlSection extends StatefulWidget {
  const RainbowControlSection({Key? key}) : super(key: key);
  @override
  State<RainbowControlSection> createState() => _RainbowControlSectionState();
}

class _RainbowControlSectionState extends State<RainbowControlSection> {
  double rainbowSpeed = 30; // ms entre pasos
  double rainbowBrightness = 100; // porcentaje
  BluetoothService btService = BluetoothService();
  String statusMsg = '';
  bool isConnected = false;

  Future<void> connectBluetooth() async {
    setState(() { statusMsg = 'Buscando dispositivos...'; });
    var devices = await btService.scanForDevices();
    if (devices.isNotEmpty) {
      bool ok = await btService.connectToDevice(devices.first);
      setState(() {
        isConnected = ok;
        statusMsg = ok ? 'Conectado a ${devices.first.name}' : 'No se pudo conectar';
      });
    } else {
      setState(() { statusMsg = 'No se encontraron dispositivos.'; });
    }
  }

  Future<void> sendRainbowConfig() async {
    if (btService.ledCharacteristic != null) {
      String msg = 'RAINBOW,${rainbowSpeed.round()},${rainbowBrightness.round()}';
      await btService.ble.writeCharacteristicWithResponse(
        btService.ledCharacteristic!,
        value: msg.codeUnits,
      );
      setState(() { statusMsg = 'Configuración enviada'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Modo Arcoíris', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.speed, color: Colors.green),
            const SizedBox(width: 8),
            Text('Velocidad', style: const TextStyle(fontSize: 12, fontFamily: 'PressStart2P')),
          ],
        ),
        Slider(
          min: 5,
          max: 2000,
          value: rainbowSpeed,
          onChanged: (v) => setState(() => rainbowSpeed = v),
          label: rainbowSpeed.round().toString(),
        ),
        Text('${rainbowSpeed.round()} ms', style: const TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.brightness_6, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Brillo', style: const TextStyle(fontSize: 12, fontFamily: 'PressStart2P')),
          ],
        ),
        Slider(
          min: 0,
          max: 100,
          value: rainbowBrightness,
          onChanged: (v) => setState(() => rainbowBrightness = v),
          label: '${rainbowBrightness.round()}%',
        ),
        Text('${rainbowBrightness.round()}%', style: const TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 300) {
              // Pantallas pequeñas: botones uno debajo del otro
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: isConnected ? null : connectBluetooth,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: const Size(70, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Conectar Bluetooth', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: isConnected ? sendRainbowConfig : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: const Size(70, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Aplicar configuración', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
                  ),
                ],
              );
            } else {
              // Pantallas normales: botones en fila, más pequeños
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: isConnected ? null : connectBluetooth,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: const Size(70, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Conectar Bluetooth', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isConnected ? sendRainbowConfig : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: const Size(70, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Aplicar configuración', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
                  ),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 8),
        Text(statusMsg, style: const TextStyle(color: Colors.purple, fontFamily: 'PressStart2P', fontSize: 10)),
      ],
    );
  }
}
