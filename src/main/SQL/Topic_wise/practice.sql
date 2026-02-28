1Distinct Flight Routes

Schema:
flights(src STRING, dest STRING)
Q: Find distinct flight routes ignoring direction (A→B same as B→A).

select

2Nth Highest Salary

Schema:
employees(emp_id INT, emp_name STRING, salary INT)
Q: Find the 3rd highest salary in the company.

3Consecutive Login Days

Schema:
logins(user_id INT, login_date DATE)
Q: Find users who logged in for 3 or more consecutive days.

4Cumulative Revenue

Schema:
orders(order_id INT, customer_id INT, order_date DATE, revenue INT)
Q: For each customer, calculate cumulative revenue ordered by date.

5 Top 3 Products by Revenue per Region

Schema:
sales(region STRING, product STRING, revenue INT)
Q: Find top 3 products with the highest revenue in each region.

6Customers with No Orders

Schema:
customers(customer_id INT, name STRING)
orders(order_id INT, customer_id INT, amount INT)
Q: Find all customers who have never placed an order.

7Duplicate Emails

Schema:
employees(emp_id INT, emp_name STRING, email STRING)
Q: Find all duplicate email IDs and their counts.

8Average Order Value per Day

Schema:
orders(order_id INT, order_date DATE, total_amount DECIMAL)
Q: Find the average order value per day.

97-Day Moving Average of Revenue

Schema:
daily_sales(sale_date DATE, revenue INT)
Q: Calculate 7-day moving average of revenue.

🔟 Highest Spending Customer per Month

Schema:
transactions(customer_id INT, amount DECIMAL, txn_date DATE)
Q: Find the highest spending customer in each month.

11Gender Ratio by Department

Schema:
employees(emp_id INT, department STRING, gender CHAR(1))
Q: Calculate male–female count and percentage per department.

12Second Order Date

Schema:
orders(order_id INT, customer_id INT, order_date DATE)
Q: For each customer, find the second order date.

13Join Three Tables

Schema:
orders(order_id INT, customer_id INT, product_id INT, amount INT)
customers(customer_id INT, name STRING)
products(product_id INT, category STRING)
Q: Find the total spend per customer per category.

14Missing Sequence IDs

Schema:
sequence(id INT)
Q: Find all missing IDs from the numeric sequence.

15Most Recent Order per Customer

Schema:
orders(order_id INT, customer_id INT, order_date DATE, total DECIMAL)
Q: Find each customer’s most recent order and amount.

16Retention

Schema:
user_activity(user_id INT, activity_date DATE)
Q: Find all users active in consecutive months (retained users).

17Category with Maximum Products

Schema:
products(product_id INT, category STRING)
Q: Find the category having the maximum number of products.

18Percentage Contribution per Region

Schema:
sales(region STRING, revenue INT)
Q: Calculate each region’s % contribution to total sales.

19Orders Growth Comparison

Schema:
orders(order_date DATE, order_id INT)
Q: Compare order count month-over-month and show growth %.

20Top 2 Salaries per Department

Schema:
employees(emp_id INT, emp_name STRING, department STRING, salary INT)
Q: Find top 2 salaries in each department.