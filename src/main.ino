
// ===============================
// INCLUDES
// ===============================
#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <arduinoFFT.h>
#include <vector>

// ===============================
// DEFINES Y UUIDs BLE
// ===============================
#define SERVICE_UUID        "0000ffe0-0000-1000-8000-00805f9b34fb"
#define CHARACTERISTIC_UUID "0000ffe1-0000-1000-8000-00805f9b34fb"

// ===============================
// CONFIGURACIÓN DE PINES
// ===============================
const int micPin = 35;      // Entrada del micrófono (MAX9814 OUT)
const int redPin = 26;      // PWM para canal Rojo
const int greenPin = 27;    // PWM para canal Verde
const int bluePin = 33;     // PWM para canal Azul

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
// CONFIGURACIÓN FFT (ANÁLISIS DE AUDIO)
// ===============================
const int samples = 512;
const double samplingFrequency = 4000.0;
const unsigned long samplingPeriodUs = static_cast<unsigned long>(1000000.0 / samplingFrequency);
double vReal[samples];
double vImag[samples];
ArduinoFFT<double> FFT(vReal, vImag, samples, samplingFrequency);

struct FluxBandState {
  int lowBin;
  int highBin;
  double avgFlux;
  double maxFlux;
};

const int NUM_FLUX_BANDS = 3;
FluxBandState fluxBands[NUM_FLUX_BANDS] = {
  {8, 18, 0.0, 0.0},   // ~60-140 Hz
  {19, 32, 0.0, 0.0},  // ~148-250 Hz
  {33, 48, 0.0, 0.0},  // ~257-375 Hz
};
const double bandFluxSmoothing = 0.82;
const double bandMaxDecay = 0.92;
const double bandSensitivity[NUM_FLUX_BANDS] = {1.35, 1.45, 1.55};

// ===============================
// VARIABLES DE MODOS DE OPERACIÓN
// ===============================
bool musicMode = false;
bool rainbowMode = false;
bool manualMode = true;

// ===============================
// VARIABLES PARA MODO ARCOÍRIS
// ===============================
unsigned long lastColorChange = 0;
int rainbowHue = 0;
unsigned long rainbowIntervalMs = 30;
float rainbowBrightness = 1.0f;

// ===============================
// VARIABLES PARA DETECCIÓN DE BEAT
// ===============================
double prevMag[samples / 2];
float beatSensitivity = 1.0f; // factor global aplicado a los umbrales multibanda
unsigned long lastBeatTime = 0;
const int beatHoldTime = 150;
double beatThreshold = 400.0;
unsigned long lastBeatFlashOn = 0;
const int beatFlashDuration = 80;
float rollingBeatIntervalMs = 0.0f;
unsigned long lastAudioActiveMs = 0;
const float silenceRawRmsFloor = 90.0f;
const unsigned long silenceReleaseMs = 650;

// ===============================
// CONFIG MUSIC SUBMODE + MULTICOLOR
// ===============================
int musicSubmode = 0; // 0 = monocolor, 1 = multicolor
unsigned long musicStepMs = 200;
int musicHue = 0;
unsigned long lastMusicStepTime = 0;

// ===============================
// VARIABLES DE COLOR MANUAL Y MÚSICA
// ===============================
int redVal = 0, greenVal = 0, blueVal = 0;
int musicRed = 0, musicGreen = 0, musicBlue = 255;

// ===============================
// OBJETOS BLE
// ===============================
BLECharacteristic *pCharacteristic = nullptr;

// ===============================
// PROTOTIPOS
// ===============================
void detectBeatAndReact();
void setManualMode();
void setMusicMode();
void setRainbowMode();
void setColor(int r, int g, int b);
void applyColor(int r, int g, int b);
void applyRainbowColor(int hue);
void hsvHueToRgbInt(int hue, int &outR, int &outG, int &outB, float brightness = 1.0f);

// ===============================
// UTILIDADES
// ===============================
std::vector<String> split(const String &str, char sep) {
  std::vector<String> tokens;
  int start = 0;
  int idx = str.indexOf(sep, start);
  while (idx >= 0) {
    tokens.push_back(str.substring(start, idx));
    start = idx + 1;
    idx = str.indexOf(sep, start);
  }
  tokens.push_back(str.substring(start));
  return tokens;
}

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) override {
    Serial.println("[BLE] Dispositivo conectado");
  }

  void onDisconnect(BLEServer *pServer) override {
    Serial.println("[BLE] Dispositivo desconectado");
    pServer->startAdvertising();
  }
};

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pChar) override {
    std::string rxValue = pChar->getValue();
    if (rxValue.empty()) return;

    if (rxValue.length() == 3) {
      int r = static_cast<uint8_t>(rxValue[0]);
      int g = static_cast<uint8_t>(rxValue[1]);
      int b = static_cast<uint8_t>(rxValue[2]);
      setColor(r, g, b);
      musicRed = r;
      musicGreen = g;
      musicBlue = b;
      setManualMode();
      Serial.printf("[BLE] Color manual: %d,%d,%d\n", r, g, b);
      return;
    }

    String cmd = String(rxValue.c_str());
    cmd.trim();
    auto parts = split(cmd, ',');
    if (parts.empty()) return;

    if (parts[0] == "MANUAL" && parts.size() >= 4) {
      int r = parts[1].toInt();
      int g = parts[2].toInt();
      int b = parts[3].toInt();
      setColor(r, g, b);
      setManualMode();
      Serial.printf("[BLE] MANUAL comando: %d,%d,%d\n", r, g, b);
    } else if (parts[0] == "MUSIC" && parts.size() >= 4) {
      beatThreshold = parts[1].toDouble();
      float mappedSensitivity = parts[1].toFloat() / 400.0f;
      beatSensitivity = constrain(mappedSensitivity, 0.6f, 3.5f);
      musicSubmode = parts[2].toInt();
      musicSubmode = constrain(musicSubmode, 0, 1);
      musicStepMs = max(5UL, static_cast<unsigned long>(parts[3].toInt()));
      setMusicMode();
      Serial.printf("[BLE] MUSIC sens=%.2f sub=%d step=%lu\n", beatSensitivity, musicSubmode, musicStepMs);
    } else if (parts[0] == "RAINBOW" && parts.size() >= 3) {
      rainbowIntervalMs = max(5UL, static_cast<unsigned long>(parts[1].toInt()));
      int bright = parts[2].toInt();
      rainbowBrightness = constrain(bright / 100.0f, 0.05f, 1.0f);
      rainbowHue = 0;
      setRainbowMode();
      Serial.printf("[BLE] RAINBOW speed=%lu brightness=%.2f\n", rainbowIntervalMs, rainbowBrightness);
    } else if (parts[0] == "COLOR" && parts.size() >= 4) {
      int r = parts[1].toInt();
      int g = parts[2].toInt();
      int b = parts[3].toInt();
      setColor(r, g, b);
      setManualMode();
      Serial.printf("[BLE] COLOR comando: %d,%d,%d\n", r, g, b);
    } else {
      Serial.println("[BLE] Comando no reconocido");
    }
  }
};

// ===============================
// FUNCIONES DE COLOR Y MODOS
// ===============================
void setColor(int r, int g, int b) {
  redVal = constrain(r, 0, pwmMax);
  greenVal = constrain(g, 0, pwmMax);
  blueVal = constrain(b, 0, pwmMax);
  applyColor(redVal, greenVal, blueVal);
}

void applyColor(int r, int g, int b) {
  ledcWrite(redChannel, constrain(r, 0, pwmMax));
  ledcWrite(greenChannel, constrain(g, 0, pwmMax));
  ledcWrite(blueChannel, constrain(b, 0, pwmMax));
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
  lastBeatFlashOn = millis();
}

void setRainbowMode() {
  manualMode = false;
  musicMode = false;
  rainbowMode = true;
  lastColorChange = millis();
}

// ===============================
// FUNCIONES DE COLOR (HSV/RGB, RAINBOW)
// ===============================
void applyRainbowColor(int hue) {
  float r, g, b;
  int region = hue / 60;
  float f = (hue / 60.0f) - region;
  float q = 1.0f - f;
  switch (region) {
    case 0: r = 1; g = f; b = 0; break;
    case 1: r = q; g = 1; b = 0; break;
    case 2: r = 0; g = 1; b = f; break;
    case 3: r = 0; g = q; b = 1; break;
    case 4: r = f; g = 0; b = 1; break;
    default: r = 1; g = 0; b = q; break;
  }
  int rv = static_cast<int>(r * 255.0f * rainbowBrightness);
  int gv = static_cast<int>(g * 255.0f * rainbowBrightness);
  int bv = static_cast<int>(b * 255.0f * rainbowBrightness);
  applyColor(rv, gv, bv);
}

void hsvHueToRgbInt(int hue, int &outR, int &outG, int &outB, float brightness) {
  float r, g, b;
  int region = hue / 60;
  float f = (hue / 60.0f) - region;
  float q = 1.0f - f;
  switch (region) {
    case 0: r = 1; g = f; b = 0; break;
    case 1: r = q; g = 1; b = 0; break;
    case 2: r = 0; g = 1; b = f; break;
    case 3: r = 0; g = q; b = 1; break;
    case 4: r = f; g = 0; b = 1; break;
    default: r = 1; g = 0; b = q; break;
  }
  outR = static_cast<int>(constrain(r * 255.0f * brightness, 0.0f, static_cast<float>(pwmMax)));
  outG = static_cast<int>(constrain(g * 255.0f * brightness, 0.0f, static_cast<float>(pwmMax)));
  outB = static_cast<int>(constrain(b * 255.0f * brightness, 0.0f, static_cast<float>(pwmMax)));
}

// ===============================
// FUNCIONES DE AUDIO Y BEAT
// ===============================
void detectBeatAndReact() {
  static unsigned long nextSampleTime = micros();
  static float smoothedRms = 0.0f;
  static float smoothedRawRms = 0.0f;

  for (int i = 0; i < samples; ++i) {
    while ((micros() - nextSampleTime) < samplingPeriodUs) {
      // Esperar al siguiente instante de muestreo (mantiene 4 kHz exactos)
    }
    nextSampleTime += samplingPeriodUs;
    double sample = analogRead(micPin);
    vReal[i] = sample;
    vImag[i] = 0;
  }

  double mean = 0;
  for (int i = 0; i < samples; ++i) {
    mean += vReal[i];
  }
  mean /= samples;

  double maxAbs = 1.0;
  double sumSquares = 0.0;
  for (int i = 0; i < samples; ++i) {
    double centered = vReal[i] - mean;
    vReal[i] = centered;
    double absVal = fabs(centered);
    if (absVal > maxAbs) maxAbs = absVal;
    sumSquares += centered * centered;
  }

  double rawRms = sqrt(sumSquares / samples);
  double agcGain = 1300.0 / maxAbs;
  agcGain = constrain(agcGain, 0.35, 8.0);
  for (int i = 0; i < samples; ++i) {
    vReal[i] *= agcGain;
  }

  double rms = rawRms * agcGain;
  if (smoothedRms == 0.0f) {
    smoothedRms = rms;
  } else {
    smoothedRms = 0.85f * smoothedRms + 0.15f * rms;
  }
  if (smoothedRawRms == 0.0f) {
    smoothedRawRms = rawRms;
  } else {
    smoothedRawRms = 0.9f * smoothedRawRms + 0.1f * rawRms;
  }
  float beatBrightness = constrain(smoothedRms / 900.0f, 0.2f, 1.0f);

  unsigned long nowMs = millis();
  if (smoothedRawRms > silenceRawRmsFloor) {
    lastAudioActiveMs = nowMs;
  }
  bool audioSilent = (nowMs - lastAudioActiveMs) > silenceReleaseMs;
  if (audioSilent) {
    if ((nowMs - lastBeatFlashOn) > beatFlashDuration) {
      applyColor(0, 0, 0);
    }
    for (int i = 0; i < samples / 2; ++i) {
      prevMag[i] *= 0.6;
    }
    for (int idx = 0; idx < NUM_FLUX_BANDS; ++idx) {
      fluxBands[idx].avgFlux *= bandFluxSmoothing;
      fluxBands[idx].maxFlux *= bandMaxDecay;
    }
    return;
  }

  FFT.windowing(FFT_WIN_TYP_HAMMING, FFT_FORWARD);
  FFT.compute(FFT_FORWARD);
  FFT.complexToMagnitude();

  nowMs = millis();
  int dynamicHold = beatHoldTime;
  if (rollingBeatIntervalMs > 5.0f) {
    dynamicHold = max(dynamicHold, static_cast<int>(rollingBeatIntervalMs * 0.35f));
  }

  bool beatDetected = false;
  for (int idx = 0; idx < NUM_FLUX_BANDS; ++idx) {
    FluxBandState &band = fluxBands[idx];
    double bandFlux = 0.0;
    int low = max(2, band.lowBin);
    int high = min(band.highBin, (samples / 2) - 1);
    for (int bin = low; bin <= high; ++bin) {
      double mag = vReal[bin];
      double diff = mag - prevMag[bin];
      if (diff > 0) {
        bandFlux += diff;
      }
      prevMag[bin] = mag;
    }

    double smoothed = bandFluxSmoothing * band.avgFlux + (1.0 - bandFluxSmoothing) * bandFlux;
    band.avgFlux = smoothed;
    band.maxFlux = max(bandFlux, band.maxFlux * bandMaxDecay);

    double baseThreshold = band.avgFlux * bandSensitivity[idx] * beatSensitivity;
    double peakThreshold = band.maxFlux * 0.55;
    double threshold = max(baseThreshold, peakThreshold);

    if (bandFlux > threshold && (nowMs - lastBeatTime) > static_cast<unsigned long>(dynamicHold)) {
      beatDetected = true;
    }
  }

  if (beatDetected) {
    if (lastBeatTime > 0) {
      float interval = nowMs - lastBeatTime;
      if (rollingBeatIntervalMs <= 0.1f) {
        rollingBeatIntervalMs = interval;
      } else {
        rollingBeatIntervalMs = rollingBeatIntervalMs * 0.7f + interval * 0.3f;
      }
    }
    lastBeatTime = nowMs;
    lastBeatFlashOn = nowMs;

    float brightness = beatBrightness;
    if (musicSubmode == 1) {
      brightness *= rainbowBrightness;
    }
    brightness = constrain(brightness, 0.15f, 1.0f);

    int rv = static_cast<int>(musicRed * brightness);
    int gv = static_cast<int>(musicGreen * brightness);
    int bv = static_cast<int>(musicBlue * brightness);
    applyColor(rv, gv, bv);
  } else if ((nowMs - lastBeatFlashOn) > beatFlashDuration) {
    applyColor(0, 0, 0);
  }
}

// ===============================
// SETUP Y LOOP PRINCIPAL
// ===============================
void setup() {
  Serial.begin(115200);
  analogReadResolution(12);

  ledcSetup(redChannel, pwmFreq, pwmResolution);
  ledcAttachPin(redPin, redChannel);
  ledcSetup(greenChannel, pwmFreq, pwmResolution);
  ledcAttachPin(greenPin, greenChannel);
  ledcSetup(blueChannel, pwmFreq, pwmResolution);
  ledcAttachPin(bluePin, blueChannel);
  setColor(0, 0, 0);
  lastAudioActiveMs = millis();

  BLEDevice::init("MusicLED-ESP32");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setCallbacks(new MyCallbacks());
  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  pAdvertising->start();
  Serial.println("[BLE] Esperando conexión...");
}

void loop() {
  unsigned long currentMillis = millis();

  if (musicMode) {
    if (musicSubmode == 1 && (currentMillis - lastMusicStepTime) > musicStepMs) {
      lastMusicStepTime = currentMillis;
      musicHue = (musicHue + 1) % 360;
      int r, g, b;
      hsvHueToRgbInt(musicHue, r, g, b, rainbowBrightness);
      musicRed = r;
      musicGreen = g;
      musicBlue = b;
    }
    detectBeatAndReact();
  } else if (rainbowMode) {
    if (currentMillis - lastColorChange > rainbowIntervalMs) {
      rainbowHue = (rainbowHue + 1) % 360;
      applyRainbowColor(rainbowHue);
      lastColorChange = currentMillis;
    }
  } else if (manualMode) {
    applyColor(redVal, greenVal, blueVal);
  }

  delay(2);
}
