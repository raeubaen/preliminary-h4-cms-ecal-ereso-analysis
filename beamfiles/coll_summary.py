#!/usr/bin/env python3

import pandas as pd
from zoneinfo import ZoneInfo


# ============================================================
# File di input/output
# ============================================================

COLLIMATOR_FILE = "log_collimators.csv"
RUN_FILE = "timestamps_runs.txt"
OUTPUT_FILE = "run_collimators.csv"

# Timezone
UTC = ZoneInfo("UTC")
GENEVA = ZoneInfo("Europe/Zurich")


# ============================================================
# 1. Leggi il log dei collimatori
# ============================================================

df_col = pd.read_csv(COLLIMATOR_FILE)

# Il timestamp del log è UTC
df_col["timestamp"] = pd.to_datetime(
    df_col["Timestamp (UTC_TIME)"],
    utc=True
)

# Ordina cronologicamente
df_col = df_col.sort_values("timestamp").reset_index(drop=True)


# ============================================================
# 2. Leggi i run
# ============================================================

runs = []

with open(RUN_FILE, "r") as f:
    for line in f:
        line = line.strip()

        if not line:
            continue

        # Esempio:
        # Jun 5 05:06 20269
        #
        # split -> ["Jun", "5", "05:06", "20269"]
        parts = line.split()

        if len(parts) != 4:
            print(f"ATTENZIONE: riga non riconosciuta: {line}")
            continue

        print(parts)

        month = parts[0]
        day = parts[1]
        time = parts[2]
        run_number = parts[3]

        # I run sono del 2026
        date_string = f"2026 {month} {day} {time}"

        # Timestamp locale di Ginevra
        timestamp_local = pd.Timestamp(
            date_string,
            tz="Europe/Zurich"
        )

        # Convertiamo in UTC per confrontarlo con il log
        timestamp_utc = timestamp_local.tz_convert("UTC")

        runs.append({
            "numero_run": int(run_number),
            "timestamp_local": timestamp_local,
            "timestamp_utc": timestamp_utc,
        })


df_runs = pd.DataFrame(runs)

df_runs = df_runs.sort_values("timestamp_utc").reset_index(drop=True)


# ============================================================
# 3. Associa ogni run all'ultimo setting disponibile
# ============================================================

# merge_asof:
# per ogni run cerca l'ultimo timestamp del log collimatori
# <= timestamp del run

df = pd.merge_asof(
    df_runs,
    df_col,
    left_on="timestamp_utc",
    right_on="timestamp",
    direction="backward"
)

# Timestamp del setting del collimatore associato al run
df["collimatore_timestamp_utc"] = df["timestamp"]

# Converti il timestamp del collimatore in ora locale GVA
df["collimatore_timestamp_gva"] = (
    df["timestamp"].dt.tz_convert("Europe/Zurich")
)

# ============================================================
# 4. Seleziona i collimatori che ci interessano
# ============================================================

output = df[[
    "numero_run",

    # Timestamp del run
    "timestamp_local",
    "timestamp_utc",

    # Timestamp del setting del collimatore
    "collimatore_timestamp_gva",
    "collimatore_timestamp_utc",

    # Settings
    "XCHV.022.131 _JAW1_REF",
    "XCHV.022.131 _JAW2_REF",
    "XCHV.022.197 _JAW1_REF",
    "XCHV.022.197 _JAW2_REF",
]].copy()

# Rinomina le colonne
output = output.rename(columns={
    "XCHV.022.131 _JAW1_REF": "collimatore131x",
    "XCHV.022.131 _JAW2_REF": "collimatore131y",
    "XCHV.022.197 _JAW1_REF": "collimatore197x",
    "XCHV.022.197 _JAW2_REF": "collimatore197y",
})


# ============================================================
# 5. Salva CSV
# ============================================================

output.to_csv(
    OUTPUT_FILE,
    index=False
)

print(f"Creato: {OUTPUT_FILE}")
print()
print(output.head(20).to_string(index=False))
