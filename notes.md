# E-Commerce Sales & Customer Analysis — Project Notes

Complete record of the analysis: every query result, how it was calculated, what it means, and how to explain it in an interview.

**Dataset:** Olist Brazilian E-Commerce (Kaggle) · 99,441 orders · 9 tables
**Tools:** SQLite (DB Browser for SQLite), Python (pandas, NumPy, Matplotlib), Jupyter
**Period analysed:** Jan 2017 – Aug 2018 · **Currency:** Brazilian Real (R$)

---

## Contents
1. [Executive Summary](#1-executive-summary)
2. [Setup, Definitions & Data Decisions](#2-setup-definitions--data-decisions)
3. [Data Exploration](#3-data-exploration)
4. [Revenue Analysis](#4-revenue-analysis)
5. [Delivery Delays vs Review Scores](#5-delivery-delays-vs-review-scores)
6. [Customer Retention](#6-customer-retention)
7. [Charts](#7-charts)
8. [Limitations & Next Steps](#8-limitations--next-steps)
9. [Interview Preparation](#9-interview-preparation)

---

## 1. Executive Summary

### Key insights
| # | Insight | Key numbers |
|---|---|---|
| 1 | **Growth stalled in 2018** | Revenue +141% (Jan–Aug 2018 vs Jan–Aug 2017), but average month-over-month growth fell from ~23.5% (2017) to ~2.5% (2018) |
| 2 | **Customers don't come back** | 97% of customers bought only once; month-1 retention averages 0.48% |
| 3 | **Late delivery is the biggest driver of bad reviews** | 6.8% of orders are late but cause ~37% of all 1-star reviews (2.27★ vs 4.29★) |
| 4 | **Ratings collapse after 3 days late** | 1–3 days late: 3.29★ · 4–7 days late: 2.11★ (58.5% gave 1★) |
| 5 | **Delivery problems are concentrated** | Rio de Janeiro: 12.1% late (2.7x São Paulo), ~23% of all late orders · Northeast: 12.8% late |
| 6 | **Small baskets, flat order value** | 90.1% of orders have one item; average order value stayed between R$ 124–149 |
| 7 | **Revenue is diversified** | Largest category is only 9.3% of revenue; top 10 = 62.5% |

### Recommendations
1. **Fix delivery in Rio de Janeiro first**, then the Northeast (carrier review, regional fulfilment). Halving late orders could cut ~1,500 1-star reviews (~16% of all 1-stars).
2. **Proactively update customers** whose orders are likely to miss the promised date, before they pass 3 days late.
3. **Run a second-purchase campaign** within 1–2 months of the first order, especially for Black Friday / promotion customers. Track month-1 retention as a KPI for every new cohort.
4. **Raise basket size** with bundles and "frequently bought together" in high-volume categories (bed/bath/table, housewares).
5. **Use premium categories** (watches & gifts, cool stuff, auto) in November campaigns to lift average order value.

### The story in one paragraph
Olist grew fast in 2017, peaking at Black Friday, but growth flattened in 2018. The reason: almost no customer ever returns (97% buy once), so growth depended entirely on finding new customers. A key reason customers have bad experiences is late delivery: late orders are 8x more likely to get a 1-star review, and the problem is concentrated in Rio de Janeiro and the Northeast. Fixing delivery there and actively bringing customers back for a second purchase are the two biggest levers.

---

## 2. Setup, Definitions & Data Decisions

### Pipeline
```
Kaggle CSVs (9 files) → load_data.py → olist.db (SQLite, 9 tables + 8 indexes)
    → SQL analysis (queries/01_explore.sql, 02_revenue.sql, 03_delivery.sql)
    → Python analysis + charts (analysis.ipynb) → charts/*.png → README.md
```

### Definitions
| Term | Definition | Why |
|---|---|---|
| **Revenue** | Sum of product `price` from `order_items` | Shipping/freight excluded: it is not the seller's sales |
| **Order** | Orders with `order_status = 'delivered'` | Only completed sales count |
| **Late** | `date(delivered) > date(estimated)` | Compared by **day**, because the estimated date has no time (00:00). Comparing timestamps would wrongly mark same-day deliveries as late |
| **Customer** | `customer_unique_id` | `customer_id` is created fresh for every order and cannot identify repeat buyers |
| **Cohort** | Customers grouped by the month of their first purchase | Standard method to track retention over time |
| **Period** | Jan 2017 – Aug 2018 (20 months) | Months before and after are incomplete |

### Data decisions
| Issue found | Decision |
|---|---|
| 2016 and Sep–Oct 2018 have almost no orders | Excluded from all trend analysis |
| 8 delivered orders have no delivery date | Excluded from delivery analysis only |
| 610 products (1.9%) have no category | Kept, labelled `"unknown"`, so their revenue still counts |
| Some orders have more than one review | Review scores averaged per order before joining, to avoid double-counting |
| Small states (e.g. Roraima, 40 orders) | Treated as unreliable; state chart uses only states with 1,000+ orders |

### Consistency checks (all passed ✔)
| Check | Result |
|---|---|
| Delivered orders in SQL (Section 4) = Python (Section 6) | 96,211 = 96,211 |
| Delivered orders with a date = delivered − missing dates | 96,203 = 96,211 − 8 |
| Late orders by delay group add up to total late (reviewed) | 1,851 + 1,748 + 1,446 + 1,333 = 6,378 |
| Orders by one-time + repeat customers = all orders | 90,315 + 5,896 = 96,211 |
| Cohort sizes add up to total customers | 93,104 |

---

## 3. Data Exploration
*File: `queries/01_explore.sql`*

### 3.1 Size of the data
| Table | Rows |
|---|---|
| orders | 99,441 |
| order_items | 112,650 |
| customers | 99,441 |
| payments | 103,886 |
| reviews | 99,224 |
| products | 32,951 |
| sellers | 3,095 |

- More order items than orders → some orders contain more than one product.
- More payments than orders → some orders are paid in parts (e.g. voucher + card).
- Customers = orders exactly → each order gets its own `customer_id` (confirmed in 3.5).
- Almost every order has a review → review analysis is reliable.
- 32,951 products from 3,095 sellers → a marketplace of many small sellers.

### 3.2 Time period
- First order: **4 Sep 2016** · Last order: **17 Oct 2018** (about 2 years)

### 3.3 Orders per month
| Month | Orders | | Month | Orders |
|---|---|---|---|---|
| 2016-09 | 4 | | 2017-11 | **7,544** |
| 2016-10 | 324 | | 2017-12 | 5,673 |
| 2016-11 | *(none)* | | 2018-01 | 7,269 |
| 2016-12 | 1 | | 2018-02 | 6,728 |
| 2017-01 | 800 | | 2018-03 | 7,211 |
| 2017-02 | 1,780 | | 2018-04 | 6,939 |
| 2017-03 | 2,682 | | 2018-05 | 6,873 |
| 2017-04 | 2,404 | | 2018-06 | 6,167 |
| 2017-05 | 3,700 | | 2018-07 | 6,292 |
| 2017-06 | 3,245 | | 2018-08 | 6,512 |
| 2017-07 | 4,026 | | 2018-09 | 16 |
| 2017-08 | 4,331 | | 2018-10 | 4 |
| 2017-09 | 4,285 | | | |
| 2017-10 | 4,631 | | | |

- **Incomplete months at both ends** (2016, Sep–Oct 2018) → excluded; analysis uses **Jan 2017 – Aug 2018**.
- **~9x growth in one year:** 800 orders (Jan 2017) → 7,269 (Jan 2018).
- **Plateau in 2018** at ~6,000–7,300 orders per month.
- **Nov 2017 spike:** 7,544 orders, ~63% above October → Black Friday (24 Nov 2017).

### 3.4 Data quality: delivered orders without a delivery date
- **8** out of ~96K → very clean data; excluded from delivery analysis.

### 3.5 customer_id vs customer_unique_id
| Measure | Count |
|---|---|
| Distinct `customer_id` | 99,441 |
| Distinct `customer_unique_id` (real people) | 96,096 |

- `customer_id` is **per order**; `customer_unique_id` is the **person**. Using `customer_id` would wrongly show 0% repeat customers.
- Only 3,345 extra orders came from people buying again → first sign of very low retention.

### 3.6 Payment methods
| Payment type | Payments | Share |
|---|---|---|
| Credit card | 76,795 | 73.9% |
| Boleto | 19,784 | 19.0% |
| Voucher | 5,775 | 5.6% |
| Debit card | 1,529 | 1.5% |
| Not defined | 3 | 0.0% |

- Credit cards dominate; in Brazil they are often used to pay in instalments.
- **Boleto** is a Brazilian bank slip paid in cash or online, used by people without cards.
- Vouchers explain why there are more payments than orders (split payments).

### 3.7 Review scores
| Score | Reviews | Share |
|---|---|---|
| 5★ | 57,328 | 57.8% |
| 4★ | 19,142 | 19.3% |
| 3★ | 8,179 | 8.2% |
| 2★ | 3,151 | 3.2% |
| 1★ | 11,424 | 11.5% |

- Average **4.09 / 5** · Positive (4–5★) **77.1%** · Negative (1–2★) **14.7%**
- **Polarised:** 1-star is 3.6x more common than 2-star → unhappy customers had something clearly go wrong.
- **Hypothesis formed here:** late deliveries cause many 1-star reviews (tested in Section 5).

### 3.8 Products without a category
- **610 products (1.9%)** → kept as `"unknown"`.

### 3.9 Items per order
| Items | Orders |
|---|---|
| 1 | 88,863 |
| 2 | 7,516 |
| 3 | 1,322 |
| 4 | 505 |
| 5 | 204 |
| 6 | 198 |
| 7–21 | 58 |

- **90.1%** of orders have a single item · Average **1.14 items per order** (112,650 ÷ 98,666)
- 775 orders have no items at all (likely cancelled or unavailable).
- → **Cross-selling opportunity.**

---

## 4. Revenue Analysis
*File: `queries/02_revenue.sql` · Techniques: joins, CTEs, window functions (`LAG`, `SUM() OVER`, `RANK`)*

### 4.1 Monthly revenue
| Month | Orders | Revenue (R$) | Avg order value (R$) |
|---|---|---|---|
| 2017-01 | 750 | 111,798 | 149.06 |
| 2017-02 | 1,653 | 234,223 | 141.70 |
| 2017-03 | 2,546 | 359,199 | 141.08 |
| 2017-04 | 2,303 | 340,670 | 147.92 |
| 2017-05 | 3,546 | 489,338 | 138.00 |
| 2017-06 | 3,135 | 421,923 | 134.58 |
| 2017-07 | 3,872 | 481,605 | 124.38 |
| 2017-08 | 4,193 | 554,700 | 132.29 |
| 2017-09 | 4,150 | 607,400 | 146.36 |
| 2017-10 | 4,478 | 648,248 | 144.76 |
| 2017-11 | 7,289 | **987,765** | 135.51 |
| 2017-12 | 5,513 | 726,033 | 131.69 |
| 2018-01 | 7,069 | 924,645 | 130.80 |
| 2018-02 | 6,555 | 826,437 | 126.08 |
| 2018-03 | 7,003 | 953,356 | 136.14 |
| 2018-04 | 6,798 | 973,534 | 143.21 |
| 2018-05 | 6,749 | 977,545 | 144.84 |
| 2018-06 | 6,099 | 856,078 | 140.36 |
| 2018-07 | 6,159 | 867,953 | 140.92 |
| 2018-08 | 6,351 | 838,577 | 132.04 |
| **Total** | **96,211** | **13,181,027** | **137.00** |

- **+141% growth:** Jan–Aug 2018 = R$ 7.22M vs Jan–Aug 2017 = R$ 2.99M.
- **Black Friday:** Nov 2017 = R$ 988K, +52% vs October, **16.6% of all 2017 revenue** in one month.
- **Flat order value (R$ 124–149)** → growth came from **more orders, not bigger orders**.
- **2018 plateau** at ~R$ 840K–980K per month.

### 4.2 Month-over-month growth
| Month | Revenue (R$) | MoM growth | Running total (R$) |
|---|---|---|---|
| 2017-01 | 111,798 | – | 111,798 |
| 2017-02 | 234,223 | +109.5% | 346,022 |
| 2017-03 | 359,199 | +53.4% | 705,221 |
| 2017-04 | 340,670 | −5.2% | 1,045,890 |
| 2017-05 | 489,338 | +43.6% | 1,535,229 |
| 2017-06 | 421,923 | −13.8% | 1,957,152 |
| 2017-07 | 481,605 | +14.1% | 2,438,756 |
| 2017-08 | 554,700 | +15.2% | 2,993,456 |
| 2017-09 | 607,400 | +9.5% | 3,600,856 |
| 2017-10 | 648,248 | +6.7% | 4,249,103 |
| 2017-11 | 987,765 | **+52.4%** | 5,236,869 |
| 2017-12 | 726,033 | −26.5% | 5,962,902 |
| 2018-01 | 924,645 | +27.4% | 6,887,547 |
| 2018-02 | 826,437 | −10.6% | 7,713,984 |
| 2018-03 | 953,356 | +15.4% | 8,667,340 |
| 2018-04 | 973,534 | +2.1% | 9,640,874 |
| 2018-05 | 977,545 | +0.4% | 10,618,419 |
| 2018-06 | 856,078 | −12.4% | 11,474,497 |
| 2018-07 | 867,953 | +1.4% | 12,342,450 |
| 2018-08 | 838,577 | −3.4% | 13,181,027 |

- **Average MoM growth: ~+23.5% in 2017** (8 of 11 months positive) vs **~+2.5% in 2018** (4 of 8 months negative).
- Dec 2017 (−26.5%) is the natural post-Black-Friday drop; December was still ~12% above October.
- Jan–Aug 2018 (R$ 7.22M) already beat all of 2017 (R$ 5.96M).

### 4.3 Top 10 categories
| Rank | Category | Orders | Revenue (R$) | Avg order value (R$) | Share |
|---|---|---|---|---|---|
| 1 | health_beauty | 8,610 | 1,229,558 | 142.81 | 9.3% |
| 2 | watches_gifts | 5,491 | 1,163,466 | **211.89** | 8.8% |
| 3 | bed_bath_table | **9,267** | 1,022,956 | 110.39 | 7.8% |
| 4 | sports_leisure | 7,513 | 952,840 | 126.83 | 7.2% |
| 5 | computers_accessories | 6,518 | 888,056 | 136.25 | 6.7% |
| 6 | furniture_decor | 6,258 | 706,237 | 112.85 | 5.4% |
| 7 | housewares | 5,734 | 614,342 | 107.14 | 4.7% |
| 8 | cool_stuff | 3,552 | 609,158 | 171.50 | 4.6% |
| 9 | auto | 3,802 | 577,838 | 151.98 | 4.4% |
| 10 | garden_tools | 3,443 | 469,135 | 136.26 | 3.6% |

- Top 3 = **25.9%** · Top 5 = **39.8%** · Top 10 = **62.5%** of revenue → **well diversified**.
- **Premium categories** (watches_gifts R$ 212, cool_stuff R$ 172, auto R$ 152): fewer, high-value orders.
- **Volume categories** (bed_bath_table, housewares, furniture_decor, ~R$ 107–113): many low-value orders.
- **health_beauty is #1** because it combines high volume with a solid order value.

---

## 5. Delivery Delays vs Review Scores
*File: `queries/03_delivery.sql` · Techniques: `CASE` binning, `julianday()` date maths, CTEs, multi-table joins*

### 5.1 How many orders arrive late?
| Measure | Value |
|---|---|
| Delivered orders (with a delivery date) | 96,203 |
| Late orders | 6,531 |
| **Late rate** | **6.8%** (about 1 in 15) |
| Average actual delivery time | **12.5 days** |
| Average promised delivery time | **23.6 days** |

- The company promises **almost 2x** the time it needs (~11-day buffer), yet 6.8% still arrive late → those orders are seriously delayed.

### 5.2 Late vs on-time: review scores
| Delivery | Orders | Avg review | 1★ | Negative (1–2★) | Positive (4–5★) |
|---|---|---|---|---|---|
| **Late** | 6,378 | **2.27** | **53.7%** | **62.4%** | 26.7% |
| On time | 89,182 | 4.29 | 6.6% | 9.2% | 82.7% |

- 1-star rate **~8x higher** for late orders; average rating **~2 stars lower**.
- Late 1★ ≈ 3,425 · On-time 1★ ≈ 5,886 → late orders are **~6.7% of reviewed orders but ~37% of all 1-star reviews**.
- **Hypothesis confirmed**, with nuance: ~63% of 1-star reviews come from on-time orders, so product/seller issues also matter.
- **Impact estimate:** halving late orders → 3,189 × (53.7% − 6.6%) ≈ **1,500 fewer 1-star reviews** (~16% of all 1-stars).

### 5.3 Review score by days late
| Delay | Orders | Avg review | 1★ |
|---|---|---|---|
| On time | 89,182 | 4.29 | 6.6% |
| 1–3 days late | 1,851 | 3.29 | 25.1% |
| **4–7 days late** | 1,748 | **2.11** | **58.5%** |
| 8–14 days late | 1,446 | 1.67 | 70.6% |
| 15+ days late | 1,333 | 1.73 | 68.7% |

- **Even 1–3 days late costs a full star** and ~4x the 1-star rate.
- **Tipping point at ~4 days late:** rating 3.29 → 2.11; 1★ share 25% → 58.5%.
- **Floor after ~1 week:** ratings bottom out around 1.7.
- **71% of late orders (4,527 of 6,378) are 4+ days late**, the most damaging group.

### 5.4 Late deliveries by state
| State | Orders | Late % | Avg delivery days | Avg promised days |
|---|---|---|---|---|
| AL – Alagoas | 396 | **21.5** | 24.5 | 32.5 |
| MA – Maranhão | 713 | 17.5 | 21.5 | 30.3 |
| SE – Sergipe | 332 | 15.4 | 21.4 | 30.6 |
| PI – Piauí | 475 | 13.9 | 19.4 | 30.0 |
| CE – Ceará | 1,273 | 13.8 | 21.2 | 31.2 |
| RR – Roraima | 40 | 12.5 | 29.9 | 45.5 |
| BA – Bahia | 3,253 | 12.2 | 19.3 | 29.4 |
| **RJ – Rio de Janeiro** | **12,310** | **12.1** | 15.3 | 26.3 |
| PA – Pará | 942 | 11.3 | 23.8 | 37.0 |
| ES – Espírito Santo | 1,992 | 10.7 | 15.8 | 25.5 |
| PB – Paraíba | 516 | 10.5 | 20.4 | 33.0 |
| TO – Tocantins | 274 | 9.9 | 17.7 | 29.1 |
| MS – Mato Grosso do Sul | 701 | 9.7 | 15.6 | 26.0 |
| PE – Pernambuco | 1,587 | 9.6 | 18.4 | 30.9 |
| RN – Rio Grande do Norte | 470 | 9.4 | 19.2 | 32.0 |
| SC – Santa Catarina | 3,537 | 8.2 | 14.9 | 25.7 |
| GO – Goiás | 1,950 | 6.6 | 15.6 | 27.0 |
| RS – Rio Grande do Sul | 5,327 | 6.1 | 15.3 | 28.4 |
| MT – Mato Grosso | 885 | 6.0 | 18.1 | 31.7 |
| DF – Distrito Federal | 2,074 | 5.7 | 12.9 | 24.2 |
| MG – Minas Gerais | 11,319 | 4.6 | 12.0 | 24.5 |
| **SP – São Paulo** | **40,399** | **4.5** | **8.7** | 19.1 |
| PR – Paraná | 4,903 | 4.1 | 12.0 | 24.5 |
| AC – Acre | 80 | 3.8 | 21.0 | 41.1 |
| AP – Amapá | 67 | 3.0 | 27.2 | 46.2 |
| RO – Rondônia | 243 | 2.9 | 19.4 | 38.8 |
| AM – Amazonas | 145 | 2.8 | 26.4 | 45.3 |

**By region** (order-weighted):
| Region | Share of orders | Late rate | Avg delivery days | Avg promised days | Share of all late orders |
|---|---|---|---|---|---|
| Northeast | 9.4% | **12.8%** | 20.0 | 30.5 | 17.6% |
| North | 1.9% | 8.6% | 22.6 | 37.4 | 2.4% |
| Center-West | 5.8% | 6.6% | 15.0 | 26.6 | 5.6% |
| Southeast | 68.6% | 6.1% | 10.7 | 21.6 | 61.9% |
| South | 14.3% | 5.9% | 14.0 | 26.3 | 12.5% |

**Where late orders come from:** SP ≈ 1,818 (27.8%) · **RJ ≈ 1,490 (22.8%)** · MG ≈ 521 (8.0%) · BA ≈ 397 (6.1%) · RS ≈ 325 (5.0%)

- **Rio de Janeiro is the #1 target:** 2nd-largest market, next to São Paulo, yet **2.7x** its late rate and ~23% of all late orders. Distance can't explain it → likely a fixable carrier/logistics issue.
- **Northeast:** ~2x the late rate of South/Southeast; Alagoas ~1 in 5 orders late.
- **São Paulo is the benchmark:** 42% of orders, fastest delivery (8.7 days), 4.5% late.
- **Low late % ≠ good service:** North states (AM, AP, RO) look best only because customers are promised ~39–46 days.

---

## 6. Customer Retention
*File: `analysis.ipynb` · Techniques: pandas `groupby`, `nunique`, `transform`, `unstack`, cohort analysis*

### 6.1 Customers
| Measure | Value |
|---|---|
| Delivered orders | 96,211 |
| Unique customers | 93,104 |

### 6.2 Repeat-purchase rate
| Measure | Value |
|---|---|
| Repeat customers (2+ orders) | 2,789 |
| **Repeat rate** | **3.00%** |
| **One-time customers** | **97.00%** |

| Orders placed | Customers |
|---|---|
| 1 | 90,315 |
| 2 | 2,562 |
| 3 | 180 |
| 4 | 28 |
| 5 | 9 |
| 6 | 5 |
| 7 | 3 |
| 9 | 1 |
| 15 | 1 |

- Of repeat customers, **91.9% bought exactly twice**; only **227** placed 3+ orders.
- Repeat customers placed **5,896 orders = 6.1% of all orders** → revenue comes almost entirely from first-time buyers.
- **Explains the 2018 plateau:** with no returning base, growth stops when new-customer growth slows.
- Moving the repeat rate from 3% to 5% would mean ~1,860 more customers placing a second order.

### 6.3 Monthly cohort retention
**Cohort sizes:**
| Cohort | Customers | | Cohort | Customers |
|---|---|---|---|---|
| 2017-01 | 718 | | 2017-11 | **7,061** |
| 2017-02 | 1,628 | | 2017-12 | 5,338 |
| 2017-03 | 2,503 | | 2018-01 | 6,843 |
| 2017-04 | 2,257 | | 2018-02 | 6,288 |
| 2017-05 | 3,451 | | 2018-03 | 6,775 |
| 2017-06 | 3,037 | | 2018-04 | 6,582 |
| 2017-07 | 3,753 | | 2018-05 | 6,508 |
| 2017-08 | 4,057 | | 2018-06 | 5,879 |
| 2017-09 | 4,005 | | 2018-07 | 5,949 |
| 2017-10 | 4,328 | | 2018-08 | 6,144 |

**Retention % by months after first purchase** (– = no data yet):
| Cohort | M1 | M2 | M3 | M4 | M5 | M6 |
|---|---|---|---|---|---|---|
| 2017-01 | 0.28 | 0.28 | 0.14 | 0.42 | 0.14 | 0.42 |
| 2017-02 | 0.18 | 0.31 | 0.12 | 0.43 | 0.12 | 0.25 |
| 2017-03 | 0.44 | 0.36 | 0.40 | 0.36 | 0.16 | 0.16 |
| 2017-04 | 0.62 | 0.22 | 0.18 | 0.27 | 0.27 | 0.35 |
| 2017-05 | 0.46 | 0.46 | 0.29 | 0.29 | 0.32 | 0.41 |
| 2017-06 | 0.49 | 0.40 | 0.43 | 0.30 | 0.40 | 0.36 |
| 2017-07 | 0.53 | 0.35 | 0.24 | 0.29 | 0.21 | 0.32 |
| 2017-08 | 0.69 | 0.35 | 0.27 | 0.35 | 0.52 | 0.30 |
| 2017-09 | 0.70 | 0.55 | 0.27 | 0.45 | 0.22 | 0.22 |
| 2017-10 | **0.72** | 0.25 | 0.09 | 0.23 | 0.21 | 0.21 |
| 2017-11 | 0.57 | 0.37 | 0.17 | 0.17 | 0.18 | **0.11** |
| 2017-12 | 0.21 | 0.28 | 0.34 | 0.26 | 0.21 | 0.17 |
| 2018-01 | 0.34 | 0.37 | 0.29 | 0.29 | 0.16 | 0.18 |
| 2018-02 | 0.35 | 0.40 | 0.30 | 0.25 | 0.22 | 0.21 |
| 2018-03 | 0.40 | 0.30 | 0.30 | 0.12 | 0.12 | – |
| 2018-04 | 0.59 | 0.30 | 0.24 | 0.14 | – | – |
| 2018-05 | 0.52 | 0.26 | 0.18 | – | – | – |
| 2018-06 | 0.43 | 0.27 | – | – | – | – |
| 2018-07 | 0.52 | – | – | – | – | – |
| 2018-08 | – | – | – | – | – | – |
| **Average** | **0.48** | **0.34** | **0.25** | **0.29** | **0.23** | **0.26** |

- **Fewer than 1 in 200 customers return the next month.** No cohort exceeds 0.72% in any month.
- **Flat curve:** retention is near zero from the start; there is no loyalty phase to lose.
- **Black Friday cohort (2017-11):** largest (7,061) but lowest 6-month retention (0.11%) → deal-seekers, not loyal customers.
- **Not improving:** month-1 retention averages 0.45% for 2018 cohorts vs 0.64% for Jul–Nov 2017.
- **Caution:** 0.1% of a 4,000-customer cohort is just 4 people, so cohort-to-cohort differences are mostly noise. The reliable finding is the overall pattern.

---

## 7. Charts
*Folder: `charts/` · Each title states the finding, not just the topic.*

| File | Type | Finding |
|---|---|---|
| `01_monthly_revenue.png` | Line | Revenue grew 141% in a year, then plateaued in 2018 |
| `02_top_categories.png` | Horizontal bar | No single category dominates: the top one is only 9.3% of revenue |
| `03_reviews_by_delay.png` | Bar (on time vs late) | Ratings collapse once a delivery is more than 3 days late |
| `04_late_by_state.png` | Highlighted horizontal bar | Rio de Janeiro: 2nd-biggest market, 2.7x São Paulo's late rate |
| `05_cohort_retention.png` | Heatmap | Fewer than 1 in 200 customers return the next month |

**Design choices:**
- Axes start at 0, so changes are not exaggerated.
- Colour carries meaning only (on time vs late; RJ vs SP vs others); everything else is neutral.
- Only key values are labelled (e.g. just the Black Friday peak) to avoid clutter.
- Heatmap uses a single-colour scale capped at 0.8%, so even the darkest cell means very low retention.
- State chart shows only states with 1,000+ orders, so every percentage is reliable.

---

## 8. Limitations & Next Steps

### Limitations
- **Correlation, not causation:** late orders get worse reviews, but this analysis doesn't prove delay is the only cause; some late orders may also have product problems.
- **Revenue excludes freight**, so it reflects product sales, not total customer spend.
- **Historical data (2016–2018)** from one Brazilian marketplace; patterns may differ elsewhere or today.
- **Retention window is short** for 2018 cohorts (few months of follow-up data).
- **Seller location was not analysed**, so the reason for regional delays (distance from sellers) is a hypothesis, not proven.

### Next steps
1. **Seller analysis:** check whether late deliveries come from a few sellers or specific seller–customer routes.
2. **Review text analysis:** analyse the written comments of 1-star on-time orders to find the other causes of dissatisfaction.
3. **Late-delivery prediction:** build a simple model (e.g. logistic regression on distance, category, seller, month) to flag orders likely to be late.
4. **Customer segmentation:** RFM (recency, frequency, monetary) scoring to target the most valuable customers for a second purchase.

---

## 9. Interview Preparation

### 60-second explanation
> "I analysed 99,000 orders from a Brazilian e-commerce marketplace using SQL and Python. Revenue grew 141% but stalled in 2018, so I investigated why. First, I found 97% of customers never came back, and monthly retention was below half a percent, so growth depended entirely on new customers. Second, I found that late deliveries were only 6.8% of orders but caused about 37% of all 1-star reviews, and ratings collapsed once an order was more than 3 days late. By state, Rio de Janeiro had a 12% late rate despite being next to São Paulo, and alone caused about a quarter of late orders. So my recommendations were to fix delivery in Rio and the Northeast first, and run a second-purchase campaign to improve retention."

### Likely questions and answers

**Q: Why did you use `customer_unique_id` instead of `customer_id`?**
A: During exploration I saw the number of `customer_id`s exactly matched the number of orders. That told me a new ID is created per order. `customer_unique_id` identifies the actual person, so it's the only way to measure repeat purchases. With `customer_id`, the repeat rate would wrongly be 0%.

**Q: How did you define a late delivery?**
A: Delivered on a later day than the estimated delivery date shown to the customer. I compared dates, not timestamps, because the estimated date is stored at midnight; otherwise an order delivered in the afternoon of the promised day would wrongly count as late.

**Q: Why did you only use Jan 2017 – Aug 2018?**
A: When I counted orders per month, 2016 and Sep–Oct 2018 had almost no orders, which means incomplete data, not real drops. Including them would distort the trends.

**Q: What is a window function? Where did you use one?**
A: It calculates across related rows without collapsing them like `GROUP BY` does. I used `LAG()` to get the previous month's revenue for month-over-month growth, `SUM() OVER (ORDER BY month)` for a running total, `SUM() OVER ()` for each category's share of total revenue, and `RANK()` to rank categories.

**Q: Why did you average review scores per order before joining?**
A: Some orders have more than one review. Joining directly would count those orders twice and slightly distort the results.

**Q: What is cohort analysis?**
A: Grouping customers by when they first bought, then tracking what share of each group buys again in later months. It shows whether retention is improving over time, which a single repeat rate can't show.

**Q: Why focus on Rio de Janeiro rather than Alagoas, which has a higher late rate?**
A: Impact. Alagoas has only 396 orders, while Rio has over 12,000 orders and causes about 23% of all late deliveries. And because Rio is close to São Paulo, the problem is likely operational and fixable, not just distance.

**Q: Does late delivery cause bad reviews?**
A: The evidence is strong (8x more 1-star reviews, and ratings fall steadily as delays increase), but it's correlation. About 63% of 1-star reviews come from on-time orders, so other factors like product quality matter too. I'd analyse review text next to find them.

**Q: What would you do with more time?**
A: Analyse seller locations to explain regional delays, analyse review text for 1-star on-time orders, and build a simple model to predict which orders are likely to be late.
