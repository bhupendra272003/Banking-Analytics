"""Regression tests for the Berka cleaning helpers (no database required)."""

import unittest

import pandas as pd

from python.berka_to_mysql import (
    LOAN_STATUS_MAP,
    OPERATION_MAP,
    parse_yymmdd,
)


class BerkaCleaningTests(unittest.TestCase):
    def test_berka_date_with_timestamp_suffix(self):
        parsed = parse_yymmdd(pd.Series(["930101 00:00:00", "981231"]))
        self.assertEqual(parsed.iloc[0], pd.Timestamp("1993-01-01"))
        self.assertEqual(parsed.iloc[1], pd.Timestamp("1998-12-31"))

    def test_invalid_date_is_null_not_a_fake_date(self):
        parsed = parse_yymmdd(pd.Series(["?", "991332"]))
        self.assertTrue(parsed.isna().all())

    def test_loan_status_labels_match_dashboard_semantics(self):
        self.assertEqual(LOAN_STATUS_MAP["A"], "Finished - Paid")
        self.assertEqual(LOAN_STATUS_MAP["B"], "Finished - Not Paid")
        self.assertEqual(LOAN_STATUS_MAP["C"], "Running - OK")
        self.assertEqual(LOAN_STATUS_MAP["D"], "Running - In Debt")

    def test_cash_withdrawal_operation_is_standardized(self):
        self.assertEqual(OPERATION_MAP["VYBER"], "Cash Withdrawal")


if __name__ == "__main__":
    unittest.main()
