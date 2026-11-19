# Project Notes

## Data pipeline

The Python loader reads local Berka source files (`.asc`, `.csv`, or `.txt`), standardizes selected Czech labels, parses dates, derives client age/gender fields from the source birth-number field, applies duplicate/orphan and missing-value handling, and loads the cleaned tables into MySQL.

Final table-name mappings include:
- `disp` -> `authorization`
- `trans` -> `transactions`
- `order` -> `orders`
- Other source tables retain their names.

The default database is `bank_analytics`. The loader is non-destructive by default and requires an explicit opt-in before replacing existing target tables.

## SQL validation

The SQL validation file targets `bank_analytics` and defines five helper views:
- `v_account`
- `v_client`
- `v_trans`
- `v_loan`
- `v_card`

It includes dashboard KPI/visual checks, data-quality checks, year-wise analysis, risk and loan analysis, customer/region analysis, and window-function examples.

## Power BI deliverable

The Power BI report file is included at the repository root as `bank_analytics_Dashboard.pbix`. The report has been uploaded to GitHub, but live Power BI Service publishing and interactive public sharing have not been configured or verified.

## Known limitations

- The New vs Repeat Customers calculation is documented in the SQL source as an assumption because the exact Power BI DAX definition was not available for review.
- Percentage-like SQL outputs should be checked against the corresponding Power BI measure formatting.
- Runtime execution and reconciliation have not been verified against a live MySQL instance and the original data.
- Dashboard screenshots and a public Power BI Service URL are still to be added.
