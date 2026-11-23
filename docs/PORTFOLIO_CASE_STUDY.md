# Banking Analytics — Portfolio Case Study

## Executive summary

This project analyzes the historical Czech Bank (Berka / PKDD'99) dataset covering 1993–1998. It combines Python-based data preparation, MySQL analysis and validation, and a seven-page Power BI report.

The work focuses on transaction activity, cash flow, loan outcomes, account balances, customer demographics, district context, and transaction patterns that may warrant closer review. It is a portfolio project using historical data, not a live banking engagement.

## Business questions

1. How do transaction volumes, credits, debits, and net cash flow vary over time?
2. What does the loan portfolio look like by status, amount, and duration?
3. What do recorded balances and transaction behaviours show?
4. How are customers and cards distributed across demographic and district attributes?
5. Which transaction patterns are useful as screening indicators for further investigation?

## Data and tools

- **Dataset:** Historical Czech Bank / Berka (PKDD'99), 1993–1998
- **Data preparation:** Python, pandas, NumPy
- **Database and analysis:** MySQL 8.0+
- **Reporting:** Microsoft Power BI
- **Model scope:** Accounts, clients, transactions, loans, cards, authorization/disp records, and district attributes

## Workflow

1. Prepared and standardized source files with a Python/pandas pipeline, including date parsing and selected category mappings.
2. Loaded the prepared relational tables into MySQL.
3. Built SQL validation and analysis queries for dashboard KPIs, data quality, loan outcomes, and regional comparisons.
4. Developed a seven-page Power BI report for overview, transactions, loans, balances, cards, customer analysis, and transaction-risk screening.
5. Compared dashboard figures with corresponding MySQL outputs. The project owner confirmed that the checked figures match; the repository does not currently include a machine-generated reconciliation export.

## Dashboard snapshot — default “All” filters

The following values are transcribed from the available seven-page Power BI PDF export. They are a historical default-filter snapshot and can change with slicers. Rounded K/M/B labels may cause small apparent differences.

| Area | Values shown | Interpretation |
|---|---|---|
| Transactions | 1.05632M transactions; 3.227bn credits; 3.030bn debits; 6.258bn gross transaction amount | Gross amount combines both directions; it is not net flow. |
| Cash flow | 197.151M net cash flow | Credits exceed debits by roughly 197M in this displayed snapshot, subject to the model's signed-amount convention. |
| Loan portfolio | 682 loans; 103M total loan amount; 151.41K average loan amount | Describes the historical loan records represented in the report. |
| Loan outcomes | 11.14% count-based default rate; 15% amount-based exposure at risk; 15.58M bad-loan amount | Amount-weighted exposure is higher than the count-based default rate in this snapshot. |
| Transactions and balances | 38.52K average recorded balance; 0.41 cash-withdrawal share; 1.07 credit-to-debit ratio | Cash withdrawals are about 41% of transaction events, not 41% of transaction value. |
| Negative-balance indicator | 0.00284 negative-balance transaction share; 288 accounts with at least one negative-balance record | A screening indicator only; it does not establish customer distress or fraud. |
| Customer and card context | 5.369K clients; 44.80 average age; 892 cards; 0.0987 gold-card share | Age is derived relative to 1998; district attributes are contextual, not individual customer salaries. |
| Regional overview | Hl.m. Praha: 133K transactions; Karvina: 36K; Ostrava - mesto: 34K | Highest transaction-count districts shown in the default overview export. |

## Metric definitions that matter

- **Gross transaction amount:** Sum of transaction amounts across credit and debit rows.
- **Net cash flow:** Sum of signed transaction amounts; interpretation follows the loader's credit/debit sign convention.
- **Default rate:** Bad-loan count divided by total loan count.
- **Exposure at risk:** Bad-loan amount divided by total loan amount.
- **Cash-withdrawal share:** Cash-withdrawal transaction count divided by total transaction count.
- **Negative-balance transaction share:** Transaction rows with a negative recorded balance divided by all transaction rows.

These measures use different denominators and should not be treated as interchangeable.

## Quality checks and validation

- Python regression tests cover date parsing and selected category mappings.
- GitHub Actions runs the Python regression checks; the latest recorded workflow run completed successfully: [workflow run](https://github.com/bhupendra272003/Banking-Analytics/actions/runs/45009347913).
- SQL scripts provide dashboard KPI checks, data-quality checks, regional analysis, and a focused loan-outcome cross-check.
- The project owner confirmed that checked Power BI figures match the corresponding MySQL results. This is owner-confirmed validation, not an independently reproduced reconciliation log in this repository.

## Known limitations and responsible interpretation

1. The source data is historical (1993–1998); results do not describe current banking conditions.
2. The report's “Fraud Detection” page contains behavioural screening indicators. No confirmed fraud labels are evidenced in the exported report, so these patterns must not be described as proven fraud.
3. “New Customers” and “Repeat Customers” are provisional: the SQL documents their calculation as an assumption pending confirmation against the exact Power BI DAX.
4. The customer segmentation visual in the PDF shows New Customers, Repeat Customers, and Total Clients as equal 33.33% slices. Since Total Clients is not a peer segment, this visual should be redesigned or the DAX and aggregation validated before using it to support a segmentation conclusion.
5. The exported report shows a title-format issue on the Net Flow page, a spelling error in the Default Rate title, and an overlapping credits/debits chart title. These are presentation fixes to complete in Power BI Desktop.
6. Dashboard screenshots and a public Power BI Service report link have not yet been added to the repository.

## Reviewer walkthrough

1. Begin with the Overview page and regional filter.
2. Explain gross transaction amount versus net cash flow.
3. Compare count-based default rate with amount-based exposure at risk.
4. Explain cash-withdrawal and negative-balance measures as screening indicators.
5. Finish with customer and district context, noting the historical reference year and provisional segmentation metric.

## Project files

- [Power BI report](../bank_analytics_Dashboard.pbix)
- [Dashboard guide and page-wise KPI definitions](./DASHBOARD_GUIDE.md)
- [SQL dashboard validation](../sql/Bank_Analytics_Dashboard_Validation.sql)
- [Loan outcome cross-check](../sql/Loan_Outcome_Crosscheck.sql)
- [Python data loader](../python/berka_to_mysql.py)

---
**Author:** [Bhupendra Singh Deora](https://github.com/bhupendra272003)
