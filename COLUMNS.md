# How to open DuckDB in the terminal

DuckDB was installed with `winget install DuckDB.cli`, but `duckdb` may not be
on your PATH yet, so typing `duckdb` gives "not recognized." Fixes below.

### 1. Try the shortcut first
Open a **new** terminal (PATH is only read when a shell starts), then:
```powershell
duckdb
```
If that works, skip to step 3.

### 2. If "not recognized" — find the .exe and run it by full path
```powershell
Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet" -Recurse -Filter duckdb.exe | Select-Object FullName
```
That prints the full path, e.g.:
```
C:\Users\Admin\AppData\Local\Microsoft\WinGet\Packages\DuckDB.cli_...\duckdb.exe
```
Launch it by pasting that path with a leading `&`:
```powershell
& "C:\Users\Admin\AppData\Local\Microsoft\WinGet\Packages\DuckDB.cli_...\duckdb.exe"
```
(Optional, so `duckdb` works permanently: add that folder to PATH via
`System > Environment Variables > Path`, then reopen the terminal.)

### 3. Fix the display (Windows console) — once per session
```powershell
chcp 65001        # UTF-8, so table borders render instead of showing as Γöî
```
Then inside DuckDB, use ASCII output:
```sql
.mode markdown
```

### 4. Query the parquet directly (no import, no server)
```sql
SELECT YEAR, AGE, EMPSTAT, EDUC FROM 'data/cps.parquet' LIMIT 5;
DESCRIBE  SELECT * FROM 'data/cps.parquet';   -- column list + types
SUMMARIZE SELECT * FROM 'data/cps.parquet';   -- min/max/nulls per column
.read analyze.sql                             -- run the whole answer key
.quit                                         -- exit
```
Paging: long output shows `-- More --`; press **space** for more, **q** to stop.

### Zero-install fallback (no CLI needed)
```powershell
python
```
```python
import duckdb
duckdb.sql("SELECT YEAR, COUNT(*) FROM 'data/cps.parquet' GROUP BY YEAR")
exit()
```

---

# Column reference — CPS ASEC extract (`data/cps.parquet`)

18 columns. Most are bookkeeping; only ~8 matter for the analysis. Codes below
are from the DDI codebook (`data/cps_0000N.xml`), confirmed against the data.

## The 8 you actually query

| Column | Meaning | Codes / notes |
|---|---|---|
| **AGE** | Age at last birthday | Plain number. Young filter: `AGE BETWEEN 22 AND 27` |
| **SEX** | Sex | `1` male · `2` female · `9` NIU |
| **EMPSTAT** | Employment status (detailed) | `10` at work, `12` has job/not at work → **employed** · `20`,`21`,`22` → **unemployed** · `30`–`36` not in labor force |
| **LABFORCE** | In the labor force? (yes/no) | `2` yes (working or job-seeking) · `1` no · `0` NIU |
| **EDUC** | Highest education completed | `111` bachelor's · `123` master's · `124` professional · `125` doctorate → **grad = `EDUC >= 111`** |
| **INCWAGE** | Pre-tax wage/salary income, **previous calendar year** | Dollars. Exclude `99999998` & `99999999` (missing). In the 2024 survey this is 2023 earnings. |
| **OCC** | Occupation code | Numeric job-type code (for later degree-mismatch work) |
| **IND** | Industry code | Numeric sector code |

## The weight — makes numbers represent the population

| Column | Meaning | Notes |
|---|---|---|
| **ASECWT** | Person weight | "This respondent represents N real Americans." **Every rate multiplies by this.** Person-level analyses use ASECWT. |
| **ASECWTH** | Household weight | Household-level version. You do person-level work → ignore. |

## IDs & bookkeeping — mostly ignore

Two axes: **household vs person**, and **within one survey vs across surveys**.

| | Household | Person |
|---|---|---|
| **Within one survey** | `SERIAL` | `SERIAL` + `PERNUM` |
| **Across surveys (over time)** | `CPSID` | `CPSIDP` (`CPSIDV` = stricter, validated) |

- **YEAR** — survey year. **You DO use this** — it's your `GROUP BY YEAR` (2019 vs 2024).
- **MONTH** — interview month. All `3` (March ASEC). Ignore. `{Jan:1 … Dec:12}`
- **ASECFLAG** — `1` ASEC · `2` March Basic. All `1` here. Ignore.
- **SERIAL** — household ID, unique only *within* one survey (resets each year). Group by `YEAR, MONTH, SERIAL` to rebuild a household.
- **PERNUM** — person's slot within the household. `SERIAL + PERNUM` = one person in one survey.
- **CPSID / CPSIDP / CPSIDV** — track a household / person / validated-person *across* the CPS 4-8-4 re-interview pattern. For longitudinal work only — you compare snapshots, so ignore all three.

## Gotchas

1. **Employed = two codes:** `EMPSTAT IN (10, 12)`. Miss `12` (has job, out sick/vacation) and you undercount.
2. **Unemployment rate denominator is the labor force, not everyone:** `unemployed / in-labor-force (LABFORCE=2)`. People not looking for work aren't unemployed — they're out of the labor force.
3. **INCWAGE is last year's income.** In the 2024 file it's 2023 wages. Say "2023 wages" when precise.
4. **"Household" ≠ "family."** A household is everyone at one address (roommates included). The narrower family concept needs the `RELATE` variable, which isn't in this extract.

## Household reconstruction (bonus)

Because all members share `SERIAL`, you can rebuild a household:

```sql
SELECT YEAR, SERIAL,
  COUNT(*)                                            AS household_size,
  SUM(CASE WHEN EMPSTAT IN (10,12) THEN 1 ELSE 0 END) AS num_earners,
  MAX(AGE) AS oldest, MIN(AGE) AS youngest
FROM 'data/cps.parquet'
GROUP BY YEAR, SERIAL;
```

`num_earners` distinguishes single vs dual income (but can't tell a couple from
roommates without `RELATE`). Idea: "share of 22–27-year-olds still living in a
parent's household, 2019 vs 2024" — a distinctive angle on the broken-rung thesis.

## Not in this extract (add to a future download if needed)

- **UHRSWORKT** — usual hours/week. Needed for the part-time underemployment
  question (Q4 in `analyze.sql`). Missing from the current file.
- **RELATE** — relationship to household head. Needed for real household-structure
  questions (dual-income couple, kids living at home).
