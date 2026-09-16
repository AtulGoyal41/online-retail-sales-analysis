# SQL & Power BI Rebuild — Process Documentation

**Project:** Online Retail II (UCI), Year_2009_2010 sheet, 525,461 rows
**Original build:** Excel / Power Query / Power Pivot (DAX)
**This document covers:** the MySQL rebuild and the Power BI rebuild — what was done, in what order, what broke along the way, and what changed as a result.

---

## 1. Why rebuild at all

The Excel version was already complete: cleaned data, six engineered columns, eleven DAX measures, five EDA findings, and a dashboard. Rebuilding the same analysis in two more tools was not about producing a different answer — it was about producing the *same* answer independently, and treating any disagreement between the three as a signal that one of them was wrong.

The business logic was deliberately not re-derived. Every cleaning rule, filter, and definition was carried over unchanged from the Power Query build. The work was translating logic already understood into SQL and DAX syntax, and then reconciling the outputs.

That reconciliation is what surfaced six real defects. None of them would have been visible from inside a single tool, because inside a single tool there is nothing to disagree with.

---

## 2. MySQL rebuild

### 2.1 Schema design

Rather than letting an import wizard infer types, the schema was written by hand, one column at a time, with a stated reason for each choice:

| Column | Type | Reasoning |
|---|---|---|
| Invoice | `VARCHAR(10)` | Variable length; no padding needed |
| StockCode | `VARCHAR(15)` | Widened from an initial 10 after a load failure (see 2.3) |
| Description | `VARCHAR(100)` | Free text |
| Quantity | `INT` | Signed by default in MySQL (≈ −2.1bn to +2.1bn), so negatives for returns are handled without extra declaration |
| InvoiceDate | `DATETIME` | Source carries both date and time |
| Price | `DECIMAL(10,3)` | Three decimal places, not two (see 2.3) |
| CustomerID | `VARCHAR(5)` | Short, frequently blank; `VARCHAR` avoids padding every blank to fixed width |
| Country | `VARCHAR(50)` | Names vary widely in length ("UK" to "European Community") |

A second table, `online_retail_staging`, was created identically except with `InvoiceDate` as `VARCHAR(20)`. This exists because the source stores dates as `DD-MM-YYYY HH:MM:SS`, which MySQL's `DATETIME` cannot parse on load. Loading to text first, then converting on insert, avoids the alternative risk: MySQL silently reinterpreting `01-12-2009` (1 December) as 12 January on some rows while erroring on others where the day exceeds 12.

### 2.2 Loading the data

The GUI import wizard was tried first and abandoned — it inserts row by row and stalls at this volume. `LOAD DATA INFILE` replaced it, which loads server-side in seconds. This required the source file to sit inside MySQL's `secure_file_priv` directory, found via:

```sql
SHOW VARIABLES LIKE 'secure_file_priv';
```

Three separate load failures had to be resolved before the file would import cleanly. Each one is documented in the next section, because each one was a real data problem rather than a syntax mistake.

### 2.3 Load failures and what they revealed

**Error 1406 — data too long for `StockCode` at row 18411.**
`VARCHAR(10)` was too narrow. Rather than guessing a larger number, the actual maximum was measured (`=MAX(LEN(...))` across the source column): 12 characters, from the value `BANK CHARGES`. Set to `VARCHAR(15)` for a small margin. The point of measuring rather than guessing is that "make it bigger until the error stops" leaves you unable to explain your own schema.

**Error 1300 — invalid utf8mb4 character string.**
Excel's default "CSV (Comma delimited)" export writes Windows-1252, not UTF-8, which breaks on the £ symbol and accented product descriptions. Re-exporting as "CSV UTF-8 (Comma delimited)" resolved it. This is a distinct, easy-to-miss menu option.

**Warning 1265 — data truncated for `Price`, 14 rows.**
The load succeeded but reported 14 warnings. Investigating rather than ignoring them found genuine prices of `0.001`, being rounded to `0.00` by `DECIMAL(10,2)`. Changed to `DECIMAL(10,3)`. A silent rounding of 14 rows is small, but it is the kind of thing that is impossible to find later once it has propagated into aggregates.

### 2.4 Converting text dates to DATETIME

```sql
INSERT INTO online_retail (...)
SELECT Invoice, StockCode, Description, Quantity,
       STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i:%s'),
       Price, CustomerID, Country
FROM online_retail_staging;
```

Converting inline during the insert avoids doing the work twice (once in staging, once again on copy). Worth noting: `DATE_FORMAT()` is not a substitute here — it changes how a date *displays*, and cannot recover a date that was misparsed on the way in.

### 2.5 A duplicate-insert incident

Partway through, `CustomerType` counts came back as 835,068 Registered and 215,854 Guest — summing to 1,050,922 against a table of 525,461 rows. Exactly double.

The cause was the `INSERT INTO ... SELECT` having run twice. The fix was straightforward (`TRUNCATE`, re-insert once), but the more useful lesson was in how it was diagnosed. The verification that had "confirmed" 215,854 guest rows earlier had itself been run against the already-duplicated table. The check looked rigorous and was worthless, because it was performed downstream of the corruption.

What resolved it was going back to `online_retail_staging` — a table that had never been re-inserted into and so could not have been affected — and reading the true figure there: **107,927** guest rows. Verification only means something when the thing being verified against could not have been touched by the same fault.

### 2.6 The six engineered columns

Each was previewed as a `SELECT` first, checked, and only then committed via `ALTER TABLE` + `UPDATE`.

| Column | Logic |
|---|---|
| `CustomerType` | `Guest` where `CustomerID IS NULL`, else `Registered` |
| `IsCancelled` | `Cancelled` where `LEFT(Invoice,1) = 'C'` |
| `IsManualWriteOff` | `remove` where not cancelled, `Price = 0`, `Quantity < 0` |
| `IsNonProduct` | `remove` where `UPPER(StockCode)` is in the 16-code exclusion list |
| `IsGiftVoucher` | `Gift Voucher` where `LEFT(StockCode,5) = 'gift_'` |
| `Revenue` | `Quantity * Price`, stored `DECIMAL(20,3)` to match Price's precision |

Two notes on these:

`CustomerID` blanks arrived as empty strings (`''`), not `NULL` — 107,927 of them, with zero true NULLs. Because `= NULL` never matches anything in SQL, a `CustomerType` rule written against `IS NULL` would have silently produced zero guests. The blanks were explicitly converted to `NULL` first.

`IsNonProduct` uses `UPPER(StockCode)` deliberately. MySQL's default collation is case-insensitive, so a plain `IN (...)` already catches the lowercase `"m"` rows — but only by accident of engine configuration. The same query on PostgreSQL would reproduce the original Excel defect exactly. Writing the case-folding explicitly makes the behaviour a property of the query rather than of the server.

### 2.7 Reconciliation results

| Measure | Result | Status |
|---|---|---|
| Row count | 525,461 | matched |
| Net Sales Revenue | £9,590,901.39 | matched |
| Distinct cancelled invoices | 4,592 | matched |
| Real Order Count (total) | 21,705 | matched |
| Real Order Count (Guest / Registered) | 2,739 / 18,966 | matched |
| Average Order Value | £425.47 / £457.31 | **differed from Excel** — see 4.5 |
| EIRE real accounts / revenue | 3 / £325,403.11 | matched after correction |
| Top 5 products share | 5.65% | **differed from Excel** — see 4.4 |
| November 2010 peak | £1,400,559.24 | matched |
| Q4 2010 | £2,875,375.65 | matched |

---

## 3. Power BI rebuild

### 3.1 Connection

Power BI connects to MySQL directly rather than via CSV export. This was not the original plan — the CSV route was attempted first and abandoned after Workbench's grid export crashed repeatedly at this row count, and truncated at 50,000 rows before that (a per-tab "Limit Rows" setting, separate from the one in Preferences).

Connecting live turned out to be both simpler and closer to real practice. Requirements:

- **MySQL Connector/NET** installed — Power BI's MySQL connector will not function without it
- Server: `localhost` (one word, lowercase — autocorrect rendering this as "Local host" produced a `Unable to connect to any of the specified MySQL hosts` error that looked like a credentials problem)
- Authentication: **Database**, not Windows — MySQL maintains its own credentials
- Table selected: `online_retail` only, not the staging table

Because all cleaning and all six engineered columns already exist in SQL, no Power Query transformation was needed. The table loads ready to model.

### 3.2 Measures built

| Measure | Definition |
|---|---|
| `Netsalesrevenue` | `SUM(Revenue)` with the three base filters, no `IsCancelled` filter |
| `GroseRevenue` | `SUM(Revenue)` where not cancelled and `Quantity > 0` |
| `CancelledRevenue` | `SUM(Revenue)` where cancelled |
| `NetRevenue` | plain unfiltered `SUM(Revenue)` |
| `AdminandVoucherValue` | `SUM(Revenue)` where any one of the three exclusion flags fires (OR, via `\|\|`) |
| `realordercount` | `DISTINCTCOUNT(Invoice)`, three base filters plus `IsCancelled = "Not Cancelled"` |
| `averageordervalue` | revenue ÷ order count, both with the identical four-filter set |
| `EIRE_customer_id` | `DISTINCTCOUNT(CustomerID)`, EIRE + three base filters + `CustomerID <> BLANK()` |
| `revenue_for_EIRE` | `SUM(Revenue)`, same five conditions |
| `Top5Revenue` | `SUMX(TOPN(5, VALUES(StockCode), ...), ...)` wrapped in `CALCULATE` with the base filters |
| `TotalOrders` | `DISTINCTCOUNT(Invoice)`, unfiltered |
| `cancellationrate` | cancelled invoices ÷ total invoices × 100 |
| `DistinctProducts` | `DISTINCTCOUNT(StockCode)` with four filters plus `Description <> "Blank"` |

Two DAX mechanics worth recording:

**Comma means AND inside `CALCULATE`.** Filter arguments separated by commas must all hold simultaneously. `AdminandVoucherValue` needs OR — a row qualifies if *any one* of the three exclusion flags fires — so those three conditions are joined with `||` inside a single filter argument, not split across commas.

**`TOPN` returns rows, not values.** It hands back the winning StockCodes without the revenue figures it ranked them by, which is why `SUMX` has to recalculate each one. The outer `CALCULATE` wrapping the whole expression pushes the base filters down into both the ranking step and the summing step, keeping them consistent.

**DAX string comparison is case-insensitive**, confirmed by `cancellationrate` returning 15.94% with a lowercase `"cancelled"` literal. Matching the data's real casing anyway remains the safer habit, for the same reason as `UPPER()` in SQL.

### 3.3 Dashboard

Three pages: Overview (four KPI cards, Revenue Bridge waterfall, Monthly Revenue Trend), Customer & Product Analysis (revenue by country, top 10 products, AOV and cancellation rate by customer type), and Key Insights (written summary).

Two build notes:

The Revenue Bridge waterfall needs its inputs as *rows*, but the four bridge figures exist as separate measures. A small manual `BridgeCategories` table supplies the category labels, and a `SWITCH(SELECTEDVALUE(...))` measure returns the matching value per row. Category ordering required a `SortOrder` column — entered as plain typed data, because defining it as a calculated column that reads `Category` while also sorting `Category` by it creates a circular dependency Power BI refuses.

The Monthly Revenue Trend initially plotted month alone, merging December 2009 and December 2010 into one point and hiding the December collapse entirely. Adding Year to the axis restored the real shape.

---

## 4. What changed, and why

Six defects, all now corrected in all three versions.

### 4.1 Case-sensitive product-code matching
The Power Query formula compared `[StockCode]="M"` case-sensitively and missed 4 rows carrying lowercase `"m"` (Description: "Manual") — manual write-offs counted as real sales. Fixed with `Text.Upper()` in M and `UPPER()` in SQL.

### 4.2 Orphaned duplicate Data Model table
The Excel workbook had accumulated a second, stale, disconnected copy of the model table alongside the live one, feeding wrong values into Real Order Count and Average Order Value specifically. Deleted, measures rebuilt against the correct table. Excel-specific; no equivalent in SQL or Power BI.

### 4.3 Blank counted as a distinct account
`DISTINCTCOUNT` treats blank as one distinct value, so every anonymous guest checkout in EIRE collapsed into a single phantom sixth "account". Real accounts: 3, not 6. Revenue from identifiable accounts: £325,403.11, with a further £23,465.81 anonymous. Per-account average: £108,467.70, not £58,144.82 — roughly 53x the UK average rather than 28x.

SQL does not reproduce this: `COUNT(DISTINCT ...)` excludes NULL by default. The explicit `CustomerID IS NOT NULL` / `<> BLANK()` condition is stated anyway rather than relied upon.

### 4.4 Product revenue fragmented by Description
The Top Products ranking grouped by `Description` rather than `StockCode`. StockCode `85099B` carries three description variants — "JUMBO BAG RED RETROSPOT" (£56,444.61), "JUMBO BAG RED WHITE SPOTTY" (£25,054.27), "RED RETROSPOT JUMBO BAG" (£9,535.24) — for one product worth £91,034.12 combined. Split three ways, it dropped out of the true top five and a lower-ranked product took its place. Corrected share: **5.65%**, not 5.27%.

`StockCode` is the stable identifier; `Description` is free text that drifts.

### 4.5 Mismatched filters in Average Order Value
The numerator summed revenue with three filters (cancellations included, netting naturally). The denominator counted invoices with four (cancellations excluded). Numerator and denominator therefore described different sets of transactions. Applying `IsCancelled = "Not Cancelled"` consistently to both gives **£425.47 Guest / £457.31 Registered**.

The direction of the finding is unchanged and still holds: the two groups spend near-identically per order, and cancellation behaviour is what separates them.

### 4.6 Revenue Bridge sign direction
`AdminandVoucherValue` nets to **−£51,416.76**, not the +£51,429.26 previously carried. It is negative because bad debt (−£136,552.02), Amazon fees (−£39,243.08), manual adjustments (−£14,109.63), bank charges (−£28,387) and discounts (−£7,788.32) outweigh postage and carriage income (+£168,894 combined).

Because the measure sums the revenue being *removed*, the bridge must subtract it. Adding it directly put the total out by £102,833.52. Corrected: £9,539,484.63 − (−£51,416.76) = **£9,590,901.39**.

---

## 5. Known limitations

**Cancellations cannot be traced to their original sale.** `IsCancelled` judges each invoice solely on whether its own number begins with "C". It cannot ask whether a given sale was later reversed by a separate transaction, and no invoice-linking key exists in the data — a check for cancellation invoices matching `'C' + original invoice number` returned zero matches.

Real Order Count therefore means *"invoices not themselves recorded as cancellation transactions"*, not *"orders confirmed to have been kept"*. An order placed and later fully cancelled through a separate invoice still counts as one real order. This is a property of the dataset's structure, not something better SQL would fix.

**Distinct Products was reported as an unresolved one-row gap (4,144 vs. a documented 4,145).** This has since been resolved, not left open: the 4,145 figure was itself a casualty of the case-sensitivity bug in §4.1 (the 4 lowercase-`"m"` rows were being wrongly counted as a distinct product before that fix). Once corrected, Excel recalculates to 4,144, matching SQL and Power BI exactly.

**Registered-customer cancelled value (−£483,794.70) has since been independently re-derived in both SQL and Power BI** and matches the original Excel figure exactly. It is no longer an open item.

---

## 6. Summary of final figures

| Measure | Value |
|---|---|
| Rows | 525,461 |
| Gross Revenue | £10,169,340.00 |
| Cancelled Value | −£629,855.37 |
| Net Revenue | £9,539,484.63 |
| Admin & Voucher Value | −£51,416.76 |
| **Net Sales Revenue** | **£9,590,901.39** |
| Total Orders | 28,816 |
| Cancelled Orders | 4,592 |
| Real Order Count | 21,705 (Guest 2,739 / Registered 18,966) |
| Cancellation Rate | 15.94% overall; Registered 18.54%, Guest 4.21% |
| Average Order Value | Guest £425.47 / Registered £457.31 |
| Distinct Products | 4,144 |
| EIRE | 3 real accounts, £325,403.11, £108,467.70 per account |
| Top 5 Products | £542,275.33 — 5.65% of Net Sales Revenue, ~47x the 0.12% expected if spread evenly across 4,144 products |
| Peak month | November 2010, £1,400,559.24 |
| Q4 2010 | £2,875,375.65 |
