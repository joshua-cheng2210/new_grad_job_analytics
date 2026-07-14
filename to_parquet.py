"""
to_parquet.py
-------------
Step 2->3 of the pipeline: turn the awkward IPUMS download
(.dat.gz fixed-width data + .xml DDI codebook) into ONE clean Parquet file
that DuckDB and Rust can both read directly.

Why Parquet: it's a compressed, column-oriented table format. Our queries
touch a few columns out of 19, and Parquet reads only those columns off disk
instead of every field of every row. It's also the format IPUMS/ISRDI actually
use, so it's a real resume signal.

Run:
    python to_parquet.py                 # auto-picks the newest extract
    python to_parquet.py data2           # or point at a specific folder

Output: data/cps.parquet
"""

import sys
from pathlib import Path
from ipumspy import readers

OUT = Path("data") / "cps.parquet"


def find_extract(search_dir: Path) -> Path:
    """Return the .xml (DDI codebook) in search_dir. ipumspy finds the
    matching .dat.gz automatically, so we only need the .xml path."""
    xmls = sorted(search_dir.glob("*.xml"))
    if not xmls:
        raise FileNotFoundError(f"No .xml codebook found in {search_dir}/")
    # Newest by extract number (cps_00004.xml > cps_00003.xml)
    return xmls[-1]


def main() -> None:
    # Which folder holds the download? default 'data2' (the complete extract),
    # override on the command line.
    search_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("data2")
    xml_path = find_extract(search_dir)
    print(f"Reading codebook: {xml_path}")

    ddi = readers.read_ipums_ddi(str(xml_path))
    ipums_df = readers.read_microdata(ddi, str(xml_path).replace(".xml", ".dat.gz"))

    # --- sanity check: fail loudly if the weight is missing ---------------
    print(f"Rows x cols : {ipums_df.shape}")
    print(f"Columns     : {list(ipums_df.columns)}")
    print(f"Years        : {sorted(ipums_df['YEAR'].unique().tolist())}")
    if "ASECWT" not in ipums_df.columns:
        raise SystemExit(
            "FATAL: ASECWT (person weight) is missing. Every rate would be "
            "unweighted and wrong. Re-run extract.py with ASECWT in the list."
        )

    OUT.parent.mkdir(exist_ok=True)
    ipums_df.to_parquet(OUT)
    print(f"\nWrote {OUT}  ({OUT.stat().st_size/1e6:.1f} MB)")
    print("Next: python run_sql.py")


if __name__ == "__main__":
    main()
