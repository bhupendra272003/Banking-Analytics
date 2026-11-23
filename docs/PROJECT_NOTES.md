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

## Power BI deliverable and reconciliation

The Power BI report file is included at the repository root as `bank_analytics_Dashboard.pbix`. The project owner has completed a manual comparison of the Power BI dashboard figures against the MySQL query outputs and confirmed that all checked figures match.

This is recorded as project-owner confirmation. A separate machine-generated reconciliation report or execution transcript has not yet been committed. Live Power BI Service publishing and interactive public sharing have not been configured or verified.

## Automated checks

GitHub Actions runs the Python syntax and regression tests. The latest recorded workflow run completed successfully:
https://github.com/bhupendra272003/Banking-Analytics/actions/runs/45009347913

These automated checks do not themselves execute the full ETL against MySQL or inspect the Power BI file.

## Known limitations

- The New vs Repeat Customers calculation is documented in the SQL source as an assumption; add the exact DAX definition if the metric is to be independently reproduced.
- Percentage-like SQL outputs should be interpreted using the corresponding Power BI measure's formatting and denominator.
- Dashboard screenshots and a public Power BI Service URL are still to be added.
