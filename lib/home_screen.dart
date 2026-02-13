import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'color_wheel_picker.dart';
import 'bluetooth_service.dart';

const Color kAccentColor = Color(0xFF00FFFF);
const Color kButtonBackground = Color(0xFF101010);
const Color kButtonBorder = Color(0xFF232323);

ButtonStyle buildAppButtonStyle({
  bool highlighted = false,
  EdgeInsetsGeometry? padding,
  Size? minSize,
}) {
  final style = ElevatedButton.styleFrom(
    backgroundColor: kButtonBackground,
    foregroundColor: kAccentColor,
    padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    minimumSize: minSize ?? const Size(110, 32),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    side: BorderSide(color: highlighted ? kAccentColor : kButtonBorder, width: 2),
    elevation: highlighted ? 4 : 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  return style.copyWith(
    animationDuration: const Duration(milliseconds: 140),
    overlayColor: MaterialStateProperty.resolveWith(
      (states) => states.contains(MaterialState.pressed) ? kAccentColor.withOpacity(0.2) : null,
    ),
  );
}

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
  bool showEasterEggImage = false;
  bool showEasterEggLink = false;
  final String easterEggImagePath = 'assets/emoji espia meme.jpg';
  final String easterEggLink = 'https://www.youtube.com/watch?v=N6JI6vi4ViI';

  void triggerEasterEgg() {
    setState(() {
      showEasterEggImage = true;
      showEasterEggLink = false;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        showEasterEggImage = false;
        showEasterEggLink = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          showEasterEggLink = false;
        });
      });
    });
  }

  void copyEasterEggLink() {
    Clipboard.setData(ClipboardData(text: easterEggLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado al portapapeles'), duration: Duration(seconds: 1)),
    );
  }
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
    return Scaffold(
      backgroundColor: const Color(0xFF040404),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeader(),
              const SizedBox(height: 28),
              _buildModeSelector(),
              const SizedBox(height: 32),
              if (selectedMode == 0)
                ManualControlSection(
                  btService: btService,
                  isConnected: isConnected,
                  showEasterEggImage: showEasterEggImage,
                  showEasterEggLink: showEasterEggLink,
                  easterEggImagePath: easterEggImagePath,
                  easterEggLink: easterEggLink,
                  onCopyLink: copyEasterEggLink,
                )
              else if (selectedMode == 1)
                MusicControlSection(btService: btService, isConnected: isConnected)
              else
                RainbowControlSection(btService: btService, isConnected: isConnected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final statusColor = isConnected ? const Color(0xFF00FFFF) : Colors.redAccent;
    return Column(
      children: [
        GestureDetector(
          onTap: triggerEasterEgg,
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[900]!),
            boxShadow: const [
              BoxShadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 12),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.joystick, color: Color(0xFF00FFFF), size: 20),
              const SizedBox(width: 10),
              const Text(
                'Ritmo RGB',
                style: TextStyle(fontFamily: 'PressStart2P', fontSize: 15, color: Color(0xFFEEEEEE)),
              ),
              const SizedBox(width: 10),
              const Icon(Symbols.music_note_2, color: Color(0xFF00FFFF), size: 20),
            ],
          ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onLongPress: triggerEasterEgg,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor, width: 1.4),
            ),
            child: Row(
              children: [
                Icon(Icons.bluetooth, color: statusColor, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isConnected ? 'Conectado a ESP32' : 'Desconectado',
                    style: TextStyle(fontFamily: 'PressStart2P', fontSize: 9, color: statusColor),
                  ),
                ),
                TextButton(
                  onPressed: connectBluetooth,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Reintentar', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 7)),
                ),
              ],
            ),
          ),
        ),
        if (statusMsg.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            statusMsg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 9, color: Colors.white70),
          ),
        ],
      ],
    );
  }

  Widget _buildModeSelector() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.view_comfy_alt, color: Color(0xFF00FFFF), size: 18),
            SizedBox(width: 8),
            Text('Modos', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16, color: Color(0xFFE5E5E5))),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: List.generate(modes.length, (index) {
            final selected = selectedMode == index;
            return ElevatedButton.icon(
              onPressed: () => setState(() => selectedMode = index),
              style: buildAppButtonStyle(
                highlighted: selected,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minSize: const Size(120, 36),
              ),
              icon: Icon(modes[index].icon, size: 16, color: kAccentColor),
              label: Text(
                modes[index].name,
                style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 9, color: kAccentColor),
              ),
            );
          }),
        ),
      ],
    );
  }
}



class ManualControlSection extends StatefulWidget {
  final BluetoothService btService;
  final bool isConnected;
  final bool showEasterEggImage;
  final bool showEasterEggLink;
  final String easterEggImagePath;
  final String easterEggLink;
  final VoidCallback onCopyLink;
  const ManualControlSection({
    Key? key,
    required this.btService,
    required this.isConnected,
    required this.showEasterEggImage,
    required this.showEasterEggLink,
    required this.easterEggImagePath,
    required this.easterEggLink,
    required this.onCopyLink,
  }) : super(key: key);
  @override
  State<ManualControlSection> createState() => _ManualControlSectionState();
}

class _ManualControlSectionState extends State<ManualControlSection> {
  Color selectedColor = Colors.blue;
  String statusMsg = '';
  bool dynamicChange = false;
  Timer? _colorSendTimer;

  Future<void> _sendColor(Color color, {bool dynamicTrigger = false}) async {
    if (!widget.isConnected) return;
    await widget.btService.sendColor(color);
    final hex = color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    setState(() {
      statusMsg = dynamicTrigger ? 'Color enviado dinámicamente' : 'Color enviado: #$hex';
    });
  }

  void _scheduleDynamicColorSend(Color color) {
    if (!widget.isConnected) return;
    _colorSendTimer?.cancel();
    _colorSendTimer = Timer(const Duration(milliseconds: 120), () {
      _sendColor(color, dynamicTrigger: true);
    });
  }

  @override
  void dispose() {
    _colorSendTimer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final manualApplyEnabled = widget.isConnected && !dynamicChange;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.palette, color: Color(0xFF00FFFF), size: 18),
            const SizedBox(width: 8),
            Text('Modo Manual', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16, color: const Color(0xFFEEEEEE))),
          ],
        ),
        const SizedBox(height: 16),
        ColorWheelPicker(
          initialColor: selectedColor,
          onColorChanged: (color) {
            setState(() => selectedColor = color);
            if (dynamicChange) {
              _scheduleDynamicColorSend(color);
            }
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: manualApplyEnabled ? () => _sendColor(selectedColor) : null,
              style: buildAppButtonStyle(highlighted: manualApplyEnabled && !dynamicChange),
              child: const Text('Aplicar color', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                setState(() => dynamicChange = !dynamicChange);
                if (!dynamicChange) {
                  _colorSendTimer?.cancel();
                } else {
                  _scheduleDynamicColorSend(selectedColor);
                }
              },
              style: buildAppButtonStyle(highlighted: dynamicChange),
              child: const Text('Cambio dinámico', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
            ),
          ],
        ),
        if (widget.showEasterEggImage)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                widget.easterEggImagePath,
                height: 140,
                width: double.infinity,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Text(
                    'Agrega tu imagen en ${widget.easterEggImagePath}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 10, color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        if (widget.showEasterEggLink)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A).withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00FFFF), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SelectableText(
                    widget.easterEggLink,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 9, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: widget.onCopyLink,
                    style: buildAppButtonStyle(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minSize: const Size(120, 32),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.copy, size: 12),
                        SizedBox(width: 6),
                        Text('Copiar enlace', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
  bool dynamicChange = false;
  Timer? _musicConfigTimer;

  Future<void> sendMusicConfig({bool dynamicTrigger = false}) async {
    if (!widget.isConnected) return;
    await widget.btService.sendMusicConfig(
      beatThreshold: beatThreshold,
      musicSubmode: musicSubmode,
      musicStepMs: musicStepMs,
    );
    setState(() { statusMsg = dynamicTrigger ? 'Configuración enviada dinámicamente' : 'Configuración enviada'; });
  }

  void _scheduleDynamicMusicSend() {
    if (!widget.isConnected) return;
    _musicConfigTimer?.cancel();
    _musicConfigTimer = Timer(const Duration(milliseconds: 150), () {
      sendMusicConfig(dynamicTrigger: true);
    });
  }

  void _updateMusicSubmode(int mode) {
    setState(() => musicSubmode = mode);
    if (dynamicChange) {
      _scheduleDynamicMusicSend();
    }
  }

  @override
  void dispose() {
    _musicConfigTimer?.cancel();
    super.dispose();
  }

  Widget _musicSubmodeButton(String label, int mode) {
    final highlighted = musicSubmode == mode;
    return ElevatedButton(
      onPressed: () => _updateMusicSubmode(mode),
      style: buildAppButtonStyle(
        highlighted: highlighted,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minSize: const Size(80, 32),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final musicApplyEnabled = widget.isConnected && !dynamicChange;
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, color: Color(0xFF00FFFF), size: 18),
            const SizedBox(width: 8),
            Text('Modo Música', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16, color: const Color(0xFFEEEEEE))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.surround_sound, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text('Sensibilidad', style: const TextStyle(fontSize: 12, fontFamily: 'PressStart2P')),
          ],
        ),
        Slider(
          min: 0,
          max: 2000,
          value: beatThreshold,
          onChanged: (v) {
            setState(() => beatThreshold = v);
            if (dynamicChange) {
              _scheduleDynamicMusicSend();
            }
          },
          label: beatThreshold.round().toString(),
        ),
        Row(
          children: const [
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('+ sensible', style: TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('- sensible', style: TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 300) {
              // Pantallas pequeñas: botones uno debajo del otro
              return Column(
                children: [
                  _musicSubmodeButton('Monocolor', 0),
                  const SizedBox(height: 6),
                  _musicSubmodeButton('Multicolor', 1),
                ],
              );
            } else {
              // Pantallas normales: botones en fila, más pequeños
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _musicSubmodeButton('Monocolor', 0),
                  const SizedBox(width: 8),
                  _musicSubmodeButton('Multicolor', 1),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 18),
        if (musicSubmode == 1) ...[
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
            max: 5000,
            value: musicStepMs,
            onChanged: (v) {
              setState(() => musicStepMs = v);
              if (dynamicChange) {
                _scheduleDynamicMusicSend();
              }
            },
            label: musicStepMs.round().toString(),
          ),
          Row(
            children: const [
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Rápido', style: TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
                ),
              ),
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('Lento', style: TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: musicApplyEnabled ? () => sendMusicConfig() : null,
              style: buildAppButtonStyle(highlighted: musicApplyEnabled),
              child: const Text('Aplicar configuración', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                setState(() => dynamicChange = !dynamicChange);
                if (dynamicChange) {
                  _scheduleDynamicMusicSend();
                } else {
                  _musicConfigTimer?.cancel();
                }
              },
              style: buildAppButtonStyle(highlighted: dynamicChange),
              child: const Text('Cambio dinámico', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
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
  bool dynamicChange = false;
  Timer? _rainbowConfigTimer;

  Future<void> sendRainbowConfig({bool dynamicTrigger = false}) async {
    if (!widget.isConnected) return;
    await widget.btService.sendRainbowConfig(
      rainbowSpeed: rainbowSpeed,
      rainbowBrightness: rainbowBrightness,
    );
    setState(() { statusMsg = dynamicTrigger ? 'Configuración enviada dinámicamente' : 'Configuración enviada'; });
  }

  void _scheduleDynamicRainbowSend() {
    if (!widget.isConnected) return;
    _rainbowConfigTimer?.cancel();
    _rainbowConfigTimer = Timer(const Duration(milliseconds: 150), () {
      sendRainbowConfig(dynamicTrigger: true);
    });
  }

  @override
  void dispose() {
    _rainbowConfigTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rainbowApplyEnabled = widget.isConnected && !dynamicChange;
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gradient, color: Color(0xFF00FFFF), size: 18),
            const SizedBox(width: 8),
            Text('Modo Arcoíris', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16, color: const Color(0xFFEEEEEE))),
          ],
        ),
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
          onChanged: (v) {
            setState(() => rainbowSpeed = v);
            if (dynamicChange) {
              _scheduleDynamicRainbowSend();
            }
          },
          label: rainbowSpeed.round().toString(),
        ),
        Row(
          children: const [
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Rápido', style: TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('Lento', style: TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
              ),
            ),
          ],
        ),
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
          onChanged: (v) {
            setState(() => rainbowBrightness = v);
            if (dynamicChange) {
              _scheduleDynamicRainbowSend();
            }
          },
          label: '${rainbowBrightness.round()}%',
        ),
        Text('${rainbowBrightness.round()}%', style: const TextStyle(fontSize: 10, fontFamily: 'PressStart2P')),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: rainbowApplyEnabled ? () => sendRainbowConfig() : null,
              style: buildAppButtonStyle(highlighted: rainbowApplyEnabled),
              child: const Text('Aplicar configuración', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                setState(() => dynamicChange = !dynamicChange);
                if (dynamicChange) {
                  _scheduleDynamicRainbowSend();
                } else {
                  _rainbowConfigTimer?.cancel();
                }
              },
              style: buildAppButtonStyle(highlighted: dynamicChange),
              child: const Text('Cambio dinámico', style: TextStyle(fontSize: 9, fontFamily: 'PressStart2P')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(statusMsg, style: const TextStyle(color: Colors.purple, fontFamily: 'PressStart2P', fontSize: 10)),
      ],
    );
  }
}
