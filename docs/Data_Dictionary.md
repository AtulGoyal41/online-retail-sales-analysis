# Data Dictionary — Online Retail II Analysis (2009-2010)

This document describes every column in the cleaned dataset used for this project, including both the original raw columns and the columns engineered during data cleaning in Power Query.

## Original Columns

| Column | Description | Data Type |
|---|---|---|
| Invoice | Contains multiple products grouped under a single invoice number; a value starting with "C" indicates the order was cancelled. | Text |
| StockCode | Identifies and tracks the specific product in the inventory. | Text |
| Description | Plain text name of the product being sold. | Text |
| Quantity | Positive value = units sold; negative value = units returned/cancelled. | Number |
| InvoiceDate | Date and time the invoice/order was created. | Date/Time |
| Price | Price per single unit of the product. | Decimal |
| Customer ID | Unique identifier for a customer when present; blank indicates a guest checkout with no customer account. | Text |
| Country | Country the order was placed from. | Text |

## Built Columns (Engineered in Power Query)

| Column | Description | Formula (Power Query M) | Data Type |
|---|---|---|---|
| CustomerType | Guest if Customer ID is blank, Registered if Customer ID has a value. | `if [CustomerID]=null then "Guest" else "Registered"` | Text |
| IsCancelled | Cancelled when Invoice starts with "C," otherwise Not Cancelled. | `if Text.StartsWith([Invoice],"C") then "Cancelled" else "Not Cancelled"` | Text |
| IsManualWriteOff | Remove when quantity, price, and invoice are not null, quantity is less than 0, price equals 0, and invoice does not start with "C"; otherwise, keep. | `if [Quantity] <> null and [Price] <> null and [Invoice] <> null and [Quantity] < 0 and [Price] = 0 and Text.StartsWith([Invoice], "C") = false then "Remove" else "Keep"` | Text |
| IsNonProduct | Remove when StockCode equals POST, DOT, M, D, ADJUST, ADJUST2, B, C2, C3, BANK CHARGES, AMAZONFEE, TEST001, TEST002, SP1002, S, or GIFT; otherwise Keep. | `if [StockCode]="POST" or [StockCode]="DOT" or [StockCode]="M" or [StockCode]="ADJUST" or [StockCode]="ADJUST2" or [StockCode]="B" or [StockCode]="C2" or [StockCode]="C3" or [StockCode]="BANK CHARGES" or [StockCode]="AMAZONFEE" or [StockCode]="TEST001" or [StockCode]="TEST002" or [StockCode]="SP1002" or [StockCode]="S" or [StockCode]="GIFT" or [StockCode]="D" then "Remove" else "Keep"` | Text |
| IsGiftVoucher | Gift Voucher when StockCode starts with "gift_," otherwise Non Voucher. | `if Text.StartsWith([StockCode],"gift_") then "Gift Voucher" else "Non Voucher"` | Text |
| Revenue | Quantity multiplied by Price. | `[Quantity] * [Price]` | Decimal |

## Notes

- `IsManualWriteOff`, `IsNonProduct`, and `IsGiftVoucher` are exclusion flags used to isolate genuine product sales from cancellations, warehouse adjustments, admin fees, and gift vouchers before calculating final revenue.
- The final revenue figure used throughout this analysis is the **Net Sales Revenue** measure, which applies the `IsManualWriteOff`, `IsNonProduct`, and `IsGiftVoucher` filters (deliberately excluding `IsCancelled`, since cancelled rows carry negative Revenue values that net naturally against their original sale).
