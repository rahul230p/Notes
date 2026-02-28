# Amazon - E-Commerce Data Model

## Overview
**Type:** OLAP (Analytics)  
**Focus:** E-Commerce Platform Analytics  
**Granularity:** Daily metrics  
**Purpose:** Track sales, customer behavior, and inventory

---

## ⚠️ Clarifying Questions (ASK FIRST - VERY IMPORTANT)

Always start with these. This signals seniority.

### Required Questions to Ask

#### Business Context
```
• Is this an OLAP (analytics) or OLTP (transactional) system?
• What are the key business metrics? (GMV, conversion rate, AOV, customer lifetime value)
• What questions do stakeholders want answered first?
• What events are tracked? (browse, add to cart, checkout, purchase, return, review)
```

#### Data Specifics
```
• Is data stored as raw events or pre-aggregated metrics?
• What is the analysis granularity? (daily, weekly, monthly)
• Do we track customer segments, product categories, regional performance?
• Is real-time analytics required or batch sufficient?
```

### Assumed Answers for This Case
- OLAP system
- Raw event ingestion
- Daily analytics with flexibility
- Batch processing initially

---

## Star Diagram

```
                        ┌─────────────────┐
                        │   dim_customer  │
                        └────────┬────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
            ┌───────▼──────┐ ┌──▼──────────┐ │
            │fact_purchases│ │fact_returns │ │
            └───────┬──────┘ └──┬──────────┘ │
                    │            │           │
                    └────────────┼───────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
            ┌───────▼──────┐ ┌──▼──────────┐ │
            │ dim_product  │ │  dim_date   │ │
            └──────────────┘ └─────────────┘ │
                    │                        │
            ┌───────▼──────────┬─────────────▼────┐
            │  dim_category    │   dim_currency   │
            └──────────────────┴──────────────────┘
```

---

## Dimension Tables

### dim_customer
| Column | Type | Description |
|--------|------|-------------|
| **customer_id** (PK) | Integer | Unique customer identifier |
| signup_date | Date | When customer joined |
| country | String | Customer country |
| account_tier | String | Prime/Standard/etc. |
| lifetime_value | Decimal | Total spending to date |

### dim_product
| Column | Type | Description |
|--------|------|-------------|
| **product_id** (PK) | Integer | Unique product identifier |
| **category_id** (FK) | Integer | Links to dim_category |
| product_name | String | Product name |
| price | Decimal | Current price |
| status | String | Active/Discontinued |

### dim_category
| Column | Type | Description |
|--------|------|-------------|
| **category_id** (PK) | Integer | Unique category identifier |
| **parent_category_id** (FK) | Integer | Parent category (hierarchy) |
| category_name | String | Category name |
| level | Integer | Depth level (1, 2, 3) |

### dim_date
| Column | Type | Description |
|--------|------|-------------|
| **date_id** (PK) | Integer | Date key (YYYYMMDD) |
| calendar_date | Date | Full date |
| day_of_week | String | Monday-Sunday |
| month | Integer | 1-12 |
| year | Integer | Year |
| quarter | Integer | Q1-Q4 |
| is_holiday | Boolean | Holiday flag |

### dim_currency
| Column | Type | Description |
|--------|------|-------------|
| **currency_id** (PK) | Integer | Unique currency identifier |
| currency_code | String | USD, EUR, etc. |
| exchange_rate | Decimal | Daily snapshot |

---

## Fact Tables

### fact_purchases ⭐
**Grain:** One row per order line item

| Column | Type | Description |
|--------|------|-------------|
| **purchase_id** (PK) | Integer | Unique transaction identifier |
| **customer_id** (FK) | Integer | Links to dim_customer |
| **product_id** (FK) | Integer | Links to dim_product |
| **date_id** (FK) | Integer | Links to dim_date |
| **currency_id** (FK) | Integer | Links to dim_currency |
| quantity | Integer | Units sold |
| unit_price | Decimal | Price per unit |
| total_price | Decimal | quantity × unit_price |
| rating | Integer | 1-5 star rating (if given) |

### fact_returns ⭐
**Grain:** One row per returned item

| Column | Type | Description |
|--------|------|-------------|
| **return_id** (PK) | Integer | Unique return identifier |
| **purchase_id** (FK) | Integer | Links to fact_purchases |
| **customer_id** (FK) | Integer | Links to dim_customer |
| **date_id** (FK) | Integer | Links to dim_date |
| return_reason | String | Defective/Wrong item/etc. |
| refund_amount | Decimal | Amount refunded |

---

## Key Relationships

```
dim_customer (1) ──< (N) fact_purchases
dim_customer (1) ──< (N) fact_returns

dim_product (1) ──< (N) fact_purchases
dim_category (1) ──< (N) dim_product (hierarchy)

dim_date (1) ──< (N) fact_purchases
dim_date (1) ──< (N) fact_returns

dim_currency (1) ──< (N) fact_purchases
```

---

## Core Analytics Queries

### 1. Daily Gross Merchandise Value (GMV)
```sql
SELECT 
    dt.calendar_date,
    SUM(fp.total_price) AS daily_gmv,
    COUNT(DISTINCT fp.customer_id) AS unique_customers
FROM fact_purchases fp
JOIN dim_date dt ON fp.date_id = dt.date_id
GROUP BY dt.calendar_date
ORDER BY dt.calendar_date DESC;
```

### 2. Average Order Value (AOV) by Category
```sql
SELECT 
    dc.category_name,
    AVG(fp.total_price) AS aov,
    COUNT(fp.purchase_id) AS total_orders
FROM fact_purchases fp
JOIN dim_product dp ON fp.product_id = dp.product_id
JOIN dim_category dc ON dp.category_id = dc.category_id
GROUP BY dc.category_name
ORDER BY aov DESC;
```

### 3. Return Rate by Product
```sql
SELECT 
    dp.product_name,
    COUNT(DISTINCT CASE WHEN fr.return_id IS NOT NULL THEN fp.purchase_id END) AS returns,
    COUNT(DISTINCT fp.purchase_id) AS total_sales,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN fr.return_id IS NOT NULL THEN fp.purchase_id END) / 
          COUNT(DISTINCT fp.purchase_id), 2) AS return_rate_pct
FROM fact_purchases fp
LEFT JOIN fact_returns fr ON fp.purchase_id = fr.purchase_id
JOIN dim_product dp ON fp.product_id = dp.product_id
GROUP BY dp.product_name
ORDER BY return_rate_pct DESC;
```

### 4. Top 10 Products by Revenue
```sql
SELECT TOP 10
    dp.product_name,
    dc.category_name,
    SUM(fp.total_price) AS total_revenue,
    SUM(fp.quantity) AS units_sold
FROM fact_purchases fp
JOIN dim_product dp ON fp.product_id = dp.product_id
JOIN dim_category dc ON dp.category_id = dc.category_id
GROUP BY dp.product_id, dp.product_name, dc.category_name
ORDER BY total_revenue DESC;
```

### 5. Customer Lifetime Value (CLV) by Tier
```sql
SELECT 
    dc.account_tier,
    COUNT(DISTINCT fp.customer_id) AS customers,
    SUM(fp.total_price) AS total_revenue,
    ROUND(SUM(fp.total_price) / COUNT(DISTINCT fp.customer_id), 2) AS avg_clv
FROM fact_purchases fp
JOIN dim_customer dc ON fp.customer_id = dc.customer_id
GROUP BY dc.account_tier
ORDER BY avg_clv DESC;
```

---

## Design Principles

✅ **Simplified:** Only 2 fact tables instead of 6  
✅ **Clear Grain:** Each fact represents a business event  
✅ **Hierarchies:** Categories support drill-down  
✅ **Multi-Currency:** Supports global expansion  
✅ **Extensible:** Easy to add new facts  

---

## Interview Tips

1. **Grain Definition:** "Each row in fact_purchases represents one item sold in an order"
2. **Why 2 Facts?** "Purchases are core transactions, returns are separate events"
3. **Hierarchy:** "Categories have parent_category_id for drill-down analysis"
4. **Star Schema:** "Fact tables at center connect to dimensions radiating outward"

---

## Follow-Up Questions & Answers

### Q1: "What if we need to track cart abandonment?"
**A:** Create a new fact table `fact_cart_abandonments`:
```sql
CREATE TABLE fact_cart_abandonments (
    abandonment_id INT PRIMARY KEY,
    customer_id INT FK,
    date_id INT FK,
    cart_items_count INT,
    cart_value DECIMAL,
    abandoned_at TIMESTAMP
);
```
Reuse dim_customer, dim_date. Existing queries unchanged.

### Q2: "How do we handle multi-currency transactions?"
**A:** Use dim_currency with exchange rates and convert in queries:
```sql
SELECT 
    dp.product_name,
    dc.currency_code,
    SUM(fp.total_price * 
        CASE WHEN dc.currency_code = 'USD' THEN 1 
             ELSE er.exchange_rate 
        END) AS revenue_usd
FROM fact_purchases fp
JOIN dim_currency dc ON fp.currency_id = dc.currency_id
GROUP BY dp.product_name, dc.currency_code;
```

### Q3: "What's the cardinality of each dimension?"
**A:**
- dim_customer: 500M (large but manageable)
- dim_product: 100M (large, but indexed well)
- dim_category: 100K (small, low cardinality)
- dim_currency: 200 (very small)
- dim_date: 40K (small, indexed)

### Q4: "Should we track product price history?"
**A:** Implement Slowly Changing Dimension (SCD) Type 2:
```sql
CREATE TABLE dim_product (
    product_id INT,
    product_name VARCHAR,
    price DECIMAL,
    version_number INT,
    start_date DATE,
    end_date DATE,
    is_current BOOLEAN
);
```
Enables historical price analysis without breaking current queries.

### Q5: "How do we handle seasonal products?"
**A:** Add a flag to dim_product and filter:
```sql
SELECT TOP 20 *
FROM fact_purchases fp
JOIN dim_product dp ON fp.product_id = dp.product_id
WHERE dp.is_seasonal = 1
  AND MONTH(fp.purchase_date) IN (11, 12);
```

### Q6: "What about promotional pricing?"
**A:** Add discount tracking to fact_purchases:
```sql
ALTER TABLE fact_purchases 
ADD discount_amount DECIMAL,
ADD discount_percentage DECIMAL,
ADD promo_code_id INT;

SELECT 
    SUM(discount_amount) AS total_discounts,
    COUNT(*) AS discounted_orders
FROM fact_purchases
WHERE discount_amount > 0;
```

### Q7: "How do we measure return ROI?"
**A:** Join facts and calculate:
```sql
SELECT 
    dp.product_id,
    dp.product_name,
    COUNT(fp.order_id) AS sold,
    COUNT(fr.return_id) AS returned,
    ROUND(100.0 * COUNT(fr.return_id) / COUNT(fp.order_id), 2) AS return_rate,
    SUM(fp.total_price) - SUM(fr.refund_amount) AS net_revenue
FROM fact_purchases fp
LEFT JOIN fact_returns fr ON fp.order_id = fr.order_id
JOIN dim_product dp ON fp.product_id = dp.product_id
GROUP BY dp.product_id, dp.product_name;
```

### Q8: "Should sellers data be a dimension or fact?"
**A:** Dimension (dim_seller). Sellers are attributes of products, not events:
```sql
-- Correct: seller is context
SELECT 
    ds.seller_name,
    SUM(fp.total_price) AS revenue
FROM fact_purchases fp
JOIN dim_seller ds ON fp.seller_id = ds.seller_id
GROUP BY ds.seller_name;
```

### Q9: "How do we handle dimension-to-dimension joins?"
**A:** NEVER join dim → dim. Flatten the dimension instead:
```sql
-- WRONG
SELECT ... FROM fact_purchases 
JOIN dim_product ON ...
JOIN dim_category ON dim_product.category_id = dim_category.category_id;

-- RIGHT: Add category_name to dim_product
SELECT ... FROM fact_purchases 
JOIN dim_product ON ...
WHERE dim_product.category_name = 'Electronics';
```

### Q10: "What's the minimum viable grain for purchases?"
**A:** One row per order line item (quantity × unit_price = line total):
```sql
-- CORRECT grain
SELECT 
    order_id,
    product_id,
    quantity,
    unit_price,
    quantity * unit_price AS line_total
FROM fact_purchases;

-- NOT order level (loses item detail)
-- NOT product level (mixes multiple orders)
```

---

## Common Interview Mistakes to Avoid

❌ **WRONG:** Including product_name in fact_purchases  
✅ **RIGHT:** Use product_id FK, join to dim_product when needed

❌ **WRONG:** Mixing discounts and taxes into one column  
✅ **RIGHT:** Separate columns or separate facts

❌ **WRONG:** Joining dim_category to dim_product to dim_subcategory  
✅ **RIGHT:** Flatten into single dimension with hierarchy columns

❌ **WRONG:** Storing aggregated data (daily totals)  
✅ **RIGHT:** Store transaction level, aggregate on query

---

## One-Liner Reminders

📌 "Fact table grain: one row per order line item."

📌 "Always ask about price history and SCD requirements."

📌 "Flatten dimensions to avoid dim-to-dim joins."

📌 "Keep facts at lowest useful grain; aggregate on query."

