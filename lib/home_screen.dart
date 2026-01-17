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
  BluetoothService btService = BluetoothService();
  bool isConnected = false;
  String statusMsg = '';

  @override
  void initState() {
    super.initState();
    connectBluetooth();
  }

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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF000000),
            Color(0xFF0A0A0A),
            Color(0xFF002B36),
            Color(0xFF000000),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Controlador RGB'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(modes.length, (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ElevatedButton(
                      onPressed: () => setState(() => selectedMode = i),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(modes[i].icon, size: 16, color: const Color(0xFF00FFFF)),
                          const SizedBox(width: 4),
                          Text(modes[i].name, style: const TextStyle(fontSize: 10, fontFamily: 'PressStart2P', color: Color(0xFF00FFFF))),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedMode == i ? const Color(0xFF002B36) : Colors.grey[900],
                        foregroundColor: const Color(0xFF00FFFF),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        minimumSize: const Size(80, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: selectedMode == i ? const Color(0xFF00FFFF) : Colors.transparent, width: 2),
                        elevation: selectedMode == i ? 6 : 0,
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: 32),
                Text(statusMsg, style: const TextStyle(color: Color(0xFF00FFFF), fontFamily: 'PressStart2P', fontSize: 10)),
                if (selectedMode == 0) ManualControlSection(btService: btService, isConnected: isConnected),
                if (selectedMode == 1) MusicControlSection(btService: btService, isConnected: isConnected),
                if (selectedMode == 2) RainbowControlSection(btService: btService, isConnected: isConnected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



class ManualControlSection extends StatefulWidget {
  final BluetoothService btService;
  final bool isConnected;
  const ManualControlSection({Key? key, required this.btService, required this.isConnected}) : super(key: key);
  @override
  State<ManualControlSection> createState() => _ManualControlSectionState();
}

class _ManualControlSectionState extends State<ManualControlSection> {
  Color selectedColor = Colors.blue;
  String statusMsg = '';


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
              onPressed: widget.isConnected
                  ? () async {
                      await widget.btService.sendColor(selectedColor);
                      setState(() { statusMsg = 'Color enviado: #${selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}'; });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: const Size(70, 26),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Aplicar color', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P', color: Color(0xFF00FFFF))),
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
  final BluetoothService btService;
  final bool isConnected;
  const MusicControlSection({Key? key, required this.btService, required this.isConnected}) : super(key: key);
  @override
  State<MusicControlSection> createState() => _MusicControlSectionState();
}

class _MusicControlSectionState extends State<MusicControlSection> {
  double beatThreshold = 400;
  int musicSubmode = 0; // 0 = monocolor, 1 = multicolor
  double musicStepMs = 200;
  String statusMsg = '';


  Future<void> sendMusicConfig() async {
    await widget.btService.sendMusicConfig(
      beatThreshold: beatThreshold,
      musicSubmode: musicSubmode,
      musicStepMs: musicStepMs,
    );
    setState(() { statusMsg = 'Configuración enviada'; });
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
        ElevatedButton(
          onPressed: widget.isConnected ? sendMusicConfig : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minimumSize: const Size(70, 26),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Aplicar configuración', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P', color: Color(0xFF00FFFF))),
        ),
        const SizedBox(height: 8),
        Text(statusMsg, style: const TextStyle(color: Colors.purple, fontFamily: 'PressStart2P', fontSize: 10)),
      ],
    );
  }
}



class RainbowControlSection extends StatefulWidget {
  final BluetoothService btService;
  final bool isConnected;
  const RainbowControlSection({Key? key, required this.btService, required this.isConnected}) : super(key: key);
  @override
  State<RainbowControlSection> createState() => _RainbowControlSectionState();
}

class _RainbowControlSectionState extends State<RainbowControlSection> {
  double rainbowSpeed = 30; // ms entre pasos
  double rainbowBrightness = 100; // porcentaje
  String statusMsg = '';


  Future<void> sendRainbowConfig() async {
    await widget.btService.sendRainbowConfig(
      rainbowSpeed: rainbowSpeed,
      rainbowBrightness: rainbowBrightness,
    );
    setState(() { statusMsg = 'Configuración enviada'; });
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
        ElevatedButton(
          onPressed: widget.isConnected ? sendRainbowConfig : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minimumSize: const Size(70, 26),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Aplicar configuración', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P', color: Color(0xFF00FFFF))),
        ),
        const SizedBox(height: 8),
        Text(statusMsg, style: const TextStyle(color: Colors.purple, fontFamily: 'PressStart2P', fontSize: 10)),
      ],
    );
  }
}
