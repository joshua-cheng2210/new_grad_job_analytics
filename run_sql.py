"""
run_sql.py
----------
Runs analyze.sql against data/cps.parquet with DuckDB and prints each
query's result. No database server, no import step: DuckDB queries the
Parquet file directly ('data/cps.parquet' IS the table).

Run:
    python run_sql.py
"""

from pathlib import Path
import duckdb

SQL_FILE = Path("analyze.sql")
PARQUET = Path("data/cps.parquet")


def split_statements(text: str):
    """Split analyze.sql into individual statements, keeping the leading
    comment block above each so we can print it as a header."""
    blocks, current = [], []
    for line in text.splitlines():
        current.append(line)
        if line.strip().endswith(";"):
            blocks.append("\n".join(current))
            current = []
    return [b for b in blocks if b.strip()]


def header_for(block: str) -> str:
    """Grab the first '-- Qn.' comment line as a title."""
    for line in block.splitlines():
        s = line.strip()
        if s.startswith("-- Q"):
            return s.lstrip("- ").strip()
    return "query"


def main() -> None:
    if not PARQUET.exists():
        raise SystemExit("data/cps.parquet not found. Run: python to_parquet.py")

    con = duckdb.connect()
    statements = split_statements(SQL_FILE.read_text(encoding="utf-8"))

    for block in statements:
        sql = "\n".join(l for l in block.splitlines()
                        if not l.strip().startswith("--"))
        if not sql.strip():
            continue
        print("\n" + "=" * 70)
        print(header_for(block))
        print("=" * 70)
        print(con.sql(sql))


if __name__ == "__main__":
    main()
