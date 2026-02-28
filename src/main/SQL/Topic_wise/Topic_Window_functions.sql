🍎 TOPIC 4: WINDOW FUNCTIONS
🧱 Schema

sales

region	product	revenue	sale_date


🧩 Q1. Find Top 2 Products per Region
SELECT region, product, revenue
FROM (
  SELECT region, product, revenue,
         RANK() OVER (PARTITION BY region ORDER BY revenue DESC) AS rnk
  FROM sales
) t
WHERE rnk <= 2;

🧩 Q2. Compare Each Day’s Revenue with Previous Day
SELECT region,
       sale_date,
       revenue,
       LAG(revenue) OVER (PARTITION BY region ORDER BY sale_date) AS prev_day_revenue,
       revenue - LAG(revenue) OVER (PARTITION BY region ORDER BY sale_date) AS revenue_change
FROM sales;

🧩 Q3. Calculate Cumulative Revenue per Region
SELECT region,
       sale_date,
       SUM(revenue) OVER (PARTITION BY region ORDER BY sale_date) AS running_total
FROM sales;

🧩 Q4. Rank Products by Revenue (No Ties)
SELECT region, product, revenue,
       ROW_NUMBER() OVER (PARTITION BY region ORDER BY revenue DESC) AS rownum
FROM sales;

🍎 TOPIC 5: COMMON TABLE EXPRESSIONS (CTEs)
🧱 Schema

employees

emp_id	emp_name	manager_id	salary
🧩 Q1. Manager → Employee Mapping
WITH emp_data AS (
  SELECT emp_id, emp_name, manager_id FROM employees
)
SELECT e.emp_name AS employee,
       m.emp_name AS manager
FROM emp_data e
LEFT JOIN emp_data m ON e.manager_id = m.emp_id;

🧩 Q2. Recursive CTE – Build Org Hierarchy
WITH RECURSIVE hierarchy AS (
  SELECT emp_id, emp_name, manager_id, 1 AS level
  FROM employees
  WHERE manager_id IS NULL
  UNION ALL
  SELECT e.emp_id, e.emp_name, e.manager_id, h.level + 1
  FROM employees e
  JOIN hierarchy h ON e.manager_id = h.emp_id
)
SELECT * FROM hierarchy;

🧩 Q3. Average Salary per Level
WITH levels AS (
  SELECT emp_id, emp_name, manager_id, 1 AS lvl
  FROM employees WHERE manager_id IS NULL
  UNION ALL
  SELECT e.emp_id, e.emp_name, e.manager_id, l.lvl + 1
  FROM employees e JOIN levels l ON e.manager_id = l.emp_id
)
SELECT lvl, AVG(salary) AS avg_salary
FROM levels JOIN employees USING(emp_id)
GROUP BY lvl;

🍎 TOPIC 6: DATA CLEANING & TRANSFORMATION
🧱 Schema

customers

customer_id	customer_name	region	is_active	spend
🧩 Q1. Replace Missing Region with Default
SELECT customer_id,
       COALESCE(region, 'Unknown') AS region
FROM customers;

🧩 Q2. Conditional Aggregation – Active vs Inactive Spend
SELECT region,
       SUM(CASE WHEN is_active = 1 THEN spend ELSE 0 END) AS active_spend,
       SUM(CASE WHEN is_active = 0 THEN spend ELSE 0 END) AS inactive_spend
FROM customers
GROUP BY region;

🧩 Q3. Categorize Customers by Spend
SELECT customer_name,
       CASE
           WHEN spend > 1000 THEN 'High Value'
           WHEN spend BETWEEN 500 AND 1000 THEN 'Medium Value'
           ELSE 'Low Value'
       END AS customer_segment
FROM customers;

🧩 Q4. Handle Missing Spend Values
SELECT customer_name,
       COALESCE(spend, 0) AS spend
FROM customers;

🍎 TOPIC 7: ADVANCED ANALYTICS
🧱 Schema

user_activity

user_id	activity_date
🧩 Q1. Find Users with 3+ Consecutive Active Days
WITH numbered AS (
    SELECT user_id,
           activity_date,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY activity_date) AS rn
    FROM user_activity
),
grouped AS (
    SELECT user_id,
           activity_date,
           DATE_SUB(activity_date, INTERVAL rn DAY) AS grp_key
    FROM numbered
)
SELECT user_id
FROM grouped
GROUP BY user_id, grp_key
HAVING COUNT(*) >= 3;

🧩 Q2. Find Longest Streak per User
WITH numbered AS (
    SELECT user_id,
           activity_date,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY activity_date) AS rn
    FROM user_activity
),
grouped AS (
    SELECT user_id,
           DATE_SUB(activity_date, INTERVAL rn DAY) AS grp_key
    FROM numbered
)
SELECT user_id, MAX(COUNT(*)) AS longest_streak
FROM grouped
GROUP BY user_id, grp_key;

🧩 Q3. Calculate Monthly Retention Rate
WITH user_month AS (
  SELECT user_id,
         DATE_TRUNC('month', activity_date) AS month_active
  FROM user_activity
  GROUP BY user_id, month_active
),
cohort AS (
  SELECT user_id, MIN(month_active) AS signup_month FROM user_month GROUP BY user_id
)
SELECT c.signup_month,
       m.month_active,
       COUNT(DISTINCT m.user_id) AS retained_users
FROM cohort c
JOIN user_month m ON c.user_id = m.user_id
GROUP BY c.signup_month, m.month_active
ORDER BY c.signup_month, m.month_active;

🍎 TOPIC 8: DATA MODELING & OPTIMIZATION (Conceptual)
🧱 Schemas

fact_sales(region_id, product_id, customer_id, revenue, sale_date)

dim_product(product_id, category, brand)

dim_customer(customer_id, region_id, age_group)

🧩 Q1. Star Schema Example Query
SELECT d.region_id, p.category, SUM(f.revenue) AS total_revenue
FROM fact_sales f
JOIN dim_product p ON f.product_id = p.product_id
JOIN dim_customer d ON f.customer_id = d.customer_id
GROUP BY d.region_id, p.category;

🧩 Q2. Partitioning for Query Speed
-- Example: Snowflake or BigQuery
CREATE TABLE fact_sales PARTITION BY sale_date CLUSTER BY region_id;

🧩 Q3. Compare OLTP vs OLAP
Feature	OLTP	OLAP
Purpose	Transactional	Analytical
Data Volume	Small & frequent	Large & historical
Schema	Normalized	Star/Snowflake
Examples	MySQL, Postgres	Snowflake, BigQuery
🧩 Q4. Query Optimization Example
EXPLAIN SELECT * FROM fact_sales WHERE region_id = 10;


✅ Check for index usage, pruning, and partition filtering.