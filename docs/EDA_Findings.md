# EDA Findings — Online Retail II Sales Analysis

Each finding below follows the same structure: **Finding** (what the data shows), **Insight** (what it means for the business), **Confirmed vs. Not Confirmed** (what's proven by the data vs. what would need more data to verify), and **Recommendation** (what action follows, with business impact, benefit, risk, priority, and difficulty).

---

## 1. Revenue Bridge

**Finding:** Gross Revenue (£10,169,340) → less Cancellations (-£629,855.37) → Net Revenue (£9,539,484.63) → plus Admin/Voucher adjustment (+£51,429.26) → **Net Sales Revenue (£9,590,901.39)** — the final true revenue figure used throughout this analysis.

---

## 2. EIRE Concentration Risk

**Finding:** EIRE accounts for 3.64% of Net Sales Revenue (£348,868.92). Of this, **£325,403.11 comes from just 3 real, identifiable customer accounts** (averaging **£108,467.70/account** — versus the UK's average of £2,057/account), with the remaining **£23,465.81 from anonymous guest checkouts** that cannot be attributed to any single customer.

**Insight:** This is not a growth opportunity ranking — it's a severe concentration risk. Losing even one of these 3 real accounts removes over £100,000 in revenue at a stroke. *(An earlier version of this finding incorrectly counted blank/guest Customer IDs as a 6th "account" — DAX's DISTINCTCOUNT treats blank as a single value, silently merging an unknown number of separate anonymous transactions into one row. This inflated the account count and understated the true per-account concentration.)*

**Confirmed:** The concentration itself (3 real accounts driving the vast majority of EIRE's identifiable revenue). **Not confirmed:** whether these accounts are genuine wholesalers — no business-type field exists in the dataset to verify this; also not confirmed how many distinct individuals make up the £23,465.81 in anonymous guest revenue, since guest checkouts cannot be individually identified.

**Recommendation:** Assign one dedicated account manager specifically to these 3 real accounts — not a full team, since the cost must be justified against the ~£325K/year at stake from identifiable accounts. The anonymous guest revenue cannot be managed the same way, since there's no individual to assign to. **Priority:** High (severe concentration risk). **Difficulty:** Low.

---

## 3. Top Products

**Finding:** The top 5 products (out of 4,145 distinct products) account for **5.27% of total revenue**, versus the 0.12% expected if revenue were spread evenly — roughly 44x above random chance.

**Insight:** This confirms genuine standout products, not statistical noise.

**Confirmed:** The concentration of revenue in the top 5 products. **Not confirmed:** the cause (marketing push, seasonality, or pricing) — no campaign or marketing-spend data exists in this dataset.

**Recommendation:** (1) Free/immediate — check whether top-5 sales cluster around the November peak using existing InvoiceDate data; (2) request marketing-spend-by-product data from the relevant team to test causation properly. **Priority:** Low (exploratory, not urgent). **Difficulty:** Low to Low-Medium.

---

## 4. Guest vs. Registered Customers

**Finding:** Average Order Value — Registered £444.38 vs. Guest £424.54 (nearly identical, only ~4.7% higher). Cancellation Rate — Registered 18.54% vs. Guest 4.21% (~4.4x higher).

**Insight:** Registered and Guest customers spend almost the same amount per order — order size is not what separates them. The real difference is cancellation behavior: Registered customers cancel at more than 4x the rate of Guests, despite ordering similarly.

**Confirmed (business impact):** Registered-customer cancellations total **-£483,794.70**, roughly 77% of all cancelled value (-£629,855.37). **Not confirmed:** whether Registered customers are predominantly wholesalers, or what specifically drives their higher cancellation rate (e.g. stock issues, payment issues, changing requirements) — no root-cause data exists in this dataset.

**Recommendation:** Review how Customer Service handles cancelling Registered customers. **Risk:** the root cause may sit outside CS's control (e.g. supply chain delays). **Priority:** High. **Difficulty:** Low-Medium.

---

## 5. Seasonal Demand Pattern

**Finding:** Q4 2010 is the strongest quarter (£2.88M) vs. Q1 (£1.89M), Q2 (£1.92M), and Q3 (£2.13M). Within Q4, **November (£1.40M) is the peak month — not December (£402K)**.

**Insight:** Wholesale restocking and gift-buying happen well ahead of Christmas, not on or near the day itself — meaning stock and staffing need to be ready before November begins, not in anticipation of a December rush.

**Confirmed:** November, not December, is the peak revenue month. **Not confirmed:** the exact lead time needed for stock/staffing preparation, since no supplier or inventory-level data exists in this dataset.

**Recommendation:** Ensure stock and staffing are fully in place before November begins. **Business impact:** if unprepared, the business risks unmet demand during its single highest-revenue month (£1.40M) — customers unable to find available stock may simply buy from a competitor instead. **Benefit:** being ready ahead of the November peak captures the full available revenue rather than losing it to stockouts. **Risk:** overcorrecting (over-stocking) ties up cash and risks margin leakage if unsold inventory must be discounted or written off later. **Priority:** High — a predictable, recurring annual pattern, not a one-off risk. **Difficulty:** Low-to-Medium — primarily a stock/staffing planning exercise, not new infrastructure.
