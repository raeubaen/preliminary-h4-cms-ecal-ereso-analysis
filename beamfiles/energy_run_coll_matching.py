#!/usr/bin/env python3

import pandas as pd
import argparse


def main():
    parser = argparse.ArgumentParser(
        description="Associa energia/resistenza ai run e aggiunge le coordinate dei collimatori."
    )
    parser.add_argument("energy_csv", help="CSV con Energy,Runs_dash_separated,Resistance")
    parser.add_argument("collimator_csv", help="CSV con number_run e coordinate collimatori")
    parser.add_argument(
        "-o",
        "--output",
        default="energy_runs_collimators.csv",
        help="CSV di output (default: energy_runs_collimators.csv)",
    )

    args = parser.parse_args()

    # ------------------------------------------------------------
    # 1. CSV energia/run/resistenza
    # ------------------------------------------------------------
    energy_df = pd.read_csv(args.energy_csv)

    required_energy = {"Energy", "Runs_dash_separated", "Resistance"}
    missing = required_energy - set(energy_df.columns)
    if missing:
        raise ValueError(
            f"Nel CSV delle energie mancano le colonne: {sorted(missing)}"
        )

    # Una riga per ogni run
    energy_df["run"] = energy_df["Runs_dash_separated"].str.split("-")
    energy_df = energy_df.explode("run")

    energy_df["run"] = pd.to_numeric(
        energy_df["run"], errors="raise"
    ).astype(int)

    energy_df["Energy"] = pd.to_numeric(energy_df["Energy"], errors="raise")
    energy_df["Resistance"] = pd.to_numeric(
        energy_df["Resistance"], errors="raise"
    )

    energy_df = energy_df[["Energy", "run", "Resistance"]]

    # ------------------------------------------------------------
    # 2. CSV collimatori
    # ------------------------------------------------------------
    coll_df = pd.read_csv(args.collimator_csv)

    required_coll = {
        "number_run",
        "collimatore131x",
        "collimatore131y",
        "collimatore197x",
        "collimatore197y",
    }

    missing = required_coll - set(coll_df.columns)
    if missing:
        raise ValueError(
            f"Nel CSV dei collimatori mancano le colonne: {sorted(missing)}"
        )

    coll_df["number_run"] = pd.to_numeric(
        coll_df["number_run"], errors="raise"
    ).astype(int)

    coll_df = coll_df[
        [
            "number_run",
            "collimatore131x",
            "collimatore131y",
            "collimatore197x",
            "collimatore197y",
        ]
    ]

    # Controllo eventuali run duplicati nel file collimatori
    duplicated = coll_df[
        coll_df["number_run"].duplicated(keep=False)
    ]

    if not duplicated.empty:
        print("ATTENZIONE: run duplicati nel CSV dei collimatori:")
        print(duplicated.to_string(index=False))

    # ------------------------------------------------------------
    # 3. Merge run -> coordinate collimatori
    # ------------------------------------------------------------
    output = energy_df.merge(
        coll_df,
        left_on="run",
        right_on="number_run",
        how="left",
    )

    output = output.drop(columns=["number_run"])

    # ------------------------------------------------------------
    # 4. Controllo run senza informazioni sui collimatori
    # ------------------------------------------------------------
    missing_coll = output[
        output[
            [
                "collimatore131x",
                "collimatore131y",
                "collimatore197x",
                "collimatore197y",
            ]
        ].isna().any(axis=1)
    ]

    if not missing_coll.empty:
        print(
            f"\nATTENZIONE: {len(missing_coll)} run non hanno "
            "informazioni sui collimatori:"
        )
        print(missing_coll[["Energy", "run", "Resistance"]].to_string(index=False))

    # ------------------------------------------------------------
    # 5. Ordina e salva
    # ------------------------------------------------------------
    output = output.sort_values(["Resistance", "Energy", "run"])

    output.to_csv(args.output, index=False)

    print(f"\nCreato: {args.output}")
    print(f"Numero di righe: {len(output)}")


if __name__ == "__main__":
    main()
