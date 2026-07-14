// agg-rs — weighted aggregation on CPS Parquet, in Rust.
//
// Computes the SAME young-worker (22-27) unemployment rate as Q1 in
// analyze.sql, but by scanning data/cps.parquet directly and timing it.
// Purpose: the benchmark line -- "the Rust aggregation ran ~Nx faster than
// pandas." Run bench.py (Python side) and compare the printed millis.
//
// Rate = SUM(ASECWT) where unemployed / SUM(ASECWT) where in labor force.
//
// Run:
//   cd agg-rs
//   cargo run --release        (expects ../data/cps.parquet)

use std::time::Instant;
use polars::prelude::*;

fn main() -> PolarsResult<()> {
    let path = "../data/cps.parquet";
    let start = Instant::now();

    // Lazy scan: polars reads only the columns the query touches.
    let lf = LazyFrame::scan_parquet(path, ScanArgsParquet::default())?
        .filter(col("AGE").gt_eq(lit(22)).and(col("AGE").lt_eq(lit(27))));

    // Numerator: weight summed over unemployed (EMPSTAT in 20,21,22).
    let unemployed = col("EMPSTAT")
        .is_in(lit(Series::new("u".into(), [20i64, 21, 22])), false);
    // Denominator: weight summed over people in the labor force (LABFORCE = 2).
    let in_lf = col("LABFORCE").eq(lit(2));

    let out = lf
        .group_by([col("YEAR")])
        .agg([
            (col("ASECWT") * when(unemployed).then(lit(1.0)).otherwise(lit(0.0)))
                .sum()
                .alias("w_unemp"),
            (col("ASECWT") * when(in_lf).then(lit(1.0)).otherwise(lit(0.0)))
                .sum()
                .alias("w_lf"),
        ])
        .with_column(
            (col("w_unemp") / col("w_lf") * lit(100.0))
                .round(1)
                .alias("young_unemp_pct"),
        )
        .select([col("YEAR"), col("young_unemp_pct")])
        .sort(["YEAR"], SortMultipleOptions::default())
        .collect()?;

    let elapsed = start.elapsed();
    println!("{out}");
    println!("Rust aggregation: {:.1} ms", elapsed.as_secs_f64() * 1000.0);
    Ok(())
}
