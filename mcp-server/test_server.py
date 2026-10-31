#!/usr/bin/env python3
"""Tests for the budget MCP server."""
import json
import pytest
from server import parse_period


class TestParsePeriod:
    def test_today(self):
        start, end = parse_period("today")
        assert start == end
        assert "202" in start

    def test_this_week(self):
        start, end = parse_period("this_week")
        assert start <= end

    def test_this_month(self):
        start, end = parse_period("this_month")
        assert start <= end
        assert start.endswith("-01")

    def test_last_week(self):
        start, end = parse_period("last_week")
        assert start <= end

    def test_last_month(self):
        start, end = parse_period("last_month")
        assert start <= end

    def test_custom_range(self):
        start, end = parse_period("2026-01-01/2026-01-31")
        assert start == "2026-01-01"
        assert end == "2026-01-31"

    def test_unknown_defaults_to_current(self):
        start, end = parse_period("something_unknown")
        assert end != ""
        assert "202" in end
