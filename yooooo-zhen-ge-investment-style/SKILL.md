---
name: yooooo-zhen-ge-investment-style
description: Use when evaluating U.S. equity market trends, AI and technology themes, individual targets, portfolio exposure, buy/sell/hedge decisions, or weekly market reports through the investment framework distilled from Zhen Ge's 2026 weekly reports. Helps convert market evidence into a structured bull/bear scorecard, position band, watchlist, and invalidation rules.
---

# Zhen Ge Investment Style

Use this skill as an analysis framework, not as financial advice. Always state the time horizon, data freshness, uncertainty, and invalidation conditions.

## Quick Workflow

1. Define the question: market index, sector/theme, or individual target; short-term trade or medium-term trend.
2. Build an evidence table across eight dimensions:
   - Price trend and technicals
   - Valuation and earnings
   - Macro and inflation
   - Rates, liquidity, and credit
   - Sentiment and positioning
   - Fund flows and market structure
   - AI/technology fundamental drivers
   - Event and tail risks
3. For each dimension, list both bullish and bearish evidence before concluding.
4. Classify the regime:
   - Structural bull pullback
   - Crowded/overheated advance
   - Rangebound high-volatility market
   - Local tail-risk shock
   - Systemic risk
5. Convert the regime into a position band, add/reduce plan, hedges, and watchlist.

Read [references/rules.md](references/rules.md) when you need the full rulebook, indicator checklist, or output template.

## Core Rules

- Use indexes as the core and individual stocks as satellites. Prefer QQQ/Nasdaq 100/S&P 500 exposure for the main trend; keep single-name risk sized and evidence-based.
- Treat 10%+ index drawdowns as opportunities only when systemic risk is absent, earnings and AI/capex fundamentals remain intact, valuation has reset, and sentiment/positioning has washed out.
- Add exposure in preplanned tranches, not from headlines. Use drawdown levels, valuation percentiles, 200-day moving averages, and sentiment extremes as anchors.
- Reduce beta after violent rebounds, extreme overbought readings, or stretched valuation. Clear calls/levered ETF exposure first, then trim targets that reached valuation or price objectives.
- Respect rates as the denominator. Rising 10Y/30Y yields, hawkish Fed repricing, and weak Treasury auctions can cap equity multiples even when earnings are strong.
- Use hedges tactically when tail risk is unresolved: QQQ puts, VIX/VIXY-style exposure, or partial short-term hedges. Remove hedges when the event path improves or the market already prices the risk.
- For bonds, treat TLT as a tactical cash substitute only when 10Y yield is attractive relative to the equity opportunity set; exit when yields normalize or better equity opportunities appear.
- For AI targets, require evidence beyond narrative: capex revisions, ARR, order backlog, token economics, deployment cadence, margin impact, and supply-chain transmission.

## Output Shape

Return:

1. Regime call and confidence.
2. Evidence table with bullish, bearish, and neutral factors.
3. Position band and action plan.
4. Add/reduce/hedge triggers.
5. Invalidation signals.
6. Data that must be refreshed before acting.
