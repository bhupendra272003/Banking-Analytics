-- Focused correction / reconciliation query for the Loan Analysis page.
-- Run after loading bank_analytics and creating the v_loan view from
-- Bank_Analytics_Dashboard_Validation.sql.
--
-- Berka source status A means finished and paid. The Python loader maps it
-- to "Finished - Paid" (not "Contract finished, no problems").

SELECT
    duration,
    SUM(CASE WHEN status_desc = 'Finished - Paid' THEN 1 ELSE 0 END) AS finished_paid,
    SUM(CASE WHEN status_desc = 'Finished - Not Paid' THEN 1 ELSE 0 END) AS finished_not_paid,
    SUM(CASE WHEN is_bad_loan = 1 THEN 1 ELSE 0 END) AS bad_loans,
    COUNT(*) AS total_loans,
    ROUND(100 * SUM(is_bad_loan) / NULLIF(COUNT(*), 0), 2) AS bad_loan_rate_pct
FROM v_loan
GROUP BY duration
ORDER BY duration;

-- Status-level totals: compare these values with the Power BI loan-status visual.
SELECT
    status,
    status_desc,
    COUNT(*) AS total_loans,
    SUM(is_bad_loan) AS bad_loans,
    SUM(amount) AS total_loan_amount
FROM v_loan
GROUP BY status, status_desc
ORDER BY status;
