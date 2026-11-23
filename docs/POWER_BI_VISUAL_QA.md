# Power BI Visual QA — Banking Analytics

This checklist is based on the seven-page PDF export documented in [DASHBOARD_GUIDE.md](./DASHBOARD_GUIDE.md). It is a set of edits to apply in Power BI Desktop; the PBIX binary has not been modified by this document.

## Priority fixes

### 1. Transactions and Cash Flow — correct the Net Flow title

**Observed:** The page heading renders `Net Flow 19715.1%`, while the KPI card shows approximately `197.151M`.

**Fix in Power BI Desktop:**
1. Select the page title visual (or the card/measure used to compose the title).
2. Inspect the field/measure assigned to the dynamic title.
3. If it references the net cash-flow amount, format it as a number with display units (Millions) or currency only if the report's currency/unit is confirmed.
4. Do not apply percentage formatting to a monetary/amount measure.
5. Keep the KPI card and title on the same unit and decimal precision.

**Acceptance check:** The heading no longer displays a percent sign and agrees with the net cash-flow KPI at the same filter state.

### 2. Loan Risk — spelling

Change the visual title from **Defualt Rate** to **Default Rate**.

**Acceptance check:** Search the page visually for the misspelling; all labels use the corrected spelling.

### 3. Transactions and Balance — repair overlapping chart title

**Observed:** The export shows the title text concatenated/overlapped around “Total Credits and Total Debits”.

**Fix:** Set a concise static title such as **Total Credits and Total Debits by Year**. Confirm the X-axis is transaction year. If the chart is actually monthly, use **Total Credits and Total Debits by Month** instead.

**Acceptance check:** Full title is readable at the report's normal viewing size and matches the visual's time grain.

### 4. Customer Analysis — replace misleading segmentation pie

**Observed:** New Customers, Repeat Customers and Total Clients appear as three equal 33.33% slices. Total Clients is a total, not a mutually exclusive customer segment, so it should not be a peer slice.

**Recommended redesign:**
- Remove the three-category pie/donut.
- Show **Total Clients** as a standalone KPI card.
- Show **New Customers** and **Repeat Customers** as two separate KPI cards only after their definitions are verified.
- Optionally show a 100% stacked bar with only New vs Repeat if the two categories are mutually exclusive, exhaustive, and their counts reconcile to Total Clients.
- Until definitions are verified, label these measures **Provisional** or hide them from the executive-facing page.

**Required validation before publishing:**
1. Open the exact DAX for New Customers and Repeat Customers.
2. Confirm the business rule for “new” (for example, first account-open year in the selected period) and “repeat” (for example, multiple distinct accounts); do not assume these are equivalent.
3. Check whether a client can appear in both groups.
4. Check whether clients with no qualifying account are excluded.
5. Verify that New + Repeat equals Total Clients only if the categories are intended to be a complete, non-overlapping partition.
6. Compare each result with a matching MySQL query using the same filters and date logic.

### 5. Customer and Districts — align age precision

The page header rounds average age to 45 while the KPI shows 44.80. This is not a calculation error by itself.

**Fix:** Use one convention across title and card: either 44.8 / 44.80 everywhere, or 45 everywhere with clear rounding.

**Acceptance check:** Page title and KPI do not appear to contradict each other.

### 6. Fraud Detection — use responsible wording

The exported page shows transaction-pattern indicators, including cash-withdrawal share and negative-balance records. These are not proof of fraud.

**Recommended presentation:** Rename the page to **Transaction Risk Indicators** or **Suspicious Activity Screening**. Add a subtitle:

> Historical transaction patterns for review; indicators do not confirm fraud.

Avoid labels such as “fraud detected” unless confirmed fraud labels and a defensible validation method are available.

## Model / measure checks

- **Net Cash Flow:** verify the signed amount convention and use a numeric/amount format, not percentage.
- **Default Rate:** bad-loan count / total loan count.
- **Exposure at Risk:** bad-loan amount / total loan amount. Keep distinct from default rate.
- **Cash Withdrawal Share:** cash-withdrawal transaction count / all transaction count; it is not a value share.
- **Negative Balance Transaction Share:** transaction rows with balance < 0 / all transaction rows; do not describe it as a customer-level rate.
- **Average Balance:** the documented SQL uses the average of transaction balance rows; do not call it a time-weighted account balance.
- **Historical Age:** age is derived relative to 1998; do not describe it as current age.

## Final visual QA checklist

Before committing an updated PBIX:

- [ ] Save a backup copy of the current PBIX.
- [ ] Correct Net Flow title formatting.
- [ ] Correct “Default Rate” spelling.
- [ ] Fix the credits/debits chart title and confirm its time grain.
- [ ] Replace or hide the unverified three-slice customer segmentation pie.
- [ ] Align age precision.
- [ ] Rename/qualify the fraud page as screening indicators.
- [ ] Check slicers and cross-filtering on every page.
- [ ] Confirm totals at default “All” filters still match the MySQL checks already performed.
- [ ] Save the updated PBIX and reopen it to confirm it loads.
- [ ] Export all seven pages using the same default filter state.
- [ ] Save genuine exports in `docs/screenshots/` with names `01-overview.png` through `07-transaction-risk.png`.
- [ ] Remove any personal connection details before publishing screenshots.

## Evidence status

This repository checklist documents the fixes to apply. It does not claim that the PBIX has been edited or that screenshots have been captured. Those steps require opening the report in Power BI Desktop and saving/exporting the actual report.
