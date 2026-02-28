🍎 Topic 3: Filtering & Subqueries — Complete Set with Schemas

We’ll go from 🟢 basics → 🔵 Apple-style analytical problems.
Each question includes a realistic schema and explanation.

🟢 Q1. Customers Who Have Placed Orders (IN)
🧱 Table Schema

customers

customer_id	customer_name
1	Alice
2	Bob
3	Charlie

orders

order_id	customer_id	amount
101	1	100
102	2	200
🎯 Question

Find all customers who have placed at least one order.

✅ Query
SELECT customer_name
FROM customers
WHERE customer_id IN (
    SELECT DISTINCT customer_id FROM orders
);


✅ Simple, readable, and works fine for small/medium datasets.

🟢 Q2. Customers Without Any Orders (NOT IN)
🎯 Question

Find all customers who have not placed any order.

✅ Query
SELECT customer_name
FROM customers
WHERE customer_id NOT IN (
    SELECT DISTINCT customer_id FROM orders
);


⚠️ Caution: NOT IN fails if subquery returns NULL.
Apple interviewers may ask this!
Fix it with NOT EXISTS:

SELECT c.customer_name
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.customer_id
);


✅ EXISTS is null-safe — always prefer it.

🟢 Q3. Customers Whose Total Spend > Average Spend (Aggregate Subquery)
🧱 Table Schema

orders

customer_id	amount
1	100
1	200
2	300
3	50
🎯 Question

Find customers whose total spend is greater than the average spend of all customers.

✅ Query
SELECT customer_id, SUM(amount) AS total_spend
FROM orders
GROUP BY customer_id
HAVING SUM(amount) > (
    SELECT AVG(total_amount)
    FROM (
        SELECT SUM(amount) AS total_amount
        FROM orders
        GROUP BY customer_id
    ) t
);


✅ Nested subquery inside HAVING — a very typical Apple-style question.

🟠 Q4. Find Products That Have Never Been Ordered (NOT EXISTS)
🧱 Table Schema

products

product_id	product_name
10	iPhone
11	iPad
12	Watch

orders

order_id	product_id
1	10
2	11
🎯 Question

Find all products that have never been ordered.

✅ Query
SELECT p.product_name
FROM products p
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.product_id = p.product_id
);


✅ Efficient, scalable, and clear — Apple expects this style.

🟠 Q5. Customers Whose Orders Exceed Their Own Average (Correlated Subquery)
🧱 Table Schema

orders

order_id	customer_id	amount
1	101	200
2	101	100
3	102	500
4	102	300
🎯 Question

Find all orders where the amount is greater than that customer’s average order amount.

✅ Query
SELECT o.order_id, o.customer_id, o.amount
FROM orders o
WHERE o.amount > (
    SELECT AVG(o2.amount)
    FROM orders o2
    WHERE o2.customer_id = o.customer_id
);


✅ Correlated subquery (depends on outer query)
✅ Common in Apple interviews to test row-by-row filtering logic.

🔵 Q6. Find Customers Who Ordered from Multiple Categories (Subquery in HAVING)
🧱 Table Schema

orders

order_id	customer_id	product_id
1	101	10
2	101	11
3	102	10

products

product_id	category
10	Electronics
11	Furniture
🎯 Question

Find customers who ordered from more than one category.

✅ Query
SELECT o.customer_id
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY o.customer_id
HAVING COUNT(DISTINCT p.category) > 1;


✅ Often phrased as:

“Find multi-category buyers”
Very Apple-style business question.

🔵 Q7. Find Regions Contributing More Than 30% to Total Revenue (CTE + Subquery)
🧱 Table Schema

sales

region	revenue
East	3000
West	2000
North	1000
🎯 Question

Find all regions contributing more than 30% to total revenue.

✅ Query
WITH region_sales AS (
    SELECT region, SUM(revenue) AS total_revenue_per_region
    FROM sales
    GROUP BY region
)
SELECT region, total_revenue_per_region
FROM region_sales
WHERE total_revenue_per_region > (
    SELECT 0.3 * SUM(total_revenue_per_region) FROM region_sales
);


✅ CTE + subquery in WHERE → classic Apple analytical pattern.

🔵 Q8. Top 2 Products per Category (Subquery + Window Function)
🧱 Table Schema

products

product_id	category	revenue
1	Electronics	1000
2	Electronics	900
3	Electronics	700
4	Furniture	800
5	Furniture	750
🎯 Question

Find the top 2 products by revenue within each category.

✅ Query
SELECT *
FROM (
    SELECT *,
           RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rnk
    FROM products
) ranked
WHERE rnk <= 2;


✅ Often used as a follow-up to a subquery question at Apple.

🧠 Apple Interviewer Focus Areas
Concept	Example
IN vs EXISTS	When to use which — and why EXISTS is faster
Correlated subqueries	WHERE amount > (SELECT AVG(...) WHERE ...)
Nested aggregations	Compare to averages, medians
Filtering post-aggregation	HAVING with subqueries
Window + subquery mix	Top-N within group