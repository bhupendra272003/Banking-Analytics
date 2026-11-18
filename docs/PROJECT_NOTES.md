# Project Notes

## Data pipeline
The Python script is designed to read local Berka source files, standardize selected Czech labels, parse dates, derive client age/gender fields from the source birth-number field, remove duplicates/orphans according to its cleaning rules, and load the cleaned tables into MySQL.

## SQL validation
The SQL validation file targets `bank_analytics`, defines five helper views (`v_account`, `v_client`, `v_trans`, `v_loan`, `v_card`), and includes dashboard, data-quality, year-wise, risk/loan, customer/region, and window-function checks.

## Known limitations
- The New vs Repeat Customers calculation is documented in the SQL source as an assumption because the actual Power BI DAX definition was not available for review.
- Percentage-like SQL outputs should be checked against the Power BI measure formatting.
- Runtime execution and reconciliation have not been verified against a live MySQL instance and the original data.
- No Power BI `.pbix` file was supplied.