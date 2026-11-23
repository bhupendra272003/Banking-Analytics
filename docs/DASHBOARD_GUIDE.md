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

## Related files

- [Main project README](../README.md)
- [SQL dashboard validation](../sql/Bank_Analytics_Dashboard_Validation.sql)
- [Loan outcome cross-check](../sql/Loan_Outcome_Crosscheck.sql)
- [Project notes](./PROJECT_NOTES.md)
