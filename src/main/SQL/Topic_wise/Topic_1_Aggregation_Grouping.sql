-- =====================================================
-- 🟢 LEVEL 1 — BASIC AGGREGATIONS
-- =====================================================

-- Q1. Total Revenue per Region
-- Table: sales(region, revenue)
-- Find total revenue generated in each region.


















/*
======================
SOLUTION
======================

SELECT region, SUM(revenue) AS total_revenue
FROM sales
GROUP BY region;

*/


-- Q2. Count of Orders per Customer
-- Table: orders(customer_id)
-- Find total number of orders placed by each customer.






/*
======================
SOLUTION
======================

SELECT customer_id, COUNT(*) AS order_count
FROM orders
GROUP BY customer_id;

*/


-- Q3. Average Revenue per Product
-- Table: sales(product, revenue)
-- Find average revenue per product.





/*
======================
SOLUTION
======================

SELECT product, AVG(revenue) AS avg_revenue
FROM sales
GROUP BY product;

*/

-- =====================================================
-- 🟢 LEVEL 2 — AGGREGATION WITH FILTERING
-- =====================================================

-- Q4. Regions with Total Revenue > 5000
-- Table: sales(region, revenue)
-- Return only regions where total revenue exceeds 5000.



/*
======================
SOLUTION
======================

SELECT region, SUM(revenue) AS total_revenue
FROM sales
GROUP BY region
HAVING SUM(revenue) > 5000;

*/


-- Q5. Products with More Than 2 Orders
-- Table: sales(product)
-- Find products that appear more than twice.



/*
======================
SOLUTION
======================

SELECT product, COUNT(*) AS order_count
FROM sales
GROUP BY product
HAVING COUNT(*) > 2;

*/

-- =====================================================
-- 🟠 LEVEL 3 — AGGREGATION + JOINS
-- =====================================================

-- Q6. Total Spend per Customer
-- Tables:
-- customers(customer_id, customer_name)
-- orders(customer_id, amount)
-- Find total amount spent by each customer.



/*
======================
SOLUTION
======================

SELECT c.customer_name,
       SUM(o.amount) AS total_spend
FROM customers c
JOIN orders o
  ON c.customer_id = o.customer_id
GROUP BY c.customer_name;

*/


-- Q7. Revenue per Region and Category
-- Table: sales(region, category, revenue)
-- Find total revenue grouped by region and category.



/*
======================
SOLUTION
======================

SELECT region,
       category,
       SUM(revenue) AS total_revenue
FROM sales
GROUP BY region, category;

*/

-- =====================================================
-- 🟠 LEVEL 4 — CONDITIONAL AGGREGATION
-- =====================================================

-- Q8. Revenue Split by Product Type
-- Table: sales(region, category, revenue)
-- Find electronics vs furniture revenue per region.



/*
======================
SOLUTION
======================

SELECT region,
       SUM(CASE WHEN category = 'Electronics' THEN revenue ELSE 0 END) AS electronics_revenue,
       SUM(CASE WHEN category = 'Furniture' THEN revenue ELSE 0 END) AS furniture_revenue
FROM sales
GROUP BY region;

*/


-- Q9. Count Active vs Inactive Customers
-- Table: customers(region, is_active)
-- Count active and inactive customers per region.



/*
======================
SOLUTION
======================

SELECT region,
       COUNT(CASE WHEN is_active = 1 THEN 1 END) AS active_customers,
       COUNT(CASE WHEN is_active = 0 THEN 1 END) AS inactive_customers
FROM customers
GROUP BY region;

*/

-- =====================================================
-- 🔵 LEVEL 5 — DERIVED METRICS & NESTED AGGREGATION
-- =====================================================

-- Q10. % Contribution of Each Product to Total Revenue
-- Table: sales(product, revenue)
-- Find percentage contribution of each product to overall revenue.



/*
======================
SOLUTION
======================

SELECT product,
       SUM(revenue) AS product_revenue,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS pct_of_total
FROM sales
GROUP BY product;

*/


-- Q11. Average Revenue per Customer per Region
-- Table: sales(region, customer_id, revenue)
-- First calculate total per customer, then average per region.



/*
======================
SOLUTION
======================

SELECT region,
       AVG(total_per_customer) AS avg_revenue_per_customer
FROM (
    SELECT region,
           customer_id,
           SUM(revenue) AS total_per_customer
    FROM sales
    GROUP BY region, customer_id
) t
GROUP BY region;

*/

-- =====================================================
-- 🔵 LEVEL 6 — ANALYTICAL / SENIOR-LEVEL QUESTIONS
-- =====================================================

-- Q12. Regions Contributing > 30% of Global Revenue
-- Table: sales(region, revenue)
-- Return regions whose contribution exceeds 30% of total revenue.



/*
======================
SOLUTION
======================

WITH region_sales AS (
    SELECT region,
           SUM(revenue) AS total_rev
    FROM sales
    GROUP BY region
)
SELECT region,
       total_rev,
       ROUND(100.0 * total_rev / SUM(total_rev) OVER (), 2) AS pct_share
FROM region_sales
WHERE 100.0 * total_rev / SUM(total_rev) OVER () > 30;

*/

-- =====================================================
-- 🔴 EXTRA MUST-HAVE INTERVIEW PROBLEMS (IMPORTANT)
-- =====================================================

-- Q13. Customers with More Than One Order on Same Day
-- Table: orders(customer_id, order_date)
-- Find customers who placed more than one order on the same day.



/*
======================
SOLUTION
======================

SELECT customer_id,
       order_date,
       COUNT(*) AS orders_count
FROM orders
GROUP BY customer_id, order_date
HAVING COUNT(*) > 1;

*/


-- Q14. Highest Revenue Region
-- Table: sales(region, revenue)
-- Find region with highest total revenue.



/*
======================
SOLUTION
======================

SELECT region
FROM sales
GROUP BY region
ORDER BY SUM(revenue) DESC
LIMIT 1;

*/


-- Q15. Orders vs Delivered Orders Count
-- Table: orders(order_status)
-- Return total orders and delivered orders in one row.



/*
======================
SOLUTION
======================

SELECT COUNT(*) AS total_orders,
       SUM(CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders
FROM orders;

*/
