# The Broken Bottom Rung

How are young workers really faring on the entry-level job market? A
Python → Parquet → DuckDB → Rust pipeline over real **IPUMS CPS** census
microdata, testing the claim that AI is breaking the bottom rung.

## The question

Recent-grad unemployment and underemployment are said to be climbing. Using
the March ASEC (the annual income-capable CPS supplement), how do workers aged
**22–27** compare with everyone else on employment, wages, and part-time work —
and is the gap widening from 2019 to 2024?

## Why this uses weights (the data-literacy point)

CPS is a **probability sample**, not a full census. Every record carries a
person weight, `ASECWT`, meaning "this person represents N real Americans."
Every rate here is `SUM(ASECWT) FILTER (condition) / SUM(ASECWT)`, never
`COUNT(*)` — otherwise the national numbers are simply wrong. That distinction
is the whole point.

## Pipeline

```
extract.py      IPUMS API  -> data2/cps_0000N.dat.gz + .xml   (fixed-width + DDI codebook)
to_parquet.py   .dat.gz+.xml -> data/cps.parquet             (clean, columnar, fast)
analyze.sql     8 weighted questions, run by run_sql.py       (DuckDB reads parquet directly)
agg-rs/         same Q1 aggregation in Rust                   (the speed benchmark)
bench.py        same Q1 in pandas                             (compare vs Rust)
```

## Run it

```bash
# 1. one-time: put your IPUMS key in .env  ->  IPUMS_API_KEY=xxxxx
python extract.py          # downloads the ASEC samples (already done -> data2/)

# 2. build the parquet
python to_parquet.py       # reads data2/, writes data/cps.parquet

# 3. answer the 8 questions
python run_sql.py

# 4. (optional) the Rust benchmark
python bench.py
cd agg-rs && cargo run --release
```

## Early findings (2019 → 2024, weighted)

| metric | 2019 | 2024 |
|---|---|---|
| Young (22–27) unemployment | 5.4% | 5.8% |
| All workers (22+) unemployment | 3.4% | 3.5% |
| Young college-grad median wage | $40,000 | $50,000 |

Young-worker unemployment sits well above the all-worker rate in both years —
the bottom rung is *lower*, and the question is whether the gap is widening.
Fill in the observation/interpretation lines in `analyze.sql` as you work
through each query.

## Honest framing

- CPS = population-level claims ("X% of young workers are unemployed").
- The LinkedIn postings set (later, optional) = texture only ("AI skills appear
  in Y% of postings") — it's a convenience sample, not representative.
- Wages are nominal (not inflation-adjusted); note that when presenting.
- Q4 part-time is a **proxy** for underemployment; CPS can't cleanly flag
  "job doesn't require the degree."

## Files

`config.yaml` variable list + code meanings · `extract.py` download ·
`to_parquet.py` convert · `analyze.sql` the 8 questions · `run_sql.py` runner ·
`agg-rs/` Rust aggregation · `bench.py` pandas timing.
