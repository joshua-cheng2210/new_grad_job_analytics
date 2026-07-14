-- analyze.sql — The Broken Bottom Rung : answer key
-- ---------------------------------------------------------------------------
-- Run with: python run_sql.py   (splits on the ";" and prints each result)
-- Data: data/cps.parquet  (built by to_parquet.py)
--
-- THE ONE RULE: a rate is SUM(ASECWT) FILTER (condition) / SUM(ASECWT),
-- never COUNT(*). CPS is a sample; ASECWT expands each person to the N real
-- people they represent. Every query below weights.
--
-- Codes (confirmed against the DDI on 2026-07-14):
--   EMPSTAT  employed = 10,12   unemployed = 20,21,22
--   LABFORCE in labor force = 2
--   EDUC     bachelor's or higher = >= 111
--   INCWAGE  exclude 99999998, 99999999 (and <=0)
--   UHRSWORKT full-time = >= 35 ; exclude 997 (varies) and 999 (NIU)
-- ===========================================================================

-- select YEAR, SERIAL, CPSID, CPSIDP, AGE, SEX, EMPSTAT, LABFORCE, OCC, IND, EDUC, INCWAGE from 'data/cps.parquet'

-- Q1. Weighted unemployment rate, young workers (22-27), by year.
--     Baseline of the whole project: is the bottom rung's rate rising?
SELECT YEAR,
  ROUND(100.0 *
    SUM(ASECWT) FILTER (WHERE EMPSTAT IN (20,21,22))
    / NULLIF(SUM(ASECWT) FILTER (WHERE LABFORCE = 2), 0), 1) AS young_unemp_pct
FROM 'data/cps.parquet'
WHERE AGE BETWEEN 22 AND 27
GROUP BY YEAR
ORDER BY YEAR;
-- Observation ->
-- Interpretation ->


-- Q2. Same rate for ALL workers (22+), by year -- the comparison line.
--     If Q1 rises faster than Q2, the young are being hit harder.
SELECT YEAR,
  ROUND(100.0 *
    SUM(ASECWT) FILTER (WHERE EMPSTAT IN (20,21,22))
    / NULLIF(SUM(ASECWT) FILTER (WHERE LABFORCE = 2), 0), 1) AS all_unemp_pct
FROM 'data/cps.parquet'
WHERE AGE >= 22
GROUP BY YEAR
ORDER BY YEAR;
-- Observation ->
-- Interpretation ->


-- Q3. Median annual wage, young college grads (22-27, bachelor's+), by year.
--     Are entry-level grad wages keeping up? (Nominal $, not inflation-adjusted.)
--     NOTE: MEDIAN() is unweighted. Within this narrow group weights vary
--     little, so it's a fair "typical wage." For a weighted central value use
--     the weighted MEAN in the commented line below.
SELECT YEAR,
  ROUND(MEDIAN(INCWAGE), 0)                                    AS median_wage,
  ROUND(SUM(INCWAGE * ASECWT) / SUM(ASECWT), 0)               AS weighted_mean_wage
FROM 'data/cps.parquet'
WHERE AGE BETWEEN 22 AND 27
  AND EDUC >= 111
  AND EMPSTAT IN (10, 12)                    -- employed only
  AND INCWAGE NOT IN (99999998, 99999999)
  AND INCWAGE > 0
GROUP BY YEAR
ORDER BY YEAR;
-- Observation ->
-- Interpretation ->


-- Q4. Underemployment proxy: share of EMPLOYED young grads working part-time
--     (usual hours < 35). CPS can't cleanly flag "job doesn't need a degree,"
--     so this is a PROXY and involuntary vs voluntary isn't separable here.
--     Call it a proxy when you present it.
SELECT YEAR,
  ROUND(100.0 *
    SUM(ASECWT) FILTER (WHERE UHRSWORKT < 35)
    / NULLIF(SUM(ASECWT), 0), 1) AS part_time_pct
FROM 'data/cps.parquet'
WHERE AGE BETWEEN 22 AND 27
  AND EDUC >= 111
  AND EMPSTAT IN (10, 12)
  AND UHRSWORKT NOT IN (997, 999)            -- drop "hours vary" and NIU
GROUP BY YEAR
ORDER BY YEAR;
-- Observation ->
-- Interpretation ->


-- Q5. Employment-to-population ratio, young workers (22-27), by year.
--     A different lens than unemployment: unemployment ignores people who
--     stopped looking; emp-pop ratio counts them as not-employed.
SELECT YEAR,
  ROUND(100.0 *
    SUM(ASECWT) FILTER (WHERE EMPSTAT IN (10, 12))
    / NULLIF(SUM(ASECWT), 0), 1) AS emp_pop_pct
FROM 'data/cps.parquet'
WHERE AGE BETWEEN 22 AND 27
GROUP BY YEAR
ORDER BY YEAR;
-- Observation ->
-- Interpretation ->


-- Q6. Wage gap: median wage of young grads (22-27) vs established grads
--     (35-50), by year. Is the gap widening?
SELECT YEAR,
  ROUND(MEDIAN(INCWAGE) FILTER (WHERE AGE BETWEEN 22 AND 27), 0) AS young_grad_wage,
  ROUND(MEDIAN(INCWAGE) FILTER (WHERE AGE BETWEEN 35 AND 50), 0) AS estab_grad_wage
FROM 'data/cps.parquet'
WHERE EDUC >= 111
  AND EMPSTAT IN (10, 12)
  AND INCWAGE NOT IN (99999998, 99999999)
  AND INCWAGE > 0
GROUP BY YEAR
ORDER BY YEAR;
-- Observation ->
-- Interpretation ->


-- Q7. Young unemployment (22-27) broken down by SEX, by year.
--     SEX: 1 = male, 2 = female.
SELECT YEAR,
  CASE SEX WHEN 1 THEN 'male' WHEN 2 THEN 'female' END AS sex,
  ROUND(100.0 *
    SUM(ASECWT) FILTER (WHERE EMPSTAT IN (20,21,22))
    / NULLIF(SUM(ASECWT) FILTER (WHERE LABFORCE = 2), 0), 1) AS unemp_pct
FROM 'data/cps.parquet'
WHERE AGE BETWEEN 22 AND 27
GROUP BY YEAR, SEX
ORDER BY YEAR, SEX;
-- Observation ->
-- Interpretation ->


-- Q8. THE PUNCHLINE: young vs all unemployment side by side, with the gap,
--     for each year. One table that answers "is the bottom rung breaking?"
WITH rates AS (
  SELECT YEAR,
    ROUND(100.0 *
      SUM(ASECWT) FILTER (WHERE EMPSTAT IN (20,21,22) AND AGE BETWEEN 22 AND 27)
      / NULLIF(SUM(ASECWT) FILTER (WHERE LABFORCE = 2 AND AGE BETWEEN 22 AND 27), 0), 1) AS young_pct,
    ROUND(100.0 *
      SUM(ASECWT) FILTER (WHERE EMPSTAT IN (20,21,22))
      / NULLIF(SUM(ASECWT) FILTER (WHERE LABFORCE = 2), 0), 1) AS all_pct
  FROM 'data/cps.parquet'
  WHERE AGE >= 22
  GROUP BY YEAR
)
SELECT YEAR, young_pct, all_pct,
       ROUND(young_pct - all_pct, 1) AS gap_points
FROM rates
ORDER BY YEAR;
-- Observation -> is gap_points larger in 2024 than 2019?
-- Interpretation -> a widening gap is the evidence the news claim predicts.
