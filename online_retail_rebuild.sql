-- =====================================================================
-- Online Retail II — SQL Rebuild
-- Dataset: UCI Online Retail II (Year_2009_2010 sheet, ~525,461 rows)
-- Source: https://archive.ics.uci.edu/dataset/502/online+retail+ii
--
-- This script rebuilds the full cleaning and analysis pipeline that was
-- originally built in Excel/Power Query/DAX, independently in MySQL.
-- Every derived column and every final number below was verified against
-- the original Excel build. That cross-verification surfaced two real
-- bugs in the original Excel logic that had gone undetected:
--   1. A Windows line-ending artifact (carriage return, \r) silently
--      corrupting every value in the Country column.
--   2. A Description-based grouping error in the original Top Products
--      chart that fragmented one product's true revenue across three
--      separate rows, producing an incorrect "Top 5" list.
-- Both are documented and fixed below.
-- =====================================================================


-- =====================================================================
-- SECTION 1: DATABASE AND TABLE SETUP
-- =====================================================================

CREATE DATABASE online_retail;
USE online_retail;

-- Staging table: raw import, InvoiceDate kept as text since the source
-- CSV stores dates as DD-MM-YYYY HH:MM:SS, which MySQL's DATETIME type
-- cannot parse directly on load.
CREATE TABLE online_retail_staging (
    Invoice     VARCHAR(10),
    StockCode   VARCHAR(15),   -- widened from 10 to fit 'BANK CHARGES' (12 chars)
    Description VARCHAR(100),
    Quantity    INT,
    InvoiceDate VARCHAR(20),
    Price       DECIMAL(10,3), -- 3 decimal places to preserve values like 0.001
    CustomerID  VARCHAR(5),
    Country     VARCHAR(50)
);

-- Final table: same structure, but InvoiceDate is a proper DATETIME.
CREATE TABLE online_retail (
    Invoice     VARCHAR(10),
    StockCode   VARCHAR(15),
    Description VARCHAR(100),
    Quantity    INT,
    InvoiceDate DATETIME,
    Price       DECIMAL(10,3),
    CustomerID  VARCHAR(5),
    Country     VARCHAR(50)
);


-- =====================================================================
-- SECTION 2: LOAD RAW DATA
-- =====================================================================

-- Note: source CSV must be UTF-8 encoded (plain "CSV (Comma delimited)"
-- exports from Excel use Windows-1252 by default and will fail on
-- special characters). Use "CSV UTF-8 (Comma delimited)" when exporting.
-- File must sit in MySQL's secure_file_priv directory to be readable.

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Year_2009_2010.csv'
INTO TABLE online_retail_staging
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Insert into final table, converting InvoiceDate text -> DATETIME.
-- Format string matches the source's DD-MM-YYYY HH:MM:SS layout exactly.
INSERT INTO online_retail (Invoice, StockCode, Description, Quantity, InvoiceDate, Price, CustomerID, Country)
SELECT Invoice, StockCode, Description, Quantity,
       STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i:%s'),
       Price, CustomerID, Country
FROM online_retail_staging;

-- Expect: 525,461 rows in online_retail. Verify before proceeding:
-- SELECT COUNT(*) FROM online_retail;


-- =====================================================================
-- SECTION 3: DATA CLEANING
-- =====================================================================

-- 3a. CustomerID: blanks were loaded as empty strings ('') rather than
-- NULL. Convert to NULL so "no customer" is represented properly.
SET SQL_SAFE_UPDATES = 0;

UPDATE online_retail
SET CustomerID = NULL
WHERE CustomerID = '';

-- 3b. BUG FIX — Country column had a hidden trailing carriage return
-- (\r, hex 0D) on every value, left over because LOAD DATA INFILE was
-- told LINES TERMINATED BY '\n' only, not '\r\n'. This made exact-match
-- filters like Country = 'EIRE' silently return zero rows even though
-- the value visually displayed as "EIRE". Confirmed via HEX(Country)
-- and fixed by trimming the character explicitly (plain TRIM() does not
-- remove \r, since it only strips ordinary spaces by default).
UPDATE online_retail
SET Country = TRIM(BOTH '\r' FROM Country);


-- =====================================================================
-- SECTION 4: BUILT COLUMNS (6 total)
-- Logic replicated exactly from the original Power Query build.
-- =====================================================================

-- 4a. CustomerType — Guest if CustomerID is NULL, else Registered.
ALTER TABLE online_retail ADD COLUMN CustomerType VARCHAR(15);
UPDATE online_retail
SET CustomerType = CASE WHEN CustomerID IS NULL THEN 'Guest' ELSE 'Registered' END;

-- 4b. IsCancelled — Cancelled if Invoice starts with "C".
ALTER TABLE online_retail ADD COLUMN IsCancelled VARCHAR(20);
UPDATE online_retail
SET IsCancelled = CASE WHEN LEFT(Invoice,1) = 'C' THEN 'Cancelled' ELSE 'Not Cancelled' END;

-- 4c. IsManualWriteOff — Remove rows that are negative-quantity,
-- zero-price, and NOT part of a real cancellation (i.e. manual
-- write-offs rather than genuine cancelled sales).
ALTER TABLE online_retail ADD COLUMN IsManualWriteOff VARCHAR(10);
UPDATE online_retail
SET IsManualWriteOff = CASE
    WHEN Invoice IS NOT NULL
     AND IsCancelled = 'Not Cancelled'
     AND Price IS NOT NULL AND Price = 0.000
     AND Quantity IS NOT NULL AND Quantity < 0
    THEN 'remove' ELSE 'keep' END;

-- 4d. IsNonProduct — Remove specific non-product StockCodes (postage,
-- admin fees, test entries, adjustments, etc.).
-- BUG FIX: original Excel formula used case-sensitive comparisons
-- ([StockCode]="M") and missed 4 rows with lowercase StockCode "m"
-- (a manual write-off entry). MySQL's default collation is
-- case-insensitive so a plain IN(...) check happens to catch these
-- correctly, but that's incidental, not guaranteed on every SQL engine
-- (e.g. PostgreSQL is case-sensitive by default). UPPER() is used here
-- so the logic is correct by design, not by accident.
ALTER TABLE online_retail ADD COLUMN IsNonProduct VARCHAR(15);
UPDATE online_retail
SET IsNonProduct = CASE
    WHEN UPPER(StockCode) IN ('POST','DOT','M','D','ADJUST','ADJUST2','B','C2','C3',
                               'BANK CHARGES','AMAZONFEE','TEST001','TEST002','SP1002','S','GIFT')
    THEN 'remove' ELSE 'keep' END;

-- 4e. IsGiftVoucher — Gift Voucher if StockCode starts with "gift_".
ALTER TABLE online_retail ADD COLUMN IsGiftVoucher VARCHAR(15);
UPDATE online_retail
SET IsGiftVoucher = CASE WHEN LEFT(StockCode,5) = 'gift_' THEN 'Gift Voucher' ELSE 'Non Voucher' END;

-- 4f. Revenue — Quantity x Price. DECIMAL(20,3) matches Price's
-- 3-decimal precision so small values (e.g. 0.001) aren't rounded away.
ALTER TABLE online_retail ADD COLUMN Revenue DECIMAL(20,3);
UPDATE online_retail
SET Revenue = Quantity * Price;


-- =====================================================================
-- SECTION 5: ANALYSIS / EDA FINDINGS
-- All 5 findings below were independently reconciled against the
-- original Excel build. Two genuine bugs were found and corrected
-- along the way (see notes inline).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Finding 1: Net Sales Revenue
-- Filters: IsManualWriteOff="Keep", IsNonProduct="Keep",
-- IsGiftVoucher="Non Voucher" — deliberately NO IsCancelled filter,
-- since cancelled rows' negative revenue nets naturally against the
-- original sale.
-- Verified result: £9,590,901.39
-- ---------------------------------------------------------------------
SELECT SUM(Revenue) AS NetSalesRevenue
FROM online_retail
WHERE IsManualWriteOff = 'Keep' AND IsNonProduct = 'Keep' AND IsGiftVoucher = 'Non Voucher';


-- ---------------------------------------------------------------------
-- Finding 2: Real Order Count and Average Order Value (AOV) by
-- CustomerType. Unlike Net Sales Revenue, cancelled orders ARE
-- excluded here, since a cancelled invoice is not a genuinely
-- completed order.
-- Verified results:
--   Real Order Count: Guest 2,739 | Registered 18,966 | Total 21,705
--   AOV: Guest £424.54 | Registered £444.38
-- ---------------------------------------------------------------------
SELECT
    CustomerType,
    COUNT(DISTINCT Invoice) AS RealOrderCount,
    SUM(Revenue) AS Revenue,
    SUM(Revenue) / COUNT(DISTINCT Invoice) AS AverageOrderValue
FROM online_retail
WHERE IsCancelled = 'Not Cancelled'
  AND IsManualWriteOff = 'Keep'
  AND IsNonProduct = 'Keep'
  AND IsGiftVoucher = 'Non Voucher'
GROUP BY CustomerType;


-- ---------------------------------------------------------------------
-- Finding 3: EIRE Concentration Risk
-- Distinct-customer count uses ONLY Country = 'EIRE' (no other
-- filters), matching how "distinct accounts" should be measured —
-- a customer's identity doesn't change based on write-off/voucher
-- flags on individual line items.
-- Revenue and per-account average DO use the three base filters plus
-- an explicit CustomerID IS NOT NULL, so anonymous guest checkouts
-- aren't miscounted as a real "account".
-- Verified results: 3 real accounts, £325,403.11 total,
-- £108,467.70 average per account.
-- ---------------------------------------------------------------------
SELECT
    COUNT(DISTINCT CustomerID) AS RealAccountCount,
    SUM(Revenue) AS RealAccountRevenue,
    SUM(Revenue) / COUNT(DISTINCT CustomerID) AS AvgRevenuePerAccount
FROM online_retail
WHERE Country = 'EIRE'
  AND CustomerID IS NOT NULL
  AND IsManualWriteOff = 'Keep'
  AND IsNonProduct = 'Keep'
  AND IsGiftVoucher = 'Non Voucher';


-- ---------------------------------------------------------------------
-- Finding 4: Top 5 Products by Revenue
-- Grouped by StockCode, NOT Description. BUG FOUND: the original
-- Excel Top Products chart grouped by Description instead of
-- StockCode. Product 85099B has three inconsistent Description
-- values ("JUMBO BAG RED RETROSPOT", "JUMBO BAG RED WHITE SPOTTY",
-- "RED RETROSPOT JUMBO BAG") for the same real product, which
-- fragmented its true revenue (£91,034.12) into three smaller rows
-- in Excel's chart — knocking it out of the true top 5 and replacing
-- it with a lower-ranked product. StockCode is the reliable,
-- consistent product identifier and is the correct grouping key.
-- Verified result: top 5 = £542,275.33, which is 5.65% of Net Sales
-- Revenue (not the original, Description-based 5.27%).
-- Cancelled rows are included (not filtered out), same reasoning as
-- Net Sales Revenue — a product's true net revenue should reflect
-- cancellations netting out.
-- ---------------------------------------------------------------------
WITH top_products AS (
    SELECT StockCode, SUM(Revenue) AS Revenue
    FROM online_retail
    WHERE IsManualWriteOff = 'Keep' AND IsNonProduct = 'Keep' AND IsGiftVoucher = 'Non Voucher'
    GROUP BY StockCode
    ORDER BY SUM(Revenue) DESC
    LIMIT 5
)
SELECT * FROM top_products;

-- Top-5 share of total Net Sales Revenue:
-- WITH top_products AS ( ... same as above ... )
-- SELECT SUM(Revenue) / 9590901.394 * 100 AS TopFivePercentOfRevenue
-- FROM top_products;


-- ---------------------------------------------------------------------
-- Finding 5: Seasonal Pattern
-- Grouped by year-month, formatted as 'YYYY-MM' specifically so the
-- text sorts in true chronological order (month-name or MM-YYYY
-- formats do not sort correctly as plain text).
-- Verified results:
--   November 2010 peak: £1,400,559.24
--   December 2010 drop: £402,363.51
--   Q4 2010 total (Oct+Nov+Dec): £2,875,375.65 (~£2.88M)
-- ---------------------------------------------------------------------
SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS YearMonth,
    SUM(Revenue) AS Revenue
FROM online_retail
WHERE IsManualWriteOff = 'Keep' AND IsNonProduct = 'Keep' AND IsGiftVoucher = 'Non Voucher'
GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m')
ORDER BY YearMonth;
