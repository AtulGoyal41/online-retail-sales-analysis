# EDA Findings — Online Retail II Sales Analysis

Each finding below follows the same structure: **Finding** (what the data shows), **Insight** (what it means for the business), **Confirmed vs. Not Confirmed** (what's proven by the data vs. what would need more data to verify), and **Recommendation** (what action follows, with business impact, benefit, risk, priority, and difficulty).

---

## 1. Revenue Bridge

**Finding:** Gross Revenue (£10,169,340) → less Cancellations (-£629,855.37) → Net Revenue (£9,539,484.63) → plus Admin/Voucher adjustment (+£51,429.26) → **Net Sales Revenue (£9,590,913.89)** — the final true revenue figure used throughout this analysis.

---

## 2. EIRE Concentration Risk

**Finding:** EIRE accounts for 3.64% of Net Sales Revenue, but that revenue comes from only **6 distinct customer accounts**, averaging **£59,700/account** — versus the UK's average of £2,057/account.

**Insight:** This is not a growth opportunity ranking — it's a concentration risk. Losing even one of these 6 accounts removes roughly £59,700 in revenue at a stroke.

**Confirmed:** The concentration itself (6 accounts driving all EIRE revenue). **Not confirmed:** whether these accounts are genuine wholesalers — no business-type field exists in the dataset to verify this.

**Recommendation:** Assign one dedicated account manager plus one associate specifically to these 6 accounts — not a full team, since the cost must be justified against the ~£358K/year at stake. **Priority:** High (concentration risk, not a ranking issue). **Difficulty:** Low.

---

## 3. Top Products

**Finding:** The top 5 products (out of 4,145 distinct products) account for **5.27% of total revenue**, versus the 0.12% expected if revenue were spread evenly — roughly 44x above random chance.

**Insight:** This confirms genuine standout products, not statistical noise.

**Confirmed:** The concentration of revenue in the top 5 products. **Not confirmed:** the cause (marketing push, seasonality, or pricing) — no campaign or marketing-spend data exists in this dataset.

**Recommendation:** (1) Free/immediate — check whether top-5 sales cluster around the November peak using existing InvoiceDate data; (2) request marketing-spend-by-product data from the relevant team to test causation properly. **Priority:** Low (exploratory, not urgent). **Difficulty:** Low to Low-Medium.

---

## 4. Guest vs. Registered Customers

**Finding:** Average Order Value — Registered £357.32 vs. Guest £222.38 (~1.6x higher). Cancellation Rate — Registered 18.54% vs. Guest 4.21% (~4.4x higher).

**Insight:** Registered customers order more per transaction, but also cancel dramatically more often.

**Confirmed (business impact):** Registered-customer cancellations total **-£483,794.70**, roughly 77% of all cancelled value (-£629,855.37). **Not confirmed:** whether Registered customers are predominantly wholesalers, or what specifically drives their higher cancellation rate (e.g. stock issues, payment issues, changing requirements) — no root-cause data exists in this dataset.

**Recommendation:** Review how Customer Service handles cancelling Registered customers. **Risk:** the root cause may sit outside CS's control (e.g. supply chain delays). **Priority:** High. **Difficulty:** Low-Medium.

---

## 5. Seasonal Demand Pattern

**Finding:** Q4 2010 is the strongest quarter (£2.88M) vs. Q1 (£1.89M), Q2 (£1.92M), and Q3 (£2.13M). Within Q4, **November (£1.40M) is the peak month — not December (£402K)**.

**Insight:** Wholesale restocking and gift-buying happen well ahead of Christmas, not on or near the day itself — meaning stock and staffing need to be ready before November begins, not in anticipation of a December rush.

**Confirmed:** November, not December, is the peak revenue month. **Not confirmed:** the exact lead time needed for stock/staffing preparation, since no supplier or inventory-level data exists in this dataset.

**Recommendation:** Ensure stock and staffing are fully in place before November begins. **Business impact:** if unprepared, the business risks unmet demand during its single highest-revenue month (£1.40M) — customers unable to find available stock may simply buy from a competitor instead. **Benefit:** being ready ahead of the November peak captures the full available revenue rather than losing it to stockouts. **Risk:** overcorrecting (over-stocking) ties up cash and risks margin leakage if unsold inventory must be discounted or written off later. **Priority:** High — a predictable, recurring annual pattern, not a one-off risk. **Difficulty:** Low-to-Medium — primarily a stock/staffing planning exercise, not new infrastructure.
