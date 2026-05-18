import re
import time
from collections import deque

import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
import serial
from serial.tools import list_ports

# Ajusta este puerto si tu ESP32 aparece con otro nombre
PORT = "COM8"
BAUD = 115200

# Ventana de tiempo en segundos a mostrar
WINDOW_SECONDS = 30

# Deques para señal global (RMS)
MAX_POINTS = 2000

t_data = deque(maxlen=MAX_POINTS)
raw_rms_data = deque(maxlen=MAX_POINTS)
smoothed_rms_data = deque(maxlen=MAX_POINTS)
beat_times = []

# Deques para banda de graves (LOW band = índice 0 en el firmware)
band_t = deque(maxlen=MAX_POINTS)
band_flux = deque(maxlen=MAX_POINTS)
band_thr = deque(maxlen=MAX_POINTS)

start_time = time.time()
paused = False

# Log de beats (líneas verticales en el primer gráfico)
beat_log_file = None
last_beat_t = None
beat_dt_sum = 0.0
beat_dt_count = 0

# Screenshots automáticos
SCREENSHOT_INTERVAL_SEC = 10.0
last_screenshot_wall = None
auto_screenshot_index = 0

# Regex para las líneas de depuración del firmware
DBG_GLOBAL_RE = re.compile(
    r"^\[DBG\] RMSraw=(?P<raw>[-0-9\.]+) RMS=(?P<rms>[-0-9\.]+) "
    r"beat=(?P<beat>[01]) hold=(?P<hold>\d+) silent=(?P<silent>[01])"
)

DBG_BAND_RE = re.compile(
    r"^\[DBG\] Band (?P<idx>\d+) "
    r"flux=(?P<flux>[-0-9\.]+) thr=(?P<thr>[-0-9\.]+) "
    r"avg=(?P<avg>[-0-9\.]+) max=(?P<max>[-0-9\.]+)"
)


def open_serial(port: str, baud: int) -> serial.Serial:
    ser = serial.Serial(port, baud, timeout=1)
    ser.reset_input_buffer()
    return ser


fig, (ax1, ax2) = plt.subplots(2, 1, sharex=True)
fig.suptitle("music_led_2_1 - Modo música (RMS y banda LOW)")


def update(frame):
    global paused, last_screenshot_wall, auto_screenshot_index
    global beat_log_file, last_beat_t, beat_dt_sum, beat_dt_count
    if paused:
        return ax1, ax2

    now = time.time() - start_time

    # Leer varias líneas por frame
    for _ in range(80):
        try:
            raw_line = ser.readline()
        except serial.SerialException:
            continue

        if not raw_line:
            continue

        line = raw_line.decode(errors="ignore").strip()
        if not line:
            continue

        # Línea global de RMS / beat
        m_glob = DBG_GLOBAL_RE.match(line)
        if m_glob:
            try:
                raw_val = float(m_glob.group("raw"))
                rms_val = float(m_glob.group("rms"))
                beat_flag = int(m_glob.group("beat"))
            except ValueError:
                continue

            t_data.append(now)
            raw_rms_data.append(raw_val)
            smoothed_rms_data.append(rms_val)

            if beat_flag == 1:
                beat_times.append(now)

                # Registrar en el log este "beat" (línea vertical en el gráfico superior)
                if beat_log_file is not None:
                    # No guardar mediciones con dt = 0 (primer beat) ni dt negativos
                    if last_beat_t is None:
                        # Solo inicializamos el tiempo base; no se registra este beat
                        last_beat_t = now
                    else:
                        dt = now - last_beat_t
                        if dt > 0.0:
                            last_beat_t = now
                            beat_dt_sum += dt
                            beat_dt_count += 1
                            beat_log_file.write(
                                f"[BEAT] t={now:.3f} raw={raw_val:.3f} rms={rms_val:.3f} dt={dt:.3f}\n"
                            )
                            beat_log_file.flush()

            continue

        # Línea de banda (usamos sólo LOW band = idx 0 para graficar graves)
        m_band = DBG_BAND_RE.match(line)
        if m_band:
            try:
                idx = int(m_band.group("idx"))
                if idx != 0:
                    continue
                flux_val = float(m_band.group("flux"))
                thr_val = float(m_band.group("thr"))
            except ValueError:
                continue

            band_t.append(now)
            band_flux.append(flux_val)
            band_thr.append(thr_val)

            continue

    if not t_data:
        return ax1, ax2

    ax1.cla()
    ax2.cla()

    t_last = t_data[-1]
    t0 = max(0.0, t_last - WINDOW_SECONDS)

    # Gráfico superior: RMS crudo vs suavizado + beats
    ax1.plot(t_data, raw_rms_data, color="gray", alpha=0.5, label="RMS raw")
    ax1.plot(t_data, smoothed_rms_data, color="tab:orange", label="RMS smoothed")

    # Marcar beats como líneas verticales
    if beat_times:
        xs = [t for t in beat_times if t0 <= t <= t_last]
        if xs:
            ymin, ymax = ax1.get_ylim()
            for t in xs:
                ax1.axvline(t, color="tab:blue", alpha=0.3, linewidth=1.0)

    ax1.set_xlim(t0, t_last)
    ax1.set_ylabel("RMS")
    ax1.legend(loc="upper right")
    ax1.grid(True, alpha=0.3)

    # Gráfico inferior: banda LOW (flux y umbral)
    if band_t:
        ax2.plot(band_t, band_flux, color="magenta", label="LOW flux")
        ax2.plot(band_t, band_thr, color="red", linestyle="--", label="LOW thr")

    ax2.set_xlim(t0, t_last)
    ax2.set_ylabel("Flux LOW")
    ax2.set_xlabel("Tiempo (s)")
    ax2.legend(loc="upper right")
    ax2.grid(True, alpha=0.3)

    # Captura periódica de screenshots automáticos cada SCREENSHOT_INTERVAL_SEC
    now_wall = time.time()
    if last_screenshot_wall is None:
        last_screenshot_wall = now_wall
    elif (now_wall - last_screenshot_wall) >= SCREENSHOT_INTERVAL_SEC:
        auto_screenshot_index += 1
        last_screenshot_wall = now_wall

        filename = f"music_mode_snapshot_{auto_screenshot_index:03d}.png"
        import os
        script_dir = os.path.dirname(os.path.abspath(__file__))
        filepath = os.path.join(script_dir, filename)
        fig.savefig(filepath, dpi=150)
        print(f"[INFO] Screenshot automático guardado: {filepath}")

    return ax1, ax2


def on_key(event):
    global paused
    if event.key == "p":
        paused = not paused
        estado = "PAUSA" if paused else "EN MARCHA"
        print(f"[INFO] Estado de captura: {estado}")


if __name__ == "__main__":
    try:
        ser = open_serial(PORT, BAUD)
    except serial.SerialException as e:
        print(f"No se pudo abrir el puerto {PORT}: {e}")
        print("\nVerifica que:")
        print("  - Ningún monitor serie (PlatformIO, VS Code, Arduino IDE, etc.) esté usando ese puerto.")
        print("  - El ESP32 está conectado y aparece con ese COM en el Administrador de dispositivos.")
        print("\nPuertos serie disponibles detectados:")
        for p in list_ports.comports():
            print(f"  - {p.device}: {p.description}")
        raise SystemExit(1)

    # Abrir archivo de log para los beats (líneas verticales del gráfico superior)
    import os
    script_dir = os.path.dirname(os.path.abspath(__file__))
    log_path = os.path.join(script_dir, "music_mode_beats_log.txt")
    beat_log_file = open(log_path, "w", encoding="utf-8")
    beat_log_file.write("# Log de beats (líneas verticales en el gráfico RMS)\n")
    beat_log_file.write("# t: tiempo en segundos desde inicio del script\n")
    beat_log_file.write("# raw: RMS raw en ese instante\n")
    beat_log_file.write("# rms: RMS suavizado en ese instante\n")
    beat_log_file.write("# dt: diferencia de tiempo desde el beat anterior (s)\n")

    print(f"Leyendo datos de {PORT} @ {BAUD} baud...")
    print("Cierra la ventana para detener el script. Pulsa 'p' para pausar/reanudar.")

    ani = FuncAnimation(fig, update, interval=100)
    fig.canvas.mpl_connect("key_press_event", on_key)
    plt.tight_layout()

    try:
        plt.show()
    finally:
        # Al cerrar la ventana, escribir promedio de dt entre beats y cerrar el log
        if beat_log_file is not None:
            if beat_dt_count > 0:
                avg_dt = beat_dt_sum / beat_dt_count
                beat_log_file.write(
                    f"# Promedio dt entre beats: {avg_dt:.3f} s (n={beat_dt_count})\n"
                )
            beat_log_file.close()
