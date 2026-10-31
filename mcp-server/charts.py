"""Chart generation for budget MCP server."""
import io
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm


def _setup_style():
    plt.style.use("dark_background")


def generate_bar_chart(data: list[dict], title: str, buf: io.BytesIO) -> None:
    if not data:
        return _empty_chart(buf, title)

    _setup_style()
    categories = [d["category"] for d in data]
    totals = [float(d["total"]) for d in data]
    colors = [d.get("color", "#3B82F6") for d in data]

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.bar(categories, totals, color=colors)
    ax.set_title(title, fontsize=14)
    ax.set_ylabel("Total ($)")
    ax.tick_params(axis="x", rotation=45)
    for i, v in enumerate(totals):
        ax.text(i, v + max(totals) * 0.01, f"${v:,.0f}", ha="center", fontsize=9)
    fig.tight_layout()
    fig.savefig(buf, format="png", dpi=100)
    plt.close(fig)


def generate_pie_chart(data: list[dict], title: str, buf: io.BytesIO) -> None:
    if not data:
        return _empty_chart(buf, title)

    _setup_style()
    filtered = [d for d in data if float(d["total"]) > 0]
    if not filtered:
        return _empty_chart(buf, title)

    totals = [float(d["total"]) for d in filtered]
    labels = [f"{d['category']} (${d['total']:,.0f})" for d in filtered]
    colors = [d.get("color", "#3B82F6") for d in filtered]

    fig, ax = plt.subplots(figsize=(8, 8))
    ax.pie(totals, labels=labels, colors=colors, autopct="%1.1f%%", startangle=90)
    ax.set_title(title, fontsize=14)
    fig.tight_layout()
    fig.savefig(buf, format="png", dpi=100)
    plt.close(fig)


def generate_line_chart(data: list[dict], title: str, buf: io.BytesIO) -> None:
    if not data:
        return _empty_chart(buf, title)

    _setup_style()
    categories = [d["category"] for d in data]
    totals = [float(d["total"]) for d in data]

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(categories, totals, marker="o", linewidth=2)
    ax.fill_between(range(len(categories)), totals, alpha=0.2)
    ax.set_title(title, fontsize=14)
    ax.set_ylabel("Total ($)")
    ax.tick_params(axis="x", rotation=45)
    for i, v in enumerate(totals):
        ax.text(i, v + max(totals) * 0.02, f"${v:,.0f}", ha="center", fontsize=9)
    fig.tight_layout()
    fig.savefig(buf, format="png", dpi=100)
    plt.close(fig)


def _empty_chart(buf: io.BytesIO, title: str) -> None:
    _setup_style()
    fig, ax = plt.subplots(figsize=(6, 4))
    ax.text(0.5, 0.5, f"No data for:\n{title}", ha="center", va="center", fontsize=14)
    ax.axis("off")
    fig.savefig(buf, format="png", dpi=100)
    plt.close(fig)
