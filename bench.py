"""
bench.py — time the SAME weighted aggregation (Q1) in pandas, so you can
compare against the Rust "cargo run --release" number for the README line.

Run:
    python bench.py
"""

import time
import pandas as pd

df = pd.read_parquet("data/cps.parquet")

t0 = time.perf_counter()
young = df[(df.AGE >= 22) & (df.AGE <= 27)]
num = young.loc[young.EMPSTAT.isin([20, 21, 22])].groupby("YEAR").ASECWT.sum()
den = young.loc[young.LABFORCE == 2].groupby("YEAR").ASECWT.sum()
rate = (100 * num / den).round(1)
elapsed = (time.perf_counter() - t0) * 1000

print(rate.rename("young_unemp_pct"))
print(f"\npandas aggregation: {elapsed:.1f} ms")
print("Compare with the Rust number from: cd agg-rs && cargo run --release")
