# Banking Analytics Dashboard Guide

This guide documents the seven report pages and the metric logic represented in `sql/Bank_Analytics_Dashboard_Validation.sql`. It is intended to help a reviewer understand what each visual measures and how to interpret it.

> **Validation status:** The project owner has manually compared the Power BI dashboard figures with the corresponding MySQL outputs and confirmed that the checked figures match. The repository does not yet contain a machine-generated reconciliation export. The SQL definitions below are the documented validation logic; where the SQL itself marks a definition as an assumption, that limitation is retained.

## Dataset and analytical scope

- **Source:** Historical Czech Bank / Berka (PKDD'99) dataset, covering 1993–1998.
- **Tools:** Python/pandas for preparation, MySQL for relational analysis and validation, Power BI for reporting.
- **Model joins:** Transactions and loans are associated with account districts; cards are associated with client districts through authorization/disp records.
- **Historical context:** Values describe the source period, not current banking activity or current customer risk.

## Report page guide

| Page | Main question | Key measures / visuals | Main slicers |
|---|---|---|---|
| 1. Transaction | How does transaction activity and value change over time? | Transaction count, credits, debits, gross transaction amount, net cash flow; yearly activity; credit/debit amount mix | Year |
| 2. Loan | What is the loan portfolio composition and observed repayment outcome? | Loan count and amount, average loan amount, bad-loan amount, default rate, exposure at risk; status mix; default rate by duration | Loan issue year, duration |
| 3. Balance | What do transaction balances and cash movements look like? | Average balance, net cash flow, credit-to-debit ratio, cash-withdrawal share, negative-balance transaction share, average transactions per account | Region, transaction type |
| 4. Card | How are cards and client/district characteristics distributed? | Cards issued, gold-card share, average client age, female-client share, average district salary and unemployment; age/gender distribution; active accounts by region | Region, gender (subject to measure-specific filter logic) |
| 5. Customer Analysis | What is the customer profile across districts? | Total clients, average age, female/male share; gender distribution; bottom/top 10 districts; new/repeat customer indicators | District, gender |
| 6. Fraud Detection Analysis | Where do transaction patterns warrant closer review? | Transaction count, active accounts, cash-withdrawal share, negative-balance transaction share, accounts ever observed with negative balance, bad-loan count; operation and district comparisons | Transaction type, district |
| 7. Overview | What is the high-level regional picture? | Clients, accounts, average balance, loans, default rate, net cash flow; age distribution; regional loan performance; cash-withdrawal trend; top districts by transaction count | Region |

## KPI definitions and interpretation

### Transaction metrics

| Metric | Definition | Interpretation |
|---|---|---|
| Total Transactions | Count of transaction rows in the selected context | Activity volume, not monetary value |
| Total Credits / Total Debits | Sum of `amount` for Credit or Debit rows respectively | Gross inflow/outflow amounts |
| Total Transaction Amount | Sum of `amount` across credits and debits | Gross processed value; do not interpret as net cash flow |
| Net Cash Flow | Sum of `signed_amount` | Signed net movement; direction depends on the loader's credit/debit sign convention |
| Average Balance | Arithmetic mean of transaction `balance` values | Average recorded balance per transaction row, not a time-weighted account balance |

### Loan metrics

| Metric | Definition | Interpretation |
|---|---|---|
| Total Loans | Count of loan records | Loan volume |
| Total Loan Amount | Sum of loan `amount` | Total original principal represented in the selected records |
| Average Loan Amount | Mean of loan `amount` | Average original loan amount |
| Bad Loan Amount | Sum of `amount` where `is_bad_loan = 1` | Principal amount associated with loans classified as bad by the project mapping |
| Default Rate | Bad-loan count divided by total loan count | Count-based share; displayed as a percentage in the report |
| Exposure at Risk | Bad-loan amount divided by total loan amount | Amount-weighted share; distinct from default rate |
| Default Rate by Duration | Bad-loan count divided by loan count within each duration | Compare repayment outcome mix across loan terms |

The SQL uses loan issue year for the loan-page year filter. The `status_desc` mapping is standardized by the Python loader; the focused loan cross-check is in `sql/Loan_Outcome_Crosscheck.sql`.

### Balance and transaction-behaviour metrics

| Metric | Definition | Interpretation |
|---|---|---|
| Credit-to-Debit Ratio | Credit amount divided by debit amount | Above 1 means credit amount exceeds debit amount in the selected rows; undefined when debit amount is zero |
| Cash Withdrawal Share | Cash-withdrawal transaction count divided by transaction count | Share of transaction events, not share of transaction value |
| Negative Balance Transactions Share | Rows with `balance < 0` divided by all transaction rows | Transaction-row indicator; not the share of customers or accounts in financial distress |
| Average Transactions per Account | Transaction count divided by distinct account count | Activity intensity among accounts represented in the selected transaction rows |
| Active Accounts | Distinct accounts with at least one transaction in the dataset/context | Operational definition used by this report; not a formal bank account status |

### Card, customer and district metrics

| Metric | Definition | Interpretation |
|---|---|---|
| Cards Issued | Count of card records linked to clients and districts | Number of card records, not necessarily unique clients |
| Gold Card Share | Gold-card records divided by all card records | Card-product mix |
| Average Client Age | Mean of `age_at_1998` | Age is derived relative to 1998, not current age |
| Female / Male Client Share | Gender-specific client count divided by client count | Customer composition in the selected population |
| Average District Salary | Mean of district `avg_salary` values in the selected region | District-level contextual attribute; not an individual customer salary |
| Average Unemployment Rate | Mean of district `unemployment_rate_96` values | Historical district-level context from 1996 |
| New Customers | Clients whose first linked account-open year is identified | The SQL implementation is an assumption pending confirmation against the exact Power BI DAX |
| Repeat Customers | Clients linked to more than one distinct account | The SQL implementation is an assumption pending confirmation against the exact Power BI DAX |

## Important interpretation and model caveats

1. **Risk indicators are not proof of fraud.** Negative balances and cash withdrawals are screening signals only. They do not establish fraudulent intent or a confirmed fraud event. Page 6 should be described as transaction-risk / anomaly indicators unless verified fraud labels are available.
2. **Negative balance definitions differ by visual.** The negative-balance transaction share counts transaction rows with a negative balance. The accounts-with-negative-balance metric counts distinct accounts that have at least one such row.
3. **New vs Repeat Customers is provisional.** The SQL explicitly labels its logic as an assumption because the exact Power BI DAX was not available when the validation query was authored. Do not present these two measures as independently reconciled until the DAX definition is documented.
4. **Filter behaviour is measure-specific.** The Card page's SQL uses region and gender filters for some card/client metrics, while female-client share and district-level salary/unemployment calculations are not all filtered identically. Confirm the intended Power BI filter interactions before describing every KPI as responding to every slicer.
5. **Averages are not weighted unless stated.** Average district salary/unemployment in this validation SQL is an average of district-level values, not a population-weighted regional rate.
6. **Historical dataset only.** Avoid claims about today's banking market, current fraud rates, or live customer behaviour.
7. **Percent formatting matters.** Several SQL ratios are returned as decimals (for example, 0.1250). Display them as 12.50% in Power BI if the measure uses percentage formatting; do not multiply by 100 twice.

## Suggested reviewer walkthrough

1. Start on Overview and explain the regional slicer and high-level customer, account, loan and cash-flow measures.
2. Open Transaction to distinguish gross credit/debit amounts from signed net cash flow.
3. Open Loan to explain count-based default rate versus amount-based exposure at risk.
4. Use Balance and Fraud Detection Analysis to discuss behavioural indicators carefully, without calling them confirmed fraud.
5. Finish with Customer Analysis and Card to explain demographic and district-level context, including the historical age reference year.
6. Point reviewers to the SQL validation script and the project-owner-confirmed Power BI ↔ MySQL comparison.

## Dashboard evidence still to add

Capture genuine screenshots from Power BI Desktop (or an approved published report) for all seven pages. Use the same default filter state for each capture, remove any personal or connection details, and save them under `docs/screenshots/` with descriptive names such as `01-overview.png`, `02-transactions.png`, and so on. Do not create placeholder screenshots or imply that a public Power BI Service report exists before it is actually published.


## Observed dashboard snapshot (uploaded 7-page PDF)

The following figures are transcribed from the uploaded Power BI export in its default "All" filter state. They are a visual snapshot, not a replacement for the SQL definitions above; slicers can change the values.

| Page | Values visible in the export | Useful interpretation |
|---|---|---|
| Transactions and Cash Flow (p. 1) | 4.5K accounts; 1.05632M transactions; 3.227bn credits; 3.030bn debits; 5.369K clients; 6.258bn gross transaction amount; 197.151M net cash flow | Credits exceed debits by roughly 197M in the displayed snapshot. Gross transaction amount is the sum of both directions and should not be confused with net flow. |
| Loan Risk (p. 2) | 682 loans; 103M total loan amount; 151.41K average loan amount; 15.58M bad-loan amount; 11.14% default rate; 15% exposure at risk | The amount-weighted risk share (exposure) is higher than the count-based default rate. Status mix shown: 403 Running - OK, 203 Finished - Paid, 45 Running - In Debt, 31 Finished - Not Paid. |
| Transactions and Balance (p. 3) | 234.74 average transactions/account; 38.52K average balance; 0.41 cash-withdrawal share; 1.07 credit-to-debit ratio; 197.15M net cash flow; 0.00284 negative-balance transaction share | Cash withdrawals account for about 41% of transaction events in this view. Negative-balance transaction share is about 0.284%, not a customer-level distress rate. Average balance falls from 40.2K in 1994 to 36.4K in 1997 in the displayed yearly trend. |
| Customers and Districts (p. 4) | 44.80 average client age; 892 cards; 0.0987 gold-card share; 3.79 average unemployment rate; 49.26% female clients; 9.03K average district salary | Customer gender mix is close to even. Salary and unemployment are district-level historical context, not individual client attributes. |
| Customer Demographics and Segmentation (p. 5) | 5.369K clients; average age 44.80; female share 0.49; male share 0.51; district-level client counts shown | The displayed new-customer, repeat-customer and total-client slices each show about 5K (33.33%). These displayed values appear inconsistent with a mutually exclusive partition of 5.369K clients; do not use them as a validated segmentation result until the DAX and visual aggregation are checked. |
| Fraud Detection and Suspicious Transaction Analysis (p. 6) | 1.0563M transactions; 288 accounts with negative balance; 76 bad loans; about 5K active accounts; 0.0028 negative-balance transaction share; 0.41 cash-withdrawal share | Treat these as screening and portfolio indicators only. The report does not show confirmed fraud labels in this export. |
| Retail Bank Overview (p. 7) | 5.369K clients; 4.5K accounts; 38.52K average balance; 682 loans; 11.14% default rate; 197.15M net cash flow | Top district by transactions is Hl.m. Praha (133K), followed by Karvina (36K) and Ostrava - mesto (34K). Regional loan performance varies; the plotted default-rate labels range from about 1.6% to 15.8%. |

### Visual QA notes from the PDF

These are presentation issues visible in the uploaded export and worth fixing before using it as a polished portfolio sample:

1. **Page 1 title formatting:** the heading displays "Net Flow 19715.1%" while the KPI card shows 197.151M. Check the title measure/format string; it likely needs a monetary/amount format rather than a percentage.
2. **Page 2 title spelling:** "Defualt Rate" is misspelled; change to "Default Rate".
3. **Page 3 chart title overlap:** "Total Credits and Total by MonthDebits" appears concatenated/overlapped. Rename it to "Total Credits and Total Debits by Year" if the visual is yearly.
4. **Page 5 segmentation visual:** New Customers, Repeat Customers and Total Clients are each displayed as equal 33.33% slices. Since Total Clients is not a peer segment, replace this pie with separate KPI cards or a correctly defined new-vs-repeat split after validating the DAX.
5. **Page 4 title context:** header rounds average age to 45 while the card shows 44.80. This is not necessarily wrong, but use consistent precision if desired.
6. **Page 6 terminology:** keep "Fraud Detection" qualified as suspicious-activity screening unless a verified fraud label/outcome is added.

### Snapshot and data-quality caution

The PDF is a report export with default slicers set to All. Some visuals use rounded K/M/B labels, so sums may differ slightly due to display rounding. The values above should be rechecked after changing Year, Region, Duration, Gender, District, or Transaction Type filters. The export does not expose the underlying DAX, model relationships, or drill-through configuration; this guide does not claim to have independently inspected those internals.

## Related files

- [Main project README](../README.md)
- [SQL dashboard validation](../sql/Bank_Analytics_Dashboard_Validation.sql)
- [Loan outcome cross-check](../sql/Loan_Outcome_Crosscheck.sql)
- [Project notes](./PROJECT_NOTES.md)
