/* ======================================================================
   BANK ANALYTICS DASHBOARD - SQL VALIDATION
   Database : bank_analytics (Berka dataset)
   Purpose  : Re-calculate every dashboard visual in SQL and compare it
              with the Power BI output.

   Sections
     0. Setup              - helper views and slicer variables
     1. Dashboard checks   - page-wise, one query per visual
     2. Data quality       - row counts, duplicates, orphans, nulls
     3. Year-wise check    - which date drives the Calendar relationship
     4. Risk and fraud     - negative balances, outliers, bad loans
     5. Loan analysis      - default patterns by duration, region, amount
     6. Customer and region- cards, salary, balance, activity
     7. Window functions   - ranking, running totals, latest balance

   How to use: run Section 0 once, then run any query on its own.
   Slicers: NULL = All. For several values use a comma list, e.g.
   SET @regions = 'north Moravia,Prague';
   ====================================================================== */

USE bank_analytics;


-- ======================================================================
-- 0. SETUP
-- ======================================================================

-- Account joined with district
CREATE OR REPLACE VIEW v_account AS
SELECT a.account_id, a.frequency, a.open_date, YEAR(a.open_date) AS open_year,
       d.district_id, d.district_name, d.region
FROM account a
JOIN district d ON a.district_id = d.district_id;

-- Client with age band (age as of 1998) and district
CREATE OR REPLACE VIEW v_client AS
SELECT c.client_id, c.gender, c.age_at_1998,
       CASE WHEN c.age_at_1998 < 25 THEN '18-24'
            WHEN c.age_at_1998 < 35 THEN '25-34'
            WHEN c.age_at_1998 < 45 THEN '35-44'
            WHEN c.age_at_1998 < 55 THEN '45-54'
            WHEN c.age_at_1998 < 65 THEN '55-64'
            ELSE '65+' END AS age_band,
       d.district_id, d.district_name, d.region
FROM client c
JOIN district d ON c.district_id = d.district_id;

-- Transactions with the district of the account holder
CREATE OR REPLACE VIEW v_trans AS
SELECT t.trans_id, t.account_id, t.trans_date, t.trans_year, t.trans_month,
       t.trans_type, t.operation, t.amount, t.balance, t.signed_amount, t.payment_purpose,
       YEAR(a.open_date) AS open_year,
       d.district_id, d.district_name, d.region
FROM transactions t
JOIN account  a ON t.account_id  = a.account_id
JOIN district d ON a.district_id = d.district_id;

-- Loans with the district of the account
CREATE OR REPLACE VIEW v_loan AS
SELECT l.loan_id, l.account_id, l.amount, l.duration, l.payments,
       l.status, l.status_desc, l.is_bad_loan,
       l.loan_date, YEAR(l.loan_date) AS loan_year, MONTH(l.loan_date) AS loan_month,
       YEAR(a.open_date) AS open_year,
       d.district_id, d.district_name, d.region
FROM loan l
JOIN account  a ON l.account_id  = a.account_id
JOIN district d ON a.district_id = d.district_id;

-- Cards with the district of the card holder (client)
CREATE OR REPLACE VIEW v_card AS
SELECT cd.card_id, cd.card_type, cd.issued_date, c.gender,
       d.district_id, d.district_name, d.region
FROM card cd
JOIN authorization dp ON cd.disp_id   = dp.disp_id
JOIN client        c  ON dp.client_id = c.client_id
JOIN district      d  ON c.district_id = d.district_id;

-- Slicer variables (NULL = All)
SET @regions   = NULL;   -- Region
SET @districts = NULL;   -- District name
SET @years     = NULL;   -- Year
SET @genders   = NULL;   -- Gender: 'Female' / 'Male'
SET @durations = NULL;   -- Loan duration: 12, 24, 36, 48, 60
SET @ttypes    = NULL;   -- Transaction type: 'Credit' / 'Debit'


-- ======================================================================
-- 1. DASHBOARD CHECKS (page-wise)
-- ======================================================================

-- ----------------------------------------------------------------------
-- Page 1: TRANSACTION                                   Slicer: Year
-- ----------------------------------------------------------------------

-- KPI cards: transactions, credits, debits, amount, net cash flow, clients, accounts
SELECT COUNT(*)                                                      AS `Total Transactions`,
       SUM(CASE WHEN trans_type = 'Credit' THEN amount ELSE 0 END)   AS `Total Credits`,
       SUM(CASE WHEN trans_type = 'Debit'  THEN amount ELSE 0 END)   AS `Total Debits`,
       SUM(amount)                                                   AS `Total Txn Amount`,
       SUM(signed_amount)                                            AS `Net Cash Flow`,
       (SELECT COUNT(*) FROM client)                                 AS `Total Clients`,
       (SELECT COUNT(*) FROM account)                                AS `Total Accounts`
FROM v_trans
WHERE (@years IS NULL OR FIND_IN_SET(trans_year, @years));

-- Total Transactions by Year
SELECT trans_year, COUNT(*) AS `Total Transactions`
FROM v_trans
GROUP BY trans_year
ORDER BY trans_year;

-- Total Credits and Total Debits by Year (line chart)
SELECT trans_year,
       SUM(CASE WHEN trans_type = 'Credit' THEN amount ELSE 0 END) AS `Total Credits`,
       SUM(CASE WHEN trans_type = 'Debit'  THEN amount ELSE 0 END) AS `Total Debits`
FROM v_trans
GROUP BY trans_year
ORDER BY trans_year;

-- Total Txn Amount by Transaction Type (donut)
SELECT trans_type,
       SUM(amount) AS `Total Txn Amount`,
       ROUND(100 * SUM(amount) / SUM(SUM(amount)) OVER (), 2) AS pct
FROM v_trans
WHERE (@years IS NULL OR FIND_IN_SET(trans_year, @years))
GROUP BY trans_type;

-- Avg Balance, Avg Loan Amount, Bad Loan Amount (pie)
SELECT (SELECT ROUND(AVG(balance), 2) FROM transactions)          AS `Avg Balance`,
       (SELECT ROUND(AVG(amount), 2)  FROM loan)                  AS `Avg Loan Amount`,
       (SELECT SUM(amount) FROM loan WHERE is_bad_loan = 1)       AS `Bad Loan Amount`;


-- ----------------------------------------------------------------------
-- Page 2: LOAN                                          Slicers: Year, Duration
-- (Year is assumed to be the loan issue year)
-- ----------------------------------------------------------------------

-- KPI cards: loans, amount, average, bad loan amount, default rate, exposure at risk
SELECT COUNT(*)                                                    AS `Total Loans`,
       SUM(amount)                                                 AS `Total Loan Amount`,
       ROUND(AVG(amount), 2)                                       AS `Avg Loan Amount`,
       SUM(CASE WHEN is_bad_loan = 1 THEN amount ELSE 0 END)       AS `Bad Loan Amount`,
       ROUND(SUM(is_bad_loan) / COUNT(*), 4)                       AS `Default Rate %`,
       ROUND(SUM(CASE WHEN is_bad_loan = 1 THEN amount ELSE 0 END) / SUM(amount), 4) AS `Exposure at Risk %`
FROM v_loan
WHERE (@years     IS NULL OR FIND_IN_SET(loan_year, @years))
  AND (@durations IS NULL OR FIND_IN_SET(duration, @durations));

-- Total Loans by Status (donut)
SELECT status_desc,
       COUNT(*) AS `Total Loans`,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM v_loan
WHERE (@years     IS NULL OR FIND_IN_SET(loan_year, @years))
  AND (@durations IS NULL OR FIND_IN_SET(duration, @durations))
GROUP BY status_desc;

-- Default Rate % by Duration (column chart)
SELECT duration,
       COUNT(*)                              AS loans,
       SUM(is_bad_loan)                      AS bad_loans,
       ROUND(SUM(is_bad_loan) / COUNT(*), 4) AS `Default Rate %`
FROM v_loan
WHERE (@years IS NULL OR FIND_IN_SET(loan_year, @years))
GROUP BY duration
ORDER BY duration;

-- Sum of Payments and Total Loan Amount by Duration (scatter)
SELECT duration,
       SUM(payments) AS `Sum of payments`,
       SUM(amount)   AS `Total Loan Amount`
FROM v_loan
WHERE (@years IS NULL OR FIND_IN_SET(loan_year, @years))
GROUP BY duration
ORDER BY duration;


-- ----------------------------------------------------------------------
-- Page 3: BALANCE                                       Slicers: Region, Transaction Type
-- ----------------------------------------------------------------------

-- KPI cards: balance, cash flow, credit/debit ratio, cash share, negative share, txns per account
SELECT ROUND(AVG(balance), 2)                                                      AS `Avg Balance`,
       SUM(signed_amount)                                                          AS `Net Cash Flow`,
       ROUND(SUM(CASE WHEN trans_type = 'Credit' THEN amount ELSE 0 END)
           / NULLIF(SUM(CASE WHEN trans_type = 'Debit' THEN amount ELSE 0 END), 0), 4) AS `Credit to Debit Ratio`,
       ROUND(SUM(operation = 'Cash Withdrawal') / COUNT(*), 4)                     AS `Cash Withdrawal Share %`,
       ROUND(SUM(balance < 0) / COUNT(*), 6)                                       AS `Negative Balance Txns %`,
       ROUND(COUNT(*) / COUNT(DISTINCT account_id), 2)                             AS `Avg Txns per Account`
FROM v_trans
WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
  AND (@ttypes  IS NULL OR FIND_IN_SET(trans_type, @ttypes));

-- Cash Withdrawal Share % by Year
-- Uses transaction year. If the dashboard matches account open year instead, see Section 3.
SELECT trans_year,
       COUNT(*)                                                AS total_txns,
       SUM(operation = 'Cash Withdrawal')                      AS cash_withdrawals,
       ROUND(SUM(operation = 'Cash Withdrawal') / COUNT(*), 3) AS `Cash Withdrawal Share %`
FROM v_trans
WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
GROUP BY trans_year
ORDER BY trans_year;

-- Total Credits and Total Debits by Year
SELECT trans_year,
       SUM(CASE WHEN trans_type = 'Credit' THEN amount ELSE 0 END) AS `Total Credits`,
       SUM(CASE WHEN trans_type = 'Debit'  THEN amount ELSE 0 END) AS `Total Debits`
FROM v_trans
WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
GROUP BY trans_year
ORDER BY trans_year;

-- Avg Balance by Year
SELECT trans_year, ROUND(AVG(balance), 1) AS `Avg Balance`
FROM v_trans
WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
  AND (@ttypes  IS NULL OR FIND_IN_SET(trans_type, @ttypes))
GROUP BY trans_year
ORDER BY trans_year;

-- Sum of Amount by Operation
SELECT operation, SUM(amount) AS `Sum of amount`
FROM v_trans
WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
  AND (@ttypes  IS NULL OR FIND_IN_SET(trans_type, @ttypes))
GROUP BY operation
ORDER BY `Sum of amount` DESC;


-- ----------------------------------------------------------------------
-- Page 4: CARD                                          Slicers: Region, Gender
-- Region comes from the client's district.
-- ----------------------------------------------------------------------

-- KPI cards: cards, gold share, age, female share, salary, unemployment
SELECT (SELECT COUNT(*) FROM v_card
         WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
           AND (@genders IS NULL OR FIND_IN_SET(gender, @genders)))                 AS `Cards Issued`,
       (SELECT ROUND(SUM(card_type = 'gold') / COUNT(*), 4) FROM v_card
         WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
           AND (@genders IS NULL OR FIND_IN_SET(gender, @genders)))                 AS `Gold Card %`,
       (SELECT ROUND(AVG(age_at_1998), 2) FROM v_client
         WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
           AND (@genders IS NULL OR FIND_IN_SET(gender, @genders)))                 AS `Avg Client Age`,
       (SELECT ROUND(SUM(gender = 'Female') / COUNT(*), 4) FROM v_client
         WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions)))                 AS `Female Clients %`,
       (SELECT ROUND(AVG(avg_salary), 2) FROM district
         WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions)))                 AS `Avg District Salary`,
       (SELECT ROUND(AVG(unemployment_rate_96), 2) FROM district
         WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions)))                 AS `Avg Unemployment Rate %`;

-- Total Clients by Age Group
SELECT age_band, COUNT(*) AS `Total Clients`
FROM v_client
WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
  AND (@genders IS NULL OR FIND_IN_SET(gender, @genders))
GROUP BY age_band
ORDER BY age_band;

-- Total Clients by Gender (donut)
SELECT gender,
       COUNT(*) AS `Total Clients`,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM v_client
WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
GROUP BY gender;

-- Avg Unemployment Rate % by Region
SELECT region, ROUND(AVG(unemployment_rate_96), 2) AS `Avg Unemployment Rate %`
FROM district
GROUP BY region
ORDER BY 2 DESC;

-- Active Accounts by Region (pie): accounts with at least one transaction
SELECT region,
       COUNT(DISTINCT account_id) AS `Active Accounts`,
       ROUND(100 * COUNT(DISTINCT account_id) / SUM(COUNT(DISTINCT account_id)) OVER (), 2) AS pct
FROM v_trans
GROUP BY region
ORDER BY 2 DESC;


-- ----------------------------------------------------------------------
-- Page 5: CUSTOMER ANALYSIS                             Slicers: District Name, Gender
-- ----------------------------------------------------------------------

-- KPI cards: clients, average age, female and male share
SELECT COUNT(*)                                  AS `Total Clients`,
       ROUND(AVG(age_at_1998), 2)                AS `Avg Client Age`,
       ROUND(SUM(gender = 'Female') / COUNT(*), 4) AS `Female Clients %`,
       ROUND(SUM(gender = 'Male')   / COUNT(*), 4) AS `Male Clients %`
FROM v_client
WHERE (@districts IS NULL OR FIND_IN_SET(district_name, @districts))
  AND (@genders   IS NULL OR FIND_IN_SET(gender, @genders));

-- Customer Gender Distribution (donut)
SELECT gender, COUNT(*) AS `Total Clients`
FROM v_client
WHERE (@districts IS NULL OR FIND_IN_SET(district_name, @districts))
GROUP BY gender;

-- Total Clients by District
-- The visual-level filter in the report is Bottom 10; Top 10 is given for comparison.
SELECT district_name, COUNT(*) AS `Total Clients`
FROM v_client
GROUP BY district_name
ORDER BY 2 ASC, 1
LIMIT 10;

SELECT district_name, COUNT(*) AS `Total Clients`
FROM v_client
GROUP BY district_name
ORDER BY 2 DESC, 1
LIMIT 10;

-- New vs Repeat Customers
-- ASSUMPTION: the DAX for these two measures was not available.
-- New = client whose first account opened in that year; Repeat = client with more than one account.
-- Adjust once the actual DAX definition is confirmed.
SELECT SUM(first_open_year IS NOT NULL) AS `Total New Customers`,
       SUM(acc_cnt > 1)                 AS `Total Repeat Customers`
FROM (
    SELECT c.client_id,
           MIN(YEAR(a.open_date))       AS first_open_year,
           COUNT(DISTINCT a.account_id) AS acc_cnt
    FROM client c
    JOIN authorization dp ON dp.client_id  = c.client_id
    JOIN account       a  ON a.account_id  = dp.account_id
    GROUP BY c.client_id
) x;

SELECT first_open_year AS yr, COUNT(*) AS `New Customers`
FROM (
    SELECT c.client_id, MIN(YEAR(a.open_date)) AS first_open_year
    FROM client c
    JOIN authorization dp ON dp.client_id = c.client_id
    JOIN account       a  ON a.account_id = dp.account_id
    GROUP BY c.client_id
) x
GROUP BY first_open_year
ORDER BY yr;


-- ----------------------------------------------------------------------
-- Page 6: FRAUD DETECTION ANALYSIS                      Slicers: Transaction Type, District Name
-- ----------------------------------------------------------------------

-- KPI cards
-- Accounts with Negative Balance: accounts that ever had balance < 0 (assumed definition)
SELECT COUNT(*)                                                 AS `Total Transactions`,
       COUNT(DISTINCT account_id)                               AS `Active Accounts`,
       ROUND(SUM(operation = 'Cash Withdrawal') / COUNT(*), 4)  AS `Cash Withdrawal Share %`,
       ROUND(SUM(balance < 0) / COUNT(*), 6)                    AS `Negative Balance Txns %`,
       COUNT(DISTINCT CASE WHEN balance < 0 THEN account_id END) AS `Accounts with Negative Balance`,
       (SELECT SUM(is_bad_loan) FROM loan)                      AS `Bad Loans`
FROM v_trans
WHERE (@ttypes    IS NULL OR FIND_IN_SET(trans_type, @ttypes))
  AND (@districts IS NULL OR FIND_IN_SET(district_name, @districts));

-- Total Transactions by Transaction Type (donut)
SELECT trans_type,
       COUNT(*) AS `Total Transactions`,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM v_trans
WHERE (@districts IS NULL OR FIND_IN_SET(district_name, @districts))
GROUP BY trans_type;

-- Total Transactions by Operation
SELECT operation, COUNT(*) AS `Total Transactions`
FROM v_trans
WHERE (@ttypes    IS NULL OR FIND_IN_SET(trans_type, @ttypes))
  AND (@districts IS NULL OR FIND_IN_SET(district_name, @districts))
GROUP BY operation
ORDER BY 2 DESC;

-- Top 10 Districts by Negative Balance Txns %
SELECT district_name,
       COUNT(*)                         AS txns,
       SUM(balance < 0)                 AS neg_txns,
       ROUND(SUM(balance < 0) / COUNT(*), 6) AS `Negative Balance Txns %`
FROM v_trans
GROUP BY district_name
ORDER BY 4 DESC, 1
LIMIT 10;


-- ----------------------------------------------------------------------
-- Page 7: DASHBOARD (overview)                          Slicer: Region
-- ----------------------------------------------------------------------

-- KPI cards
SELECT (SELECT COUNT(*) FROM v_client  WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions)))                AS `Total Clients`,
       (SELECT COUNT(*) FROM v_account WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions)))                AS `Total Accounts`,
       (SELECT ROUND(AVG(balance), 2) FROM v_trans WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions)))    AS `Avg Balance`,
       (SELECT COUNT(*) FROM v_loan    WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions)))                AS `Total Loans`,
       (SELECT ROUND(SUM(is_bad_loan) / COUNT(*), 4) FROM v_loan WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))) AS `Default Rate %`,
       (SELECT SUM(signed_amount) FROM v_trans WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions)))        AS `Net Cash Flow`;

-- Customer Distribution by Age Group
SELECT age_band, COUNT(*) AS `Total Clients`
FROM v_client
WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
GROUP BY age_band
ORDER BY age_band;

-- Regional Loan Performance
SELECT region,
       SUM(amount)                           AS `Sum of amount`,
       ROUND(SUM(is_bad_loan) / COUNT(*), 4) AS `Default Rate %`
FROM v_loan
WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
GROUP BY region
ORDER BY 3 DESC;

-- Cash Withdrawal Share Trend
SELECT trans_year,
       ROUND(SUM(operation = 'Cash Withdrawal') / COUNT(*), 4) AS `Cash Withdrawal Share %`
FROM v_trans
WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
GROUP BY trans_year
ORDER BY trans_year;

-- Total Transactions by Operation
SELECT operation, COUNT(*) AS `Total Transactions`
FROM v_trans
WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
GROUP BY operation
ORDER BY 2 DESC;

-- Credit vs Debit Distribution (donut)
SELECT trans_type,
       SUM(amount) AS amount,
       ROUND(100 * SUM(amount) / SUM(SUM(amount)) OVER (), 2) AS pct
FROM v_trans
WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
GROUP BY trans_type;

-- Top 10 Districts by Transactions (tooltip: Total Txn Amount)
SELECT district_name,
       COUNT(*)    AS `Total Transactions`,
       SUM(amount) AS `Total Txn Amount`
FROM v_trans
WHERE (@regions IS NULL OR FIND_IN_SET(region, @regions))
GROUP BY district_name
ORDER BY 2 DESC
LIMIT 10;


-- ======================================================================
-- 2. DATA QUALITY AND RECONCILIATION
-- ======================================================================

-- Row counts: base tables vs views (a difference means the join dropped rows)
SELECT 'transactions' AS tbl, (SELECT COUNT(*) FROM transactions) AS base_rows, (SELECT COUNT(*) FROM v_trans)   AS view_rows
UNION ALL SELECT 'loan',    (SELECT COUNT(*) FROM loan),    (SELECT COUNT(*) FROM v_loan)
UNION ALL SELECT 'client',  (SELECT COUNT(*) FROM client),  (SELECT COUNT(*) FROM v_client)
UNION ALL SELECT 'account', (SELECT COUNT(*) FROM account), (SELECT COUNT(*) FROM v_account)
UNION ALL SELECT 'card',    (SELECT COUNT(*) FROM card),    (SELECT COUNT(*) FROM v_card);

-- Distinct category values (typos or stray spaces break filters such as 'Cash Withdrawal')
SELECT 'operation' AS col, operation AS val, COUNT(*) AS n FROM transactions GROUP BY operation
UNION ALL SELECT 'trans_type',  trans_type,  COUNT(*) FROM transactions GROUP BY trans_type
UNION ALL SELECT 'card_type',   card_type,   COUNT(*) FROM card         GROUP BY card_type
UNION ALL SELECT 'status_desc', status_desc, COUNT(*) FROM loan         GROUP BY status_desc;

-- Duplicate primary keys
SELECT 'transactions' AS tbl, COUNT(*) - COUNT(DISTINCT trans_id) AS duplicate_ids FROM transactions
UNION ALL SELECT 'loan',    COUNT(*) - COUNT(DISTINCT loan_id)    FROM loan
UNION ALL SELECT 'client',  COUNT(*) - COUNT(DISTINCT client_id)  FROM client
UNION ALL SELECT 'account', COUNT(*) - COUNT(DISTINCT account_id) FROM account;

-- Orphan records (child row without a matching parent)
SELECT 'transactions without account' AS check_name, COUNT(*) AS n
FROM transactions t LEFT JOIN account a ON a.account_id = t.account_id
WHERE a.account_id IS NULL
UNION ALL
SELECT 'loans without account', COUNT(*)
FROM loan l LEFT JOIN account a ON a.account_id = l.account_id
WHERE a.account_id IS NULL
UNION ALL
SELECT 'accounts without district', COUNT(*)
FROM account a LEFT JOIN district d ON d.district_id = a.district_id
WHERE d.district_id IS NULL
UNION ALL
SELECT 'accounts with no transactions', COUNT(*)
FROM account a LEFT JOIN transactions t ON t.account_id = a.account_id
WHERE t.trans_id IS NULL;

-- Null and invalid values in transactions
SELECT SUM(amount IS NULL)                          AS null_amount,
       SUM(balance IS NULL)                         AS null_balance,
       SUM(amount <= 0)                             AS non_positive_amount,
       SUM(operation IS NULL OR operation = '')     AS blank_operation
FROM transactions;

-- signed_amount direction: Credit should be positive, Debit negative
SELECT trans_type, SUM(signed_amount > 0) AS positive, SUM(signed_amount < 0) AS negative
FROM transactions
GROUP BY trans_type;


-- ======================================================================
-- 3. YEAR-WISE CHECK
-- Dashboard year values can differ from SQL when the Calendar table is
-- related to a different date column. Compare both bases here and keep the
-- one that matches the dashboard.
-- ======================================================================

-- Transaction metrics by transaction year vs account open year
SELECT 'trans_year' AS date_base, trans_year AS yr, COUNT(*) AS txns,
       SUM(CASE WHEN trans_type = 'Credit' THEN amount ELSE 0 END) AS credits,
       SUM(CASE WHEN trans_type = 'Debit'  THEN amount ELSE 0 END) AS debits,
       ROUND(AVG(balance), 1)                                      AS avg_balance,
       ROUND(SUM(operation = 'Cash Withdrawal') / COUNT(*), 3)     AS cash_share
FROM v_trans
GROUP BY trans_year
UNION ALL
SELECT 'open_year', open_year, COUNT(*),
       SUM(CASE WHEN trans_type = 'Credit' THEN amount ELSE 0 END),
       SUM(CASE WHEN trans_type = 'Debit'  THEN amount ELSE 0 END),
       ROUND(AVG(balance), 1),
       ROUND(SUM(operation = 'Cash Withdrawal') / COUNT(*), 3)
FROM v_trans
GROUP BY open_year
ORDER BY date_base, yr;

-- Volume of accounts, loans and cards per year
SELECT 'accounts opened' AS metric, YEAR(open_date)   AS yr, COUNT(*) AS n FROM account GROUP BY YEAR(open_date)
UNION ALL
SELECT 'loans issued',   YEAR(loan_date),   COUNT(*) FROM loan GROUP BY YEAR(loan_date)
UNION ALL
SELECT 'cards issued',   YEAR(issued_date), COUNT(*) FROM card GROUP BY YEAR(issued_date)
ORDER BY metric, yr;

-- Net Cash Flow with previous year and YoY % (matches DAX: DIVIDE(NCF - PY, ABS(PY), 0))
SELECT yr, net_cash_flow, py,
       ROUND(IFNULL((net_cash_flow - py) / NULLIF(ABS(py), 0), 0), 4) AS yoy_pct
FROM (
    SELECT trans_year AS yr,
           SUM(signed_amount) AS net_cash_flow,
           LAG(SUM(signed_amount)) OVER (ORDER BY trans_year) AS py
    FROM v_trans
    GROUP BY trans_year
) x
ORDER BY yr;

-- Monthly Net Cash Flow
SELECT trans_year, trans_month, COUNT(*) AS txns, SUM(signed_amount) AS net_cash_flow
FROM v_trans
GROUP BY trans_year, trans_month
ORDER BY trans_year, trans_month;


-- ======================================================================
-- 4. RISK AND FRAUD
-- ======================================================================

-- Accounts that most often had a negative balance
SELECT account_id, COUNT(*) AS negative_txns, MIN(balance) AS lowest_balance
FROM v_trans
WHERE balance < 0
GROUP BY account_id
ORDER BY negative_txns DESC
LIMIT 20;

-- Largest single transactions
SELECT trans_id, account_id, trans_date, trans_type, operation, amount, balance
FROM transactions
ORDER BY amount DESC
LIMIT 20;

-- Transactions more than 5x the account's own average
SELECT t.trans_id, t.account_id, t.trans_date, t.operation, t.amount,
       ROUND(a.avg_amt, 2) AS account_avg
FROM transactions t
JOIN (SELECT account_id, AVG(amount) AS avg_amt
      FROM transactions
      GROUP BY account_id) a ON a.account_id = t.account_id
WHERE t.amount > 5 * a.avg_amt
ORDER BY t.amount DESC
LIMIT 20;

-- Accounts with 5 or more transactions on the same day
SELECT account_id, trans_date, COUNT(*) AS txns_that_day, SUM(amount) AS total_amount
FROM transactions
GROUP BY account_id, trans_date
HAVING COUNT(*) >= 5
ORDER BY txns_that_day DESC, total_amount DESC
LIMIT 20;

-- Balance profile of accounts with bad loans
SELECT l.loan_id, l.account_id, l.amount AS loan_amount, l.status_desc,
       ROUND(AVG(t.balance), 1) AS avg_balance,
       MIN(t.balance)           AS min_balance
FROM loan l
JOIN transactions t ON t.account_id = l.account_id
WHERE l.is_bad_loan = 1
GROUP BY l.loan_id, l.account_id, l.amount, l.status_desc
ORDER BY l.amount DESC
LIMIT 20;


-- ======================================================================
-- 5. LOAN ANALYSIS
-- ======================================================================

-- Loan outcome by duration
SELECT duration,
       SUM(status_desc = 'Contract finished, no problems') AS finished_ok,
       SUM(is_bad_loan = 1)                                AS bad_loans,
       COUNT(*)                                            AS total_loans
FROM v_loan
GROUP BY duration
ORDER BY duration;

-- Default rate by region
SELECT region,
       COUNT(*)                              AS loans,
       SUM(amount)                           AS loan_amount,
       SUM(is_bad_loan)                      AS bad_loans,
       ROUND(SUM(is_bad_loan) / COUNT(*), 4) AS default_rate
FROM v_loan
GROUP BY region
ORDER BY default_rate DESC;

-- Highest default rate by district (districts with at least 10 loans)
SELECT district_name,
       COUNT(*)                              AS loans,
       ROUND(SUM(is_bad_loan) / COUNT(*), 4) AS default_rate
FROM v_loan
GROUP BY district_name
HAVING COUNT(*) >= 10
ORDER BY default_rate DESC
LIMIT 10;

-- Default rate by loan amount band
SELECT CASE WHEN amount < 50000  THEN '<50K'
            WHEN amount < 100000 THEN '50-100K'
            WHEN amount < 200000 THEN '100-200K'
            ELSE '200K+' END                 AS amount_band,
       COUNT(*)                              AS loans,
       ROUND(SUM(is_bad_loan) / COUNT(*), 4) AS default_rate
FROM loan
GROUP BY amount_band
ORDER BY MIN(amount);

-- Average amount, instalment and implied interest cost by duration
SELECT duration,
       ROUND(AVG(amount), 0)                       AS avg_amount,
       ROUND(AVG(payments), 0)                     AS avg_payment,
       ROUND(AVG(payments * duration - amount), 0) AS avg_interest_cost
FROM loan
GROUP BY duration
ORDER BY duration;


-- ======================================================================
-- 6. CUSTOMER AND REGION
-- ======================================================================

-- Card type by age band
SELECT c.age_band,
       SUM(cd.card_type = 'classic') AS classic,
       SUM(cd.card_type = 'gold')    AS gold,
       SUM(cd.card_type = 'junior')  AS junior,
       COUNT(*)                      AS total_cards
FROM card cd
JOIN authorization dp ON dp.disp_id   = cd.disp_id
JOIN v_client      c  ON c.client_id  = dp.client_id
GROUP BY c.age_band
ORDER BY c.age_band;

-- Region summary: clients, accounts, salary, unemployment
SELECT d.region,
       COUNT(DISTINCT c.client_id)          AS clients,
       COUNT(DISTINCT a.account_id)         AS accounts,
       ROUND(AVG(d.avg_salary), 0)          AS avg_salary,
       ROUND(AVG(d.unemployment_rate_96), 2) AS unemployment
FROM district d
LEFT JOIN client  c ON c.district_id = d.district_id
LEFT JOIN account a ON a.district_id = d.district_id
GROUP BY d.region
ORDER BY clients DESC;

-- District salary vs average account balance
SELECT d.district_name, d.avg_salary, ROUND(AVG(t.balance), 0) AS avg_balance
FROM v_trans t
JOIN district d ON d.district_id = t.district_id
GROUP BY d.district_name, d.avg_salary
ORDER BY avg_balance DESC
LIMIT 15;

-- Account activity by region
SELECT region,
       COUNT(*)                                          AS txns,
       COUNT(DISTINCT account_id)                        AS accounts,
       ROUND(COUNT(*) / COUNT(DISTINCT account_id), 1)   AS txns_per_account
FROM v_trans
GROUP BY region
ORDER BY txns_per_account DESC;

-- Transactions by balance bucket
SELECT CASE WHEN balance < 0      THEN 'Negative'
            WHEN balance < 10000  THEN '0-10K'
            WHEN balance < 50000  THEN '10-50K'
            WHEN balance < 100000 THEN '50-100K'
            ELSE '100K+' END AS balance_bucket,
       COUNT(*) AS txns
FROM transactions
GROUP BY balance_bucket
ORDER BY MIN(balance);


-- ======================================================================
-- 7. WINDOW FUNCTIONS
-- ======================================================================

-- Districts ranked by transaction amount within each region
SELECT region, district_name, SUM(amount) AS txn_amount,
       RANK() OVER (PARTITION BY region ORDER BY SUM(amount) DESC) AS rank_in_region
FROM v_trans
GROUP BY region, district_name
ORDER BY region, rank_in_region;

-- Running total of Net Cash Flow by month
SELECT trans_year, trans_month,
       SUM(signed_amount) AS monthly_ncf,
       SUM(SUM(signed_amount)) OVER (ORDER BY trans_year, trans_month) AS running_ncf
FROM v_trans
GROUP BY trans_year, trans_month
ORDER BY trans_year, trans_month;

-- Latest balance of each account
SELECT account_id, trans_date, balance
FROM (
    SELECT account_id, trans_date, balance,
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY trans_date DESC, trans_id DESC) AS rn
    FROM transactions
) x
WHERE rn = 1
ORDER BY balance DESC
LIMIT 20;