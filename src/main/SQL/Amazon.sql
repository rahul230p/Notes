Perfect. Based on the Amazon DE2 experiences you found, SQL is more likely than coding.

I would focus on these 10 SQL questions because they cover ~80% of Amazon DE interviews.

SQL Pattern 1: Top N Per Group
Question

Find top 3 products by sales in each category.

product_sales
-------------
product_id
category
sales
Solution
WITH ranked AS (
    SELECT *,
           DENSE_RANK() OVER(
               PARTITION BY category
               ORDER BY sales DESC
           ) rnk
    FROM product_sales
)
SELECT *
FROM ranked
WHERE rnk <= 3;
SQL Pattern 2: Deduplication
Question

Keep latest customer record.

customer
---------
customer_id
name
updated_ts
Solution
WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY customer_id
               ORDER BY updated_ts DESC
           ) rn
    FROM customer
)
SELECT *
FROM ranked
WHERE rn = 1;

Amazon loves this.

SQL Pattern 3: Running Total
Question

Running sales amount per customer.

Solution
SELECT
    customer_id,
    txn_date,
    amount,
    SUM(amount) OVER(
        PARTITION BY customer_id
        ORDER BY txn_date
    ) running_total
FROM transactions;
SQL Pattern 4: Second Highest Salary
Solution
WITH ranked AS (
    SELECT salary,
           DENSE_RANK() OVER(
               ORDER BY salary DESC
           ) rnk
    FROM employee
)
SELECT salary
FROM ranked
WHERE rnk = 2;
SQL Pattern 5: Sessionization

Very common for DE.

Question

Create new session if inactivity > 30 mins.

WITH cte AS (
    SELECT *,
           LAG(event_time) OVER(
               PARTITION BY user_id
               ORDER BY event_time
           ) prev_time
    FROM clicks
),
flagged AS (
    SELECT *,
           CASE
               WHEN TIMESTAMPDIFF(
                        MINUTE,
                        prev_time,
                        event_time
                    ) > 30
                    OR prev_time IS NULL
               THEN 1
               ELSE 0
           END session_start
    FROM cte
)
SELECT *,
       SUM(session_start) OVER(
           PARTITION BY user_id
           ORDER BY event_time
       ) session_id
FROM flagged;
SQL Pattern 6: Find Consecutive Days
Question

Users logged in 3 consecutive days.

Idea

Use:

LAG()

or

ROW_NUMBER()

gap-and-island pattern.

SQL Pattern 7: Day 1 Retention
Question

How many users came back next day?

SELECT
    COUNT(DISTINCT a.user_id)
FROM activity a
         JOIN activity b
              ON a.user_id = b.user_id
                  AND b.activity_date =
                      DATEADD(day,1,a.activity_date);
SQL Pattern 8: Highest Order Per Customer
Solution
WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY customer_id
               ORDER BY amount DESC
           ) rn
    FROM orders
)
SELECT *
FROM ranked
WHERE rn = 1;
SQL Pattern 9: Funnel Analysis

Example:

View Product
Add To Cart
Purchase

Count users reaching each stage.

Uses:

GROUP BY
COUNT(DISTINCT user_id)

and joins.

SQL Pattern 10: Moving Average
7-Day Moving Average
SELECT
    txn_date,
    AVG(amount) OVER(
        ORDER BY txn_date
        ROWS BETWEEN 6 PRECEDING
        AND CURRENT ROW
    ) moving_avg
FROM sales;
Amazon DE2 SQL Follow-ups

After every query, expect:

Why ROW_NUMBER?

vs

RANK()

vs

DENSE_RANK()
Difference
ROW_NUMBER
1 2 3 4

No ties.

RANK
1 1 3 4

Gap exists.

DENSE_RANK
1 1 2 3

No gap.

Mock Interview

Let's do this exactly like an Amazon interviewer.

Question 1

Table:

orders
------
order_id
customer_id
amount
order_date

Write a query to find:

Total amount spent by each customer.
Rank customers based on total spend.
Return only top 3 customers.

Write the SQL and explain your thought process. Dont worry about perfect syntax—think out loud as you would in the interview.



