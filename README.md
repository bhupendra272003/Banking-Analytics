# Banking Analytics | Berka Dataset

An end-to-end banking analytics project based on the historical Czech Bank (Berka / PKDD'99) dataset. This repository is being organized around a Python data-cleaning and MySQL-loading pipeline, SQL validation queries, and a future Power BI report.

## Status
- Python source syntax checked.
- SQL reviewed statically; MySQL 8.0+ is recommended.
- Live MySQL execution and dashboard reconciliation are not yet verified.
- No Power BI `.pbix` file was supplied, so no finished Power BI report is included yet.

## Workflow
1. Place the original Berka `.asc`, `.csv`, or `.txt` files in a local folder.
2. Configure `BERKA_FOLDER` and MySQL environment variables.
3. Run `python python/berka_to_mysql.py`.
4. Run `sql/Bank_Analytics_Dashboard_Validation.sql` in MySQL Workbench after the tables are loaded.
5. Build the Power BI report and reconcile its measures with the SQL checks.

## Requirements
Python 3.9+, MySQL Server 8.0+, MySQL Workbench, and packages in `requirements.txt`.

Install with `python -m pip install -r requirements.txt`.

## Database safety
The revised loader is intended to be non-destructive by default: it creates the database only if missing and stops if target tables already exist. It does not drop the database. Existing target tables are replaced only when `BERKA_ALLOW_TABLE_REPLACE=YES` is explicitly set. Back up the dedicated project database first. The default schema is `bank_analytics`; confirm this is not a different database such as `banking_analytics` before running.

## Privacy
Do not commit passwords, `.env` files, database dumps, personal customer data, or raw dataset files unless redistribution is permitted.

## Next milestone
Add the Power BI `.pbix` report and verified findings/KPI values when available.