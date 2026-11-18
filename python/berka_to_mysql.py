"""
Berka Bank Dataset -> MySQL loader
==================================

What this script does
    1. Reads the raw Berka files (.asc / .csv / .txt) from a local folder.
    2. Cleans them: Czech -> English labels, date parsing, gender and age from the
       birth number, duplicate and orphan removal, missing-value handling.
    3. Loads the cleaned tables into MySQL with primary keys, foreign keys and indexes.

Final table names (source file -> MySQL table)
    disp   -> authorization      (client <-> account link, disp_type OWNER / DISPONENT)
    trans  -> transactions
    order  -> orders
    all other tables keep their original name

The tables are created under their final names directly, so no RENAME TABLE step is
needed afterwards and the SQL validation file runs as-is.

Setup
    pip install pandas numpy sqlalchemy pymysql

Configuration (environment variables, with the defaults shown)
    BERKA_FOLDER       folder that contains the raw Berka files
    BERKA_DB_HOST      localhost
    BERKA_DB_PORT      3306
    BERKA_DB_USER      root
    BERKA_DB_PASSWORD  (asked at run time if not set)
    BERKA_DB_NAME      bank_analytics
"""

import getpass
import os
import sys

import numpy as np
import pandas as pd

# =====================================================================
# CONFIGURATION
# =====================================================================
FOLDER = os.getenv("BERKA_FOLDER", r"C:\path\to\data_berka\data")
DB_HOST = os.getenv("BERKA_DB_HOST", "localhost")
DB_PORT = int(os.getenv("BERKA_DB_PORT", "3306"))
DB_USER = os.getenv("BERKA_DB_USER", "root")
DB_PASSWORD = os.getenv("BERKA_DB_PASSWORD", "")
DB_NAME = os.getenv("BERKA_DB_NAME", "bank_analytics")

# Safe by default: never drop a database or replace existing tables unless explicitly opted in.
ALLOW_TABLE_REPLACE = os.getenv("BERKA_ALLOW_TABLE_REPLACE", "NO").strip().upper() == "YES"
REF_DATE = pd.Timestamp("1998-12-31")       # reference date used to calculate client age

# Table names used by earlier versions of this script. They are dropped on load
# so an old database can never keep a stale copy next to the renamed tables.
LEGACY_TABLES = ("disp", "trans")

# =====================================================================
# LOOKUPS: Czech -> English
# =====================================================================
NULL_TOKENS = {"", "?", "NULL", "null", "Null", "nan", "NaN", "NA", "N/A", "None", "none", "-"}
NOT_SPECIFIED = "Not Specified"

FREQUENCY_MAP = {
    "POPLATEK MESICNE": "Monthly",
    "POPLATEK TYDNE": "Weekly",
    "POPLATEK PO OBRATU": "After Transaction",
}
TRANS_TYPE_MAP = {"PRIJEM": "Credit", "VYDAJ": "Debit", "VYBER": "Debit"}
OPERATION_MAP = {
    "VYBER KARTOU": "Credit Card Withdrawal",
    "VKLAD": "Cash Deposit",
    "PREVOD Z UCTU": "Incoming Bank Transfer",
    "VYBER": "Cash Withdrawal",
    "PREVOD NA UCET": "Outgoing Bank Transfer",
}
K_SYMBOL_MAP = {
    "POJISTNE": "Insurance Payment",
    "SLUZBY": "Statement Fee",
    "UROK": "Interest Credited",
    "SANKC. UROK": "Penalty Interest",
    "SIPO": "Household Payment",
    "DUCHOD": "Pension Credit",
    "UVER": "Loan Payment",
    "LEASING": "Leasing",
}
LOAN_STATUS_MAP = {
    "A": "Finished - Paid",
    "B": "Finished - Not Paid",
    "C": "Running - OK",
    "D": "Running - In Debt",
}

REPORT = {}   # per-table cleaning statistics, filled during run_cleaning()


# =====================================================================
# GENERIC HELPERS
# =====================================================================
def find_file(name):
    """Locate <name>.asc / .csv / .txt anywhere under FOLDER (case-insensitive)."""
    wanted = {name.lower() + ext for ext in (".asc", ".csv", ".txt")}
    for root, _, files in os.walk(FOLDER):
        for f in files:
            if f.lower() in wanted:
                return os.path.join(root, f)
    raise FileNotFoundError(f"Source file '{name}' (.asc/.csv/.txt) not found under: {FOLDER}")


def read_raw(name):
    """Read a raw file as text, auto-detecting the separator and encoding."""
    path = find_file(name)
    with open(path, "r", encoding="latin-1") as fh:
        header = fh.readline()
    sep = ";" if header.count(";") >= header.count(",") else ","
    for enc in ("utf-8", "latin-1"):
        try:
            df = pd.read_csv(path, sep=sep, dtype=str, encoding=enc,
                             keep_default_na=False, skipinitialspace=True)
            break
        except UnicodeDecodeError:
            continue
    df.columns = [c.strip().strip('"').strip().lower() for c in df.columns]
    return df


def normalize_text(df):
    """Trim spaces and quotes, and turn placeholder tokens ('?', 'NA', ...) into NULL."""
    for c in df.columns:
        s = df[c].astype("string").str.strip().str.strip('"').str.strip()
        df[c] = s.mask(s.isin(NULL_TOKENS))
    return df


def to_num(s):
    return pd.to_numeric(s, errors="coerce")


def parse_yymmdd(s):
    """Convert Berka dates such as 930101 to 1993-01-01 (only the first 6 characters are used)."""
    s = s.astype("string").str.strip().str[:6].str.zfill(6)
    return pd.to_datetime("19" + s, format="%Y%m%d", errors="coerce")


def make_key(df, col):
    """Make `col` a clean integer key and drop rows where it is missing."""
    df[col] = to_num(df[col])
    df = df.dropna(subset=[col]).copy()
    df[col] = df[col].astype("int64")
    return df


def fill_text(df, cols, value=NOT_SPECIFIED):
    for c in cols:
        df[c] = df[c].astype("string").fillna(value)
    return df


def map_text(series, mapping):
    """Translate Czech codes to English. Values missing from the map are kept unchanged."""
    s = series.astype("string").str.upper().str.strip()
    return s.map(mapping).fillna(series.astype("string"))


# =====================================================================
# TABLE CLEANERS
# =====================================================================
def clean_district(df):
    df = df.rename(columns={
        "a1": "district_id", "a2": "district_name", "a3": "region",
        "a4": "population", "a5": "municipalities_lt_500",
        "a6": "municipalities_500_1999", "a7": "municipalities_2000_9999",
        "a8": "municipalities_gt_10000", "a9": "num_cities",
        "a10": "urban_ratio_pct", "a11": "avg_salary",
        "a12": "unemployment_rate_95", "a13": "unemployment_rate_96",
        "a14": "entrepreneurs_per_1000", "a15": "crimes_95", "a16": "crimes_96",
    })
    df = make_key(df, "district_id")
    num_cols = [c for c in df.columns if c not in ("district_id", "district_name", "region")]
    for c in num_cols:
        df[c] = to_num(df[c])

    # Missing '95 values are filled from the '96 value of the same district
    df["data_imputed"] = 0
    for old, new in (("unemployment_rate_95", "unemployment_rate_96"), ("crimes_95", "crimes_96")):
        m = df[old].isna() & df[new].notna()
        df.loc[m, old] = df.loc[m, new]
        df.loc[m, "data_imputed"] = 1

    # Anything still missing gets the column median; those rows are flagged
    for c in num_cols:
        missing = df[c].isna()
        if missing.any():
            df[c] = df[c].fillna(df[c].median())
            df.loc[missing, "data_imputed"] = 1

    df = fill_text(df, ["district_name", "region"], "Unknown")
    df["crime_rate_per_1000_96"] = (df["crimes_96"] / df["population"] * 1000).round(2)
    return df


def clean_account(df):
    df = make_key(df, "account_id")
    df = make_key(df, "district_id")
    df["frequency"] = map_text(df["frequency"], FREQUENCY_MAP).fillna("Unknown")
    df["open_date"] = parse_yymmdd(df["date"])
    return df.drop(columns=["date"])


def clean_client(df):
    df = make_key(df, "client_id")
    df = make_key(df, "district_id")
    # birth_number = YYMMDD, with 50 added to the month for women
    bn = df["birth_number"].astype("string").str.strip().str.zfill(6)
    yy = bn.str[0:2]
    mm = to_num(bn.str[2:4]).astype("float64")
    dd = bn.str[4:6]
    female = mm > 50
    mm_real = pd.Series(np.where(female, mm - 50, mm), index=df.index)
    mm_str = mm_real.round().astype("Int64").astype("string").str.zfill(2)
    df["birth_date"] = pd.to_datetime("19" + yy + mm_str + dd, format="%Y%m%d", errors="coerce")
    df["gender"] = np.where(mm.isna(), "Unknown", np.where(female, "Female", "Male"))
    df["age_at_1998"] = ((REF_DATE - df["birth_date"]).dt.days // 365.25).astype("Int64")
    return df.drop(columns=["birth_number"])


def clean_authorization(df):
    """Source file 'disp': links a client to an account. Loaded as table 'authorization'."""
    df = make_key(df, "disp_id")
    df = make_key(df, "client_id")
    df = make_key(df, "account_id")
    df["type"] = df["type"].astype("string").str.upper().fillna("Unknown")
    df = df.rename(columns={"type": "disp_type"})
    return df


def clean_card(df):
    df = make_key(df, "card_id")
    df = make_key(df, "disp_id")
    df["type"] = df["type"].astype("string").str.lower().fillna("Unknown")
    df = df.rename(columns={"type": "card_type"})
    df["issued_date"] = parse_yymmdd(df["issued"])      # e.g. '931107 00:00:00' -> first 6 characters
    return df.drop(columns=["issued"])


def clean_loan(df):
    df = make_key(df, "loan_id")
    df = make_key(df, "account_id")
    for c in ("amount", "duration", "payments"):
        df[c] = to_num(df[c])
    df["status"] = df["status"].astype("string").str.upper().str.strip()
    df["status_desc"] = df["status"].map(LOAN_STATUS_MAP).fillna("Unknown")
    df["is_bad_loan"] = df["status"].isin(["B", "D"]).astype("int64")   # B and D = problem loans
    df["loan_date"] = parse_yymmdd(df["date"])
    df = df.drop(columns=["date"])
    df["status"] = df["status"].fillna("Unknown")
    return df


def clean_orders(df):
    df = make_key(df, "order_id")
    df = make_key(df, "account_id")
    df["amount"] = to_num(df["amount"])
    df["k_symbol"] = map_text(df["k_symbol"], K_SYMBOL_MAP).fillna(NOT_SPECIFIED)
    df = fill_text(df, ["bank_to", "account_to"], NOT_SPECIFIED)
    df = df.rename(columns={"k_symbol": "payment_purpose"})
    return df


def clean_transactions(df):
    """Source file 'trans'. Loaded as table 'transactions'."""
    df = make_key(df, "trans_id")
    df = make_key(df, "account_id")
    df["amount"] = to_num(df["amount"])
    df["balance"] = to_num(df["balance"])
    df["trans_date"] = parse_yymmdd(df["date"])
    df = df.drop(columns=["date"])
    df["type"] = map_text(df["type"], TRANS_TYPE_MAP).fillna("Unknown")
    df["operation"] = map_text(df["operation"], OPERATION_MAP).fillna(NOT_SPECIFIED)
    df["k_symbol"] = map_text(df["k_symbol"], K_SYMBOL_MAP).fillna(NOT_SPECIFIED)
    df = fill_text(df, ["bank", "account"], "Not Applicable")
    df = df.rename(columns={"type": "trans_type", "k_symbol": "payment_purpose",
                            "bank": "partner_bank", "account": "partner_account"})
    df["is_credit"] = (df["trans_type"] == "Credit").astype("int64")
    df["signed_amount"] = np.where(df["is_credit"] == 1, df["amount"], -df["amount"])
    df["trans_year"] = df["trans_date"].dt.year.astype("Int64")
    df["trans_month"] = df["trans_date"].dt.month.astype("Int64")
    return df


# =====================================================================
# PIPELINE
#   (MySQL table, source file, cleaner, primary key, [(foreign key column, parent table)])
#   Order matters: parent tables must come before the tables that reference them.
# =====================================================================
PIPELINE = [
    ("district",      "district", clean_district,      "district_id", []),
    ("account",       "account",  clean_account,       "account_id",  [("district_id", "district")]),
    ("client",        "client",   clean_client,        "client_id",   [("district_id", "district")]),
    ("authorization", "disp",     clean_authorization, "disp_id",     [("client_id", "client"),
                                                                        ("account_id", "account")]),
    ("card",          "card",     clean_card,          "card_id",     [("disp_id", "authorization")]),
    ("loan",          "loan",     clean_loan,          "loan_id",     [("account_id", "account")]),
    ("orders",        "order",    clean_orders,        "order_id",    [("account_id", "account")]),
    ("transactions",  "trans",    clean_transactions,  "trans_id",    [("account_id", "account")]),
]
PK_OF = {table: pk for table, _, _, pk, _ in PIPELINE}

# Extra indexes for the columns used most in dashboard filters
EXTRA_INDEXES = [
    ("transactions", "trans_date"), ("transactions", "trans_type"), ("transactions", "operation"),
    ("loan", "loan_date"), ("loan", "status"), ("account", "open_date"),
]


# =====================================================================
# STEP 1: CLEANING
# =====================================================================
def run_cleaning():
    """Clean every table and record row counts, duplicates, orphans and NULLs in REPORT."""
    clean = {}
    for table, fname, cleaner, pk, fks in PIPELINE:
        print(f"[clean] {table} (from '{fname}') ...", flush=True)
        raw = normalize_text(read_raw(fname))
        stats = {"rows_raw": len(raw), "nulls_raw": int(raw.isna().sum().sum())}

        df = cleaner(raw.copy())

        before = len(df)
        df = df.drop_duplicates().drop_duplicates(subset=[pk], keep="first")
        stats["duplicates_removed"] = before - len(df)

        # Orphans: rows whose foreign key has no matching parent row
        orphans = 0
        for col, parent in fks:
            ok = df[col].isin(clean[parent][PK_OF[parent]])
            orphans += int((~ok).sum())
            df = df[ok]
        stats["orphans_removed"] = orphans

        stats["rows_clean"] = len(df)
        stats["nulls_clean"] = int(df.isna().sum().sum())
        stats["null_cols_left"] = {c: int(n) for c, n in df.isna().sum().items() if n > 0}
        REPORT[table] = stats
        clean[table] = df.reset_index(drop=True)
    return clean


# =====================================================================
# STEP 2: MYSQL LOAD
# =====================================================================
def get_password():
    """Use the configured password, otherwise ask for it so it is never stored in the file."""
    return DB_PASSWORD or getpass.getpass(f"MySQL password for {DB_USER}@{DB_HOST}: ")


def get_engine():
    """Create the database if needed, without ever dropping it."""
    from sqlalchemy import create_engine, text
    from sqlalchemy.engine import URL

    password = get_password()
    server_url = URL.create("mysql+pymysql", username=DB_USER, password=password,
                            host=DB_HOST, port=DB_PORT)
    with create_engine(server_url).begin() as con:
        con.execute(text(f"CREATE DATABASE IF NOT EXISTS `{DB_NAME}` "
                         f"CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"))

    db_url = URL.create("mysql+pymysql", username=DB_USER, password=password,
                        host=DB_HOST, port=DB_PORT, database=DB_NAME)
    return create_engine(db_url)


def sql_dtypes(df):
    """Dates -> DATE, text -> VARCHAR sized to the longest value; numbers use pandas defaults."""
    from sqlalchemy.types import VARCHAR, Date
    out = {}
    for c in df.columns:
        if pd.api.types.is_datetime64_any_dtype(df[c]):
            out[c] = Date()
        elif pd.api.types.is_string_dtype(df[c]) or df[c].dtype == object:
            n = int(df[c].astype("string").str.len().max() or 1)
            out[c] = VARCHAR(max(n + 10, 20))
    return out


def load_to_mysql(clean, engine):
    from sqlalchemy import text

    # Refuse to overwrite existing project tables unless the user explicitly opts in.
    target_tables = [t[0] for t in PIPELINE] + list(LEGACY_TABLES)
    from sqlalchemy import inspect
    existing = set(inspect(engine).get_table_names())
    conflicts = sorted(existing.intersection(target_tables))
    if conflicts and not ALLOW_TABLE_REPLACE:
        raise RuntimeError(
            "Safety stop: these tables already exist and were not changed: "
            + ", ".join(conflicts)
            + ". Back up your database first. If you intentionally want to replace "
              "these Berka tables, set BERKA_ALLOW_TABLE_REPLACE=YES."
        )

    if conflicts and ALLOW_TABLE_REPLACE:
        with engine.begin() as con:
            con.execute(text("SET FOREIGN_KEY_CHECKS=0"))
            for table in target_tables:
                con.execute(text(f"DROP TABLE IF EXISTS `{table}`"))
            con.execute(text("SET FOREIGN_KEY_CHECKS=1"))

    for table, *_ in PIPELINE:
        df = clean[table]
        dtypes = sql_dtypes(df)
        step = 50000
        print(f"[load ] {table}: {len(df):,} rows", flush=True)
        for i in range(0, len(df), step):
            df.iloc[i:i + step].to_sql(
                table, engine, if_exists="replace" if i == 0 else "append",
                index=False, dtype=dtypes, chunksize=10000)
            if len(df) > step:
                print(f"        {min(i + step, len(df)):,} / {len(df):,}", flush=True)


def add_constraints(engine):
    """Add primary keys, foreign keys and indexes. A failure is reported, not fatal."""
    from sqlalchemy import text

    for table, _, _, pk, _ in PIPELINE:
        with engine.begin() as con:
            try:
                con.execute(text(f"ALTER TABLE `{table}` ADD PRIMARY KEY (`{pk}`)"))
            except Exception as e:
                print(f"[warn ] primary key on {table}: {str(e)[:120]}")

    for table, _, _, _, fks in PIPELINE:
        for col, parent in fks:
            name = f"fk_{table}_{col}"
            with engine.begin() as con:
                try:
                    con.execute(text(
                        f"ALTER TABLE `{table}` ADD CONSTRAINT `{name}` "
                        f"FOREIGN KEY (`{col}`) REFERENCES `{parent}`(`{PK_OF[parent]}`)"))
                except Exception as e:
                    print(f"[warn ] foreign key {name}: {str(e)[:120]}")

    for table, col in EXTRA_INDEXES:
        with engine.begin() as con:
            try:
                con.execute(text(f"CREATE INDEX `idx_{table}_{col}` ON `{table}`(`{col}`)"))
            except Exception as e:
                print(f"[warn ] index {table}.{col}: {str(e)[:120]}")


def verify(engine):
    """Print row counts and a few sample rows from the loaded database."""
    from sqlalchemy import text
    print("\n=== MySQL VERIFICATION ===")
    with engine.connect() as con:
        for table, *_ in PIPELINE:
            n = con.execute(text(f"SELECT COUNT(*) FROM `{table}`")).scalar()
            print(f"{table:<15}{n:>10,} rows")

        print("\nSample (loan):")
        for r in con.execute(text(
                "SELECT loan_id, account_id, loan_date, amount, status, status_desc "
                "FROM loan LIMIT 3")):
            print("  ", tuple(r))

        print("\nSample (transactions):")
        for r in con.execute(text(
                "SELECT trans_id, trans_date, trans_type, operation, amount, balance "
                "FROM transactions LIMIT 3")):
            print("  ", tuple(r))

        bad = con.execute(text("SELECT COUNT(*) FROM transactions WHERE trans_date IS NULL")).scalar()
        print(f"\nTransactions with a NULL date: {bad}")


# =====================================================================
# REPORT
# =====================================================================
def report_dirs():
    """Folders to try, in order: next to this script, current folder, data folder."""
    here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
    seen, out = set(), []
    for d in (here, os.getcwd(), FOLDER):
        if d and d not in seen:
            seen.add(d)
            out.append(d)
    return out


def save_report(text_out):
    """Save the report as .txt and .csv in the first writable folder and print the exact path."""
    rows = [{"table": t, **{k: v for k, v in s.items() if k != "null_cols_left"},
             "null_cols_left": "; ".join(f"{c}={n}" for c, n in s["null_cols_left"].items())}
            for t, s in REPORT.items()]
    for folder in report_dirs():
        try:
            txt_path = os.path.join(folder, "cleaning_report.txt")
            csv_path = os.path.join(folder, "cleaning_report.csv")
            with open(txt_path, "w", encoding="utf-8-sig") as fh:
                fh.write(text_out)
            pd.DataFrame(rows).to_csv(csv_path, index=False, encoding="utf-8-sig")
            print(f"\nReport saved:\n  {txt_path}\n  {csv_path}")
            return
        except OSError as e:
            print(f"[warn ] could not write report in {folder}: {e}")
    print("[warn ] cleaning report was NOT saved (no writable folder found)")


def print_report():
    """Print the cleaning summary and save it to disk."""
    lines = ["=== CLEANING REPORT ===",
             f"{'table':<15}{'raw':>10}{'clean':>10}{'dups':>7}{'orphans':>9}{'nulls raw':>11}{'nulls now':>11}"]
    for t, s in REPORT.items():
        lines.append(f"{t:<15}{s['rows_raw']:>10,}{s['rows_clean']:>10,}"
                     f"{s['duplicates_removed']:>7}{s['orphans_removed']:>9}"
                     f"{s['nulls_raw']:>11,}{s['nulls_clean']:>11,}")
    left = {t: s["null_cols_left"] for t, s in REPORT.items() if s["null_cols_left"]}
    if left:
        lines.append("\nNULLs intentionally kept (the source has no value to fill them with):")
        for t, cols in left.items():
            lines.append(f"  {t}: {cols}")
    text_out = "\n".join(lines)
    print("\n" + text_out)
    save_report(text_out)


# =====================================================================
# MAIN
# =====================================================================
def main():
    if not os.path.isdir(FOLDER):
        sys.exit(f"Folder not found: {FOLDER}\n"
                 f"Set BERKA_FOLDER or edit FOLDER in the CONFIGURATION section.")
    if ALLOW_TABLE_REPLACE:
        print("[warning] BERKA_ALLOW_TABLE_REPLACE=YES: existing Berka target tables may be replaced.")
    else:
        print("[safe] Existing database and tables will not be overwritten.")
    clean = run_cleaning()
    print_report()
    engine = get_engine()
    load_to_mysql(clean, engine)
    add_constraints(engine)
    verify(engine)
    print("\nDone. Database:", DB_NAME)


if __name__ == "__main__":
    main()