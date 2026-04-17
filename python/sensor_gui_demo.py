import os
import csv
import random
from datetime import datetime

import tkinter as tk
from tkinter import ttk, messagebox

from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure


DATA_FILE = "sensor_data.csv"


class SensorGUIDemo:
    def __init__(self, root):
        self.root = root
        self.root.title("FPGA Multi-Sensor Monitoring System")
        self.root.geometry("1200x800")

        self.is_running = False

        self.timestamp_var = tk.StringVar(value="--")
        self.status_var = tk.StringVar(value="System status: Idle")
        self.light_var = tk.StringVar(value="--")
        self.temp_var = tk.StringVar(value="--")
        self.humidity_var = tk.StringVar(value="--")
        self.pressure_var = tk.StringVar(value="--")

        self._ensure_data_file()
        self._build_gui()

    def _ensure_data_file(self):
        """Create CSV file with header if it does not exist."""
        if not os.path.exists(DATA_FILE):
            with open(DATA_FILE, "w", newline="") as f:
                writer = csv.writer(f)
                writer.writerow(["Timestamp", "Light", "Temperature", "Humidity", "Pressure"])

    def _build_gui(self):
        title_label = tk.Label(
            self.root,
            text="FPGA Multi-Sensor Monitoring System",
            font=("Arial", 20, "bold")
        )
        title_label.pack(pady=10)

        info_frame = tk.Frame(self.root)
        info_frame.pack(fill="x", padx=20, pady=5)

        tk.Label(info_frame, text="Last Sample Time:", font=("Arial", 11, "bold")).grid(row=0, column=0, sticky="w")
        tk.Label(info_frame, textvariable=self.timestamp_var, font=("Arial", 11)).grid(row=0, column=1, sticky="w", padx=10)

        tk.Label(info_frame, textvariable=self.status_var, font=("Arial", 11), fg="blue").grid(
            row=0, column=2, sticky="w", padx=30
        )

        button_frame = tk.Frame(self.root)
        button_frame.pack(pady=10)

        start_btn = tk.Button(
            button_frame,
            text="Start Acquisition",
            font=("Arial", 12, "bold"),
            width=18,
            command=self.start_acquisition
        )
        start_btn.grid(row=0, column=0, padx=10)

        stop_btn = tk.Button(
            button_frame,
            text="Stop Acquisition",
            font=("Arial", 12, "bold"),
            width=18,
            command=self.stop_acquisition
        )
        stop_btn.grid(row=0, column=1, padx=10)

        show_btn = tk.Button(
            button_frame,
            text="Show Today's Data",
            font=("Arial", 12, "bold"),
            width=18,
            command=self.show_today_data
        )
        show_btn.grid(row=0, column=2, padx=10)

        sensor_frame = tk.LabelFrame(self.root, text="Current Sensor Readings", font=("Arial", 12, "bold"))
        sensor_frame.pack(fill="x", padx=20, pady=10)

        self._create_sensor_box(sensor_frame, "Light Intensity", self.light_var, 0, 0)
        self._create_sensor_box(sensor_frame, "Temperature (°C)", self.temp_var, 0, 1)
        self._create_sensor_box(sensor_frame, "Humidity (%)", self.humidity_var, 1, 0)
        self._create_sensor_box(sensor_frame, "Pressure (hPa)", self.pressure_var, 1, 1)

        display_frame = tk.Frame(self.root)
        display_frame.pack(fill="both", expand=True, padx=20, pady=10)

        graph_frame = tk.LabelFrame(display_frame, text="Today's Trends", font=("Arial", 12, "bold"))
        graph_frame.pack(side="top", fill="both", expand=True, pady=5)

        self.figure = Figure(figsize=(10, 4), dpi=100)
        self.ax = self.figure.add_subplot(111)
        self.ax.set_title("Sensor Data")
        self.ax.set_xlabel("Sample Index")
        self.ax.set_ylabel("Value")

        self.canvas = FigureCanvasTkAgg(self.figure, master=graph_frame)
        self.canvas.draw()
        self.canvas.get_tk_widget().pack(fill="both", expand=True)

        table_frame = tk.LabelFrame(display_frame, text="Today's Data Table", font=("Arial", 12, "bold"))
        table_frame.pack(side="top", fill="both", expand=True, pady=5)

        columns = ("Timestamp", "Light", "Temperature", "Humidity", "Pressure")
        self.tree = ttk.Treeview(table_frame, columns=columns, show="headings", height=10)

        for col in columns:
            self.tree.heading(col, text=col)
            self.tree.column(col, anchor="center", width=150)

        scrollbar = ttk.Scrollbar(table_frame, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=scrollbar.set)

        self.tree.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

    def _create_sensor_box(self, parent, label_text, value_var, row, col):
        box = tk.Frame(parent, bd=2, relief="groove", padx=20, pady=15)
        box.grid(row=row, column=col, padx=15, pady=15, sticky="nsew")

        tk.Label(box, text=label_text, font=("Arial", 12, "bold")).pack()
        tk.Label(box, textvariable=value_var, font=("Arial", 18), fg="darkgreen").pack(pady=8)

        parent.grid_columnconfigure(col, weight=1)

    def generate_fake_data(self):
        """
        Generate one fake sensor sample.
        You can adjust the ranges to make the numbers look more realistic.
        """
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        light = random.randint(350, 850)
        temperature = round(random.uniform(22.0, 28.0), 1)
        humidity = round(random.uniform(35.0, 65.0), 1)
        pressure = round(random.uniform(1005.0, 1018.0), 1)
        return timestamp, light, temperature, humidity, pressure

    def save_to_csv(self, row):
        with open(DATA_FILE, "a", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(row)

    def start_acquisition(self):
        """
        Mode A:
        One click = one sample.
        """
        self.is_running = True
        self.status_var.set("System status: Acquiring one sample...")

        timestamp, light, temperature, humidity, pressure = self.generate_fake_data()

        self.timestamp_var.set(timestamp)
        self.light_var.set(str(light))
        self.temp_var.set(f"{temperature:.1f}")
        self.humidity_var.set(f"{humidity:.1f}")
        self.pressure_var.set(f"{pressure:.1f}")

        self.save_to_csv([timestamp, light, temperature, humidity, pressure])

        self.status_var.set("System status: Sample acquired successfully")

    def stop_acquisition(self):
        self.is_running = False
        self.status_var.set("System status: Stopped")

    def read_today_data(self):
        today_str = datetime.now().strftime("%Y-%m-%d")
        rows = []

        if not os.path.exists(DATA_FILE):
            return rows

        with open(DATA_FILE, "r", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                timestamp = row["Timestamp"]
                if timestamp.startswith(today_str):
                    rows.append(row)

        return rows

    def show_today_data(self):
        rows = self.read_today_data()

        for item in self.tree.get_children():
            self.tree.delete(item)

        if not rows:
            messagebox.showinfo("No Data", "No data recorded for today yet.")
            self.ax.clear()
            self.ax.set_title("Sensor Data")
            self.ax.set_xlabel("Sample Index")
            self.ax.set_ylabel("Value")
            self.canvas.draw()
            return

        sample_index = list(range(1, len(rows) + 1))
        light_vals = [float(r["Light"]) for r in rows]
        temp_vals = [float(r["Temperature"]) for r in rows]
        humidity_vals = [float(r["Humidity"]) for r in rows]
        pressure_vals = [float(r["Pressure"]) for r in rows]

        self.ax.clear()
        self.ax.plot(sample_index, light_vals, marker="o", label="Light")
        self.ax.plot(sample_index, temp_vals, marker="o", label="Temperature")
        self.ax.plot(sample_index, humidity_vals, marker="o", label="Humidity")
        self.ax.plot(sample_index, pressure_vals, marker="o", label="Pressure")
        self.ax.set_title("Today's Sensor Data")
        self.ax.set_xlabel("Sample Index")
        self.ax.set_ylabel("Value")
        self.ax.legend()
        self.ax.grid(True)
        self.canvas.draw()

        for row in rows:
            self.tree.insert(
                "",
                "end",
                values=(
                    row["Timestamp"],
                    row["Light"],
                    row["Temperature"],
                    row["Humidity"],
                    row["Pressure"]
                )
            )

        self.status_var.set("System status: Displaying today's data")


if __name__ == "__main__":
    root = tk.Tk()
    app = SensorGUIDemo(root)
    root.mainloop()