"""PostgreSQL database layer for budget MCP server."""
import psycopg2
import psycopg2.extras
from datetime import datetime


class BudgetDB:
    def __init__(self, dsn: str):
        self.dsn = dsn

    def _get_conn(self):
        return psycopg2.connect(self.dsn)

    def get_expenses_by_category(
        self, category_name: str, start_date: str, end_date: str
    ) -> list[dict]:
        with self._get_conn() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT e.id, e.amount, e.description, e.expense_date, e.source, c.name as category
                    FROM expenses e
                    JOIN categories c ON e.category_id = c.id
                    WHERE c.name ILIKE %s
                      AND e.expense_date >= %s
                      AND e.expense_date <= %s
                    ORDER BY e.expense_date DESC
                    """,
                    (f"%{category_name}%", start_date, end_date),
                )
                return [dict(r) for r in cur.fetchall()]

    def get_summary(self, start_date: str, end_date: str) -> list[dict]:
        with self._get_conn() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT c.name as category, c.color, COUNT(e.id) as count,
                           COALESCE(SUM(e.amount), 0) as total
                    FROM categories c
                    LEFT JOIN expenses e ON c.id = e.category_id
                        AND e.expense_date >= %s AND e.expense_date <= %s
                    GROUP BY c.name, c.color
                    ORDER BY total DESC
                    """,
                    (start_date, end_date),
                )
                return [dict(r) for r in cur.fetchall()]

    def get_monthly_trends(self, months: int) -> list[dict]:
        with self._get_conn() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT TO_CHAR(expense_date, 'YYYY-MM') as month,
                           SUM(amount) as total,
                           COUNT(id) as count
                    FROM expenses
                    WHERE expense_date >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '%s months'
                    GROUP BY 1
                    ORDER BY 1
                    """,
                    (months,),
                )
                return [dict(r) for r in cur.fetchall()]

    def get_daily_spending(self, start_date: str, end_date: str) -> list[dict]:
        with self._get_conn() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT expense_date::text as date, SUM(amount) as total, COUNT(id) as count
                    FROM expenses
                    WHERE expense_date >= %s AND expense_date <= %s
                    GROUP BY expense_date
                    ORDER BY expense_date
                    """,
                    (start_date, end_date),
                )
                return [dict(r) for r in cur.fetchall()]
