#!/usr/bin/env python3

from pathlib import Path

import pandas as pd


def quast_stats(quast_output_dir):
    """
    Returns:
        A dictionary containing the length in bp (key: length), number of
        contigs (key: contigs), N50 value (key: N50) and GC content over 1
        (key: GC).

    Raises:
        ValueError: Dataframe does not have exactly 1 row.
    """
    transposed_report_tsv = Path(quast_output_dir) / "transposed_report.tsv"
    df = pd.read_table(transposed_report_tsv)

    if len(df) != 1:
        raise ValueError(f"Dataframe should have 1 row\nNumber of rows: {len(df)}")

    return {
        "assembly length": int(df["Total length"][0]),
        "contigs": int(df["# contigs"][0]),
        "N50": int(df["N50"][0]),
        "GC": float(df["GC (%)"][0] / 100),
    }


# df = pd.read_table(
#     "~/Documents/NUS/UROPS/server-data/S8E_3_1/assembly_eval/quast/transposed_report.tsv"
# )
# print(quast_stats(df))
