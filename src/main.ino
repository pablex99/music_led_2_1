#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <arduinoFFT.h>

// Callback para reiniciar advertising tras desconexión BLE
class MyServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    Serial.println("[BLE] Dispositivo conectado");
  }
  void onDisconnect(BLEServer* pServer) {
    Serial.println("[BLE] Dispositivo desconectado, reiniciando advertising");
    BLEDevice::getAdvertising()->start();
  }
};

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <arduinoFFT.h>

// ===============================
// CONFIGURACIÓN DE PINES
// ===============================
const int micPin = 35;      // Entrada del micrófono (MAX9814 OUT)
const int redPin = 26;      // PWM para canal Rojo
const int greenPin = 27;    // PWM para canal Verde  
const int bluePin = 33;     // PWM para canal Azul

// ===============================
// VARIABLES DE MODOS DE OPERACIÓN
// ===============================
bool musicMode = false;     // Modo reactivo a música
bool rainbowMode = false;   // Modo arcoíris automático
bool manualMode = true;     // Modo manual (activo por defecto)

// ===============================
// VARIABLES PARA MODO ARCOÍRIS
// ===============================
unsigned long lastColorChange = 0;
int rainbowHue = 0;
unsigned long rainbowIntervalMs = 30; // default 30ms per step
float rainbowBrightness = 1.0; // 1.0 = 100%

// ===============================
// CONFIGURACIÓN FFT (ANÁLISIS DE AUDIO)
// ===============================
const int samples = 512;
const double samplingFrequency = 4000.0;
double vReal[samples];
double vImag[samples];
ArduinoFFT<double> FFT(vReal, vImag, samples, samplingFrequency);

// ===============================
// CONFIGURACIÓN PWM
// ===============================
const int pwmFreq = 5000;
const int pwmResolution = 8;
const int pwmMax = 255;
const int redChannel = 0;
const int greenChannel = 1;
const int blueChannel = 2;

// ===============================
// VARIABLES PARA DETECCIÓN DE BEAT
// ===============================
double prevLowEnergy = 0; // kept for compatibility with older logic
double avgLowEnergy = 0;
const double smoothingFactor = 0.9;
double prevMag[samples/2];
double avgFlux = 0.0;
const double fluxSmoothing = 0.85;
float beatSensitivity = 1.6;
unsigned long lastBeatTime = 0;
const int beatHoldTime = 150;
double beatThreshold = 400.0;

// ===============================
// CONFIG MUSIC SUBMODE + MULTICOLOR
// ===============================
int musicSubmode = 0; // 0 = monocolor, 1 = multicolor
unsigned long musicStepMs = 200; // ms per color step in multicolor mode
int musicHue = 0;
unsigned long lastMusicStepTime = 0;

// ===============================
// VARIABLES DE COLOR MANUAL Y MÚSICA
// ===============================
int redVal = 0, greenVal = 0, blueVal = 0;
int musicRed = 0, musicGreen = 0, musicBlue = 255;

// BLE UUIDs
#define SERVICE_UUID        "0000ffe0-0000-1000-8000-00805f9b34fb"
#define CHARACTERISTIC_UUID "0000ffe1-0000-1000-8000-00805f9b34fb"

BLECharacteristic *pCharacteristic;


void setColor(int r, int g, int b) {
  redVal = r; greenVal = g; blueVal = b;
  ledcWrite(redChannel, redVal);
  ledcWrite(greenChannel, greenVal);
  ledcWrite(blueChannel, blueVal);
}

void applyColor(int r, int g, int b) {
  ledcWrite(redChannel, r);
  ledcWrite(greenChannel, g);
  ledcWrite(blueChannel, b);
}

void detectBeatAndReact() {
  static unsigned long lastSampleTime = 0;
  unsigned long now = micros();
  if (now - lastSampleTime < (1000000.0 / samplingFrequency)) return;
  lastSampleTime = now;
  double avg = 0;
  for (int i = 0; i < samples; i++) {
    vReal[i] = analogRead(micPin);
    avg += vReal[i];
    vImag[i] = 0;
    delayMicroseconds(50);
  }
  avg /= samples;
  for (int i = 0; i < samples; i++) {
    vReal[i] -= avg;
  }
  FFT.windowing(FFT_WIN_TYP_HAMMING, FFT_FORWARD);
  FFT.compute(FFT_FORWARD);
  FFT.complexToMagnitude();
  double flux = 0.0;
  int lowBin = 2;
  int highBin = samples / 8;
  if (highBin >= samples/2) highBin = samples/2 - 1;
  for (int i = lowBin; i <= highBin; i++) {
    double mag = vReal[i];
    double diff = mag - prevMag[i];
    if (diff > 0) flux += diff;
    prevMag[i] = mag;
  }
  avgFlux = fluxSmoothing * avgFlux + (1.0 - fluxSmoothing) * flux;
  bool beatDetected = false;
  if (avgFlux > 0.0 && flux > (avgFlux * beatSensitivity) && (millis() - lastBeatTime > beatHoldTime)) {
    beatDetected = true;
    lastBeatTime = millis();
    int rv = constrain(musicRed, 0, pwmMax);
    int gv = constrain(musicGreen, 0, pwmMax);
    int bv = constrain(musicBlue, 0, pwmMax);
    ledcWrite(redChannel, rv);
    ledcWrite(greenChannel, gv);
    ledcWrite(blueChannel, bv);
  }
  if (beatDetected) {
    // already wrote the chosen music color above
  } else {
    int fade = map(millis() - lastBeatTime, 0, beatHoldTime, 255, 0);
    fade = constrain(fade, 0, 255);
    float f = fade / 255.0;
    int rv = (int)constrain(musicRed * f, 0, pwmMax);
    int gv = (int)constrain(musicGreen * f, 0, pwmMax);
    int bv = (int)constrain(musicBlue * f, 0, pwmMax);
    ledcWrite(redChannel, rv);
    ledcWrite(greenChannel, gv);
    ledcWrite(blueChannel, bv);
  }
}

void applyRainbowColor(int hue) {
  float r, g, b;
  int region = hue / 60;
  float f = (hue / 60.0) - region;
  float q = 1 - f;
  switch(region) {
    case 0: r=1; g=f; b=0; break;
    case 1: r=q; g=1; b=0; break;
    case 2: r=0; g=1; b=f; break;
    case 3: r=0; g=q; b=1; break;
    case 4: r=f; g=0; b=1; break;
    default: r=1; g=0; b=q; break;
  }
  int rv = (int)(r * 255 * rainbowBrightness);
  int gv = (int)(g * 255 * rainbowBrightness);
  int bv = (int)(b * 255 * rainbowBrightness);
  rv = constrain(rv, 0, pwmMax);
  gv = constrain(gv, 0, pwmMax);
  bv = constrain(bv, 0, pwmMax);
  ledcWrite(redChannel, rv);
  ledcWrite(greenChannel, gv);
  ledcWrite(blueChannel, bv);
}

void hsvHueToRgbInt(int hue, int &outR, int &outG, int &outB, float brightness=1.0f) {
  float r,g,b;
  int region = hue / 60;
  float f = (hue / 60.0) - region;
  float q = 1 - f;
  switch(region) {
    case 0: r=1; g=f; b=0; break;
    case 1: r=q; g=1; b=0; break;
    case 2: r=0; g=1; b=f; break;
    case 3: r=0; g=q; b=1; break;
    case 4: r=f; g=0; b=1; break;
    default: r=1; g=0; b=q; break;
  }
  outR = (int)constrain(r * 255.0 * brightness, 0, pwmMax);
  outG = (int)constrain(g * 255.0 * brightness, 0, pwmMax);
  outB = (int)constrain(b * 255.0 * brightness, 0, pwmMax);
}

void setManualMode() {
  manualMode = true;
  musicMode = false;
  rainbowMode = false;
}

void setMusicMode() {
  manualMode = false;
  musicMode = true;
  rainbowMode = false;
}

void setRainbowMode() {
  manualMode = false;
  musicMode = false;
  rainbowMode = true;
}

class MyCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    std::string value = pCharacteristic->getValue();
    if (value.length() > 0) {
      Serial.print("[BLE] Comando recibido: ");
      Serial.println(value.c_str());
      // Espera comandos tipo: MANUAL,R,G,B | MUSIC,thresh,submode,step | RAINBOW,speed,brightness
      if (value.find("MANUAL,") == 0) {
        int r, g, b;
        sscanf(value.c_str(), "MANUAL,%d,%d,%d", &r, &g, &b);
        Serial.printf("[BLE] Modo MANUAL: R=%d G=%d B=%d\n", r, g, b);
        setManualMode();
        setColor(r, g, b);
      } else if (value.find("MUSIC,") == 0) {
        setMusicMode();
        int thresh = 400, submode = 0, step = 200;
        sscanf(value.c_str(), "MUSIC,%d,%d,%d", &thresh, &submode, &step);
        Serial.printf("[BLE] Modo MUSIC: thresh=%d submode=%d step=%d\n", thresh, submode, step);
        beatThreshold = thresh;
        musicSubmode = submode;
        musicStepMs = step;
      } else if (value.find("RAINBOW,") == 0) {
        setRainbowMode();
        int speed = 30;
        int bright = 100;
        sscanf(value.c_str(), "RAINBOW,%d,%d", &speed, &bright);
        Serial.printf("[BLE] Modo RAINBOW: speed=%d bright=%d\n", speed, bright);
        rainbowIntervalMs = speed;
        rainbowBrightness = bright / 100.0;
      } else {
        Serial.println("[BLE] Comando no reconocido");
      }
    }
  }
};

void setup() {
  Serial.begin(115200);
  // PWM
  ledcSetup(redChannel, pwmFreq, pwmResolution);
  ledcSetup(greenChannel, pwmFreq, pwmResolution);
  ledcSetup(blueChannel, pwmFreq, pwmResolution);
  ledcAttachPin(redPin, redChannel);
  ledcAttachPin(greenPin, greenChannel);
  ledcAttachPin(bluePin, blueChannel);
  setColor(0, 0, 0);

  // BLE
  BLEDevice::init("MusicLED-ESP32");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  // Añadir descriptor BLE2902 para compatibilidad con apps BLE
  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setCallbacks(new MyCallbacks());
  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  // Incluir el UUID del servicio en el anuncio BLE
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x06);  // Compatibilidad iOS
  pAdvertising->setMinPreferred(0x12);  // Compatibilidad iOS
  pAdvertising->start();
}

void loop() {
  if (musicMode) {
    unsigned long currentMillis = millis();
    if (musicSubmode == 1) {
      if (currentMillis - lastMusicStepTime > musicStepMs) {
        lastMusicStepTime = currentMillis;
        musicHue = (musicHue + 1) % 360;
        int r,g,b;
        hsvHueToRgbInt(musicHue, r, g, b, rainbowBrightness);
        musicRed = r; musicGreen = g; musicBlue = b;
      }
    }
    detectBeatAndReact();
  }
  else if (rainbowMode) {
    unsigned long currentMillis = millis();
    if (currentMillis - lastColorChange > rainbowIntervalMs) {
      rainbowHue = (rainbowHue + 1) % 360;
      applyRainbowColor(rainbowHue);
      lastColorChange = currentMillis;
    }
  }
  else if (manualMode) {
    applyColor(redVal, greenVal, blueVal);
  }
  delay(5);
}
