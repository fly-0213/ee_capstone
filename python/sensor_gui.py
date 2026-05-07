import tkinter as tk
from tkinter import ttk
import serial
import threading
import csv
import os
from datetime import datetime

from matplotlib.figure import Figure
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg

# -----------------------------
# UART settings
# -----------------------------
PORT = "/dev/cu.usbserial-210183B30E651"
BAUD = 115200

HEAD_MAGIC = bytes([0xA5, 0xA5])
PACKET_LEN = 16

SHT30_ID = 0x1
MPL3115_ID = 0x2

CSV_FILE = "sensor_log.csv"

running = False
ser = None
buffer = bytearray()
send_start_after_open = False

records = []

# -----------------------------
# GUI setup
# -----------------------------
root = tk.Tk()
root.title("FPGA Sensor Monitor")
root.geometry("1000x750")

temp_var = tk.StringVar(value="-- °C")
hum_var = tk.StringVar(value="-- %")
press_var = tk.StringVar(value="-- Pa")
status_var = tk.StringVar(value="Idle")

frame = ttk.Frame(root, padding=15)
frame.pack(fill="both", expand=True)

ttk.Label(frame, text="Temperature:").grid(row=0, column=0, sticky="w")
ttk.Label(frame, textvariable=temp_var).grid(row=0, column=1, sticky="w")

ttk.Label(frame, text="Humidity:").grid(row=1, column=0, sticky="w")
ttk.Label(frame, textvariable=hum_var).grid(row=1, column=1, sticky="w")

ttk.Label(frame, text="Pressure:").grid(row=2, column=0, sticky="w")
ttk.Label(frame, textvariable=press_var).grid(row=2, column=1, sticky="w")

ttk.Label(frame, text="Status:").grid(row=3, column=0, sticky="w")
ttk.Label(frame, textvariable=status_var).grid(row=3, column=1, sticky="w")

# -----------------------------
# Plot setup
# -----------------------------
fig = Figure(figsize=(8, 4), dpi=100)
ax = fig.add_subplot(111)
ax.set_title("Sensor Trends")
ax.set_xlabel("Sample #")
ax.set_ylabel("Value")

canvas = FigureCanvasTkAgg(fig, master=frame)
canvas.get_tk_widget().grid(row=5, column=0, columnspan=4, pady=15)

# -----------------------------
# Hex box
# -----------------------------
hex_box = tk.Text(frame, height=10, width=115)
hex_box.grid(row=6, column=0, columnspan=4, pady=10)

# -----------------------------
# CSV helpers
# -----------------------------
def init_csv():
    if not os.path.exists(CSV_FILE):
        with open(CSV_FILE, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow([
                "pc_time",
                "fpga_timestamp",
                "temperature_c",
                "humidity_percent",
                "pressure_pa"
            ])

def save_csv(row):
    with open(CSV_FILE, "a", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(row)

# -----------------------------
# Plot update
# -----------------------------
def update_plot():
    ax.clear()
    ax.set_title("Sensor Trends")
    ax.set_xlabel("Sample #")
    ax.set_ylabel("Value")

    if len(records) < 2:
        ax.text(
            0.5, 0.5,
            "Need at least 2 samples to plot",
            ha="center",
            va="center",
            transform=ax.transAxes
        )
        canvas.draw()
        return

    x = list(range(1, len(records) + 1))

    temps = [r["temperature"] for r in records]
    hums = [r["humidity"] for r in records]
    presses = [r["pressure"] for r in records]

    if any(v is not None for v in temps):
        y = [v if v is not None else float("nan") for v in temps]
        ax.plot(x, y, marker="o", label="Temperature (°C)")
        for xi, yi in zip(x, y):
            if yi == yi:
                ax.annotate(f"{yi:.1f}", (xi, yi), textcoords="offset points", xytext=(0, 6), ha="center")

    if any(v is not None for v in hums):
        y = [v if v is not None else float("nan") for v in hums]
        ax.plot(x, y, marker="o", label="Humidity (%)")
        for xi, yi in zip(x, y):
            if yi == yi:
                ax.annotate(f"{yi:.1f}", (xi, yi), textcoords="offset points", xytext=(0, 6), ha="center")

    if any(v is not None for v in presses):
        y = [(v / 1000.0) if v is not None else float("nan") for v in presses]
        ax.plot(x, y, marker="o", label="Pressure (kPa)")
        for xi, yi in zip(x, y):
            if yi == yi:
                ax.annotate(f"{yi:.1f}", (xi, yi), textcoords="offset points", xytext=(0, 6), ha="center")

    ax.legend()
    ax.grid(True)
    canvas.draw()

# -----------------------------
# Packet parser
# -----------------------------
latest = {
    "temperature": None,
    "humidity": None,
    "pressure": None,
    "timestamp": None
}

def log_current_sample():
    if latest["temperature"] is None and latest["humidity"] is None and latest["pressure"] is None:
        return

    row = [
        datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        latest["timestamp"],
        latest["temperature"],
        latest["humidity"],
        latest["pressure"]
    ]

    save_csv(row)

    records.append({
        "temperature": latest["temperature"],
        "humidity": latest["humidity"],
        "pressure": latest["pressure"]
    })

    update_plot()

def parse_packet(pkt: bytes):
    packet_int = int.from_bytes(pkt, byteorder="big")

    head = (packet_int >> 112) & 0xFFFF
    sensor_id = (packet_int >> 108) & 0xF
    timestamp = (packet_int >> 76) & 0xFFFFFFFF
    data = (packet_int >> 24) & ((1 << 52) - 1)
    flag = (packet_int >> 16) & 0xFF

    if head != 0xA5A5:
        return

    latest["timestamp"] = timestamp
    status_var.set(f"Packet received | sensor={sensor_id} | ts={timestamp} | flag=0x{flag:02X}")

    if sensor_id == SHT30_ID:
        temp_raw = (data >> 16) & 0xFFFF
        hum_raw = data & 0xFFFF

        temperature = -45.0 + 175.0 * temp_raw / 65535.0
        humidity = 100.0 * hum_raw / 65535.0

        latest["temperature"] = temperature
        latest["humidity"] = humidity

        temp_var.set(f"{temperature:.2f} °C")
        hum_var.set(f"{humidity:.2f} %")

    elif sensor_id == MPL3115_ID:
        pressure_raw = (data >> 12) & 0xFFFFF
        temp_raw = data & 0xFFF

        pressure = pressure_raw / 4.0
        mpl_temp = temp_raw / 16.0

        latest["pressure"] = pressure
        press_var.set(f"{pressure:.2f} Pa")

        if latest["temperature"] is None:
            latest["temperature"] = mpl_temp
            temp_var.set(f"{mpl_temp:.2f} °C")

        log_current_sample()

# -----------------------------
# UART thread
# -----------------------------
def uart_worker():
    global running, ser, buffer, send_start_after_open

    try:
        ser = serial.Serial(PORT, BAUD, timeout=1)
        status_var.set("Listening...")

        if send_start_after_open:
            ser.write(b"S")
            send_start_after_open = False
            status_var.set("Listening... sent START to FPGA")

    except Exception as e:
        status_var.set(f"UART error: {e}")
        running = False
        return

    while running:
        try:
            data = ser.read(64)

            if data:
                hex_box.insert(tk.END, data.hex(" ") + "\n")
                hex_box.see(tk.END)

                buffer.extend(data)

                while True:
                    idx = buffer.find(HEAD_MAGIC)

                    if idx == -1:
                        if len(buffer) > 64:
                            buffer.clear()
                        break

                    if len(buffer) < idx + PACKET_LEN:
                        break

                    pkt = bytes(buffer[idx:idx + PACKET_LEN])
                    del buffer[:idx + PACKET_LEN]

                    parse_packet(pkt)

        except Exception as e:
            status_var.set(f"Read error: {e}")
            break

    try:
        if ser is not None and ser.is_open:
            ser.close()
    except Exception:
        pass

    status_var.set("Stopped")

# -----------------------------
# Button callbacks
# -----------------------------
def start_listening():
    global running, send_start_after_open

    if running:
        return

    running = True
    send_start_after_open = True
    status_var.set("Opening serial...")

    t = threading.Thread(target=uart_worker, daemon=True)
    t.start()

def stop_listening():
    global running, ser

    running = False

    try:
        if ser is not None and ser.is_open:
            ser.write(b"P")
    except Exception:
        pass

def clear_hex():
    hex_box.delete("1.0", tk.END)

def clear_plot():
    records.clear()
    update_plot()

# -----------------------------
# Buttons
# -----------------------------
ttk.Button(frame, text="Start Listening", command=start_listening).grid(row=4, column=0, pady=10)
ttk.Button(frame, text="Stop Listening", command=stop_listening).grid(row=4, column=1, pady=10)
ttk.Button(frame, text="Clear Hex", command=clear_hex).grid(row=4, column=2, pady=10)
ttk.Button(frame, text="Clear Plot", command=clear_plot).grid(row=4, column=3, pady=10)

init_csv()
update_plot()

root.mainloop()