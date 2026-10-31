#!/usr/bin/env python3
"""
MCP Server for Budget Tracking.
Provides tools for OpenClaw to query expense data and generate charts.
"""
import os
import sys
import json
import base64
import io
from datetime import datetime, timedelta
from typing import Any

from mcp.server.fastmcp import FastMCP
from db import BudgetDB
from charts import generate_bar_chart, generate_pie_chart, generate_line_chart

mcp = FastMCP(
    "budget-tools",
    host=os.environ.get("MCP_HOST", "127.0.0.1"),
    port=int(os.environ.get("MCP_PORT", "8000")),
)

db = BudgetDB(
    os.environ.get("DATABASE_URL", "postgres://budget:change-me@localhost:5432/budget")
)


def parse_period(period: str) -> tuple[str, str]:
    today = datetime.now().date()
    if period == "today":
        return today.isoformat(), today.isoformat()
    elif period == "this_week":
        start = today - timedelta(days=today.weekday())
        return start.isoformat(), today.isoformat()
    elif period == "last_week":
        start = today - timedelta(days=today.weekday() + 7)
        end = start + timedelta(days=6)
        return start.isoformat(), end.isoformat()
    elif period == "this_month":
        start = today.replace(day=1)
        return start.isoformat(), today.isoformat()
    elif period == "last_month":
        start = (today.replace(day=1) - timedelta(days=1)).replace(day=1)
        end = today.replace(day=1) - timedelta(days=1)
        return start.isoformat(), end.isoformat()
    elif "/" in period:
        parts = period.split("/")
        return parts[0], parts[1]
    return period, today.isoformat()


@mcp.tool()
def get_expenses_by_category(category_name: str, period: str = "this_month") -> str:
    """
    Get total expenses for a specific category in a time period.

    Args:
        category_name: Category name (e.g., "alimentos", "transporte", "servicios",
                      "entretenimiento", "salud", "educacion", "hogar", "ropa", "otros")
        period: Time period. Options: "today", "this_week", "last_week", "this_month",
               "last_month", "YYYY-MM-DD/YYYY-MM-DD" for custom range
    """
    start, end = parse_period(period)
    expenses = db.get_expenses_by_category(category_name, start, end)
    total = sum(e["amount"] for e in expenses)

    result = {
        "category": category_name,
        "period": f"{start} to {end}",
        "total": round(total, 2),
        "count": len(expenses),
        "expenses": expenses,
    }
    return json.dumps(result, ensure_ascii=False, indent=2, default=str)


@mcp.tool()
def get_expenses_summary(
    period_start: str = "", period_end: str = "", period: str = "this_month"
) -> str:
    """
    Get spending summary grouped by category for a period.

    Args:
        period_start: Start date (YYYY-MM-DD). Optional, use period instead.
        period_end: End date (YYYY-MM-DD). Optional, use period instead.
        period: Preset period. "today", "this_week", "last_week", "this_month", "last_month"
    """
    if not period_start:
        period_start, period_end = parse_period(period)
    elif not period_end:
        period_end = datetime.now().date().isoformat()

    summary = db.get_summary(period_start, period_end)
    result = {
        "period": f"{period_start} to {period_end}",
        "total": round(sum(s["total"] for s in summary), 2),
        "by_category": summary,
    }
    return json.dumps(result, ensure_ascii=False, indent=2, default=str)


@mcp.tool()
def get_expense_chart(
    period_start: str = "",
    period_end: str = "",
    chart_type: str = "bar",
    period: str = "this_month",
) -> dict:
    """
    Generate a chart image of expenses by category.

    Args:
        period_start: Start date (YYYY-MM-DD)
        period_end: End date (YYYY-MM-DD)
        chart_type: Chart type. Options: "bar", "pie", "line"
        period: Preset period if start/end not provided
    """
    if not period_start:
        period_start, period_end = parse_period(period)
    elif not period_end:
        period_end = datetime.now().date().isoformat()

    data = db.get_summary(period_start, period_end)
    title = f"Gastos ({period_start} a {period_end})"

    buf = io.BytesIO()
    if chart_type == "pie":
        generate_pie_chart(data, title, buf)
    elif chart_type == "line":
        generate_line_chart(data, title, buf)
    else:
        generate_bar_chart(data, title, buf)

    buf.seek(0)
    img_b64 = base64.b64encode(buf.read()).decode()

    return {
        "type": "image",
        "mimeType": "image/png",
        "data": img_b64,
        "description": f"{chart_type} chart: {title}",
    }


@mcp.tool()
def get_monthly_trends(months: int = 6) -> str:
    """
    Get monthly spending trends for the last N months.

    Args:
        months: Number of months to look back (default: 6)
    """
    trends = db.get_monthly_trends(months)
    result = {"months": months, "trends": trends}
    return json.dumps(result, ensure_ascii=False, indent=2, default=str)


@mcp.tool()
def get_weekly_spending() -> str:
    """
    Get daily spending breakdown for the current week.
    """
    today = datetime.now().date()
    start = today - timedelta(days=today.weekday())

    spending = db.get_daily_spending(start.isoformat(), today.isoformat())
    total = sum(d["total"] for d in spending)

    result = {
        "week_start": start.isoformat(),
        "week_end": today.isoformat(),
        "daily": spending,
        "total": round(total, 2),
    }
    return json.dumps(result, ensure_ascii=False, indent=2, default=str)


if __name__ == "__main__":
    # stdio por defecto (dev local); para OpenClaw se sirve por HTTP
    # (streamable-http) dentro de un contenedor en apps-network.
    transport = os.environ.get("MCP_TRANSPORT", "stdio")
    mcp.run(transport=transport)
