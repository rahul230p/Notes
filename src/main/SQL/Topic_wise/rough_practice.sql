select region, sum(revenue) as total_revenue
from sales
group by region


select count(*) as cnt_per_customer, customer_id
from orders
group by customer_id



select avg(revenue) as avg_revenue_per_customer, product
from sales
group by product


Level 2

select region, sum(revenue) as total_revenue
from sales
group by region
having total_revenue > 5000


select product
from sales
group by product
having count(product)>2

select c.customer_id, sum(o.amount) as total_spend_per_customer
from customers c
left join orders o on c.customer_id = o.customer_id
group by c.customer_id


select region, category, sum(revenue) as revenue_per_region_per_category
from sales
group by region, category

select
 sum(case when category ilike 'electronics' then revenue else 0 end)  as electronics_revenue,
 sum(case when category ilike 'furniture' then revenue else 0 end)  as furniture_revenue,
from sales
group by region


select region,
 count(case when is_active = 1 then 1 else 0 end) as active_customers,
 count(case when is_active = 0 then 1 else 0 end) as inactive_customers,
 from customers
 group by region



 select product,
ROUND(100* sum(revenue)/ sum(sum(revenue)) over (), 2) as percent_revenue
 group by product


select region, avg(total_revenue) as total_revenue from
(
select customer_id, region, sum(revenue) as total_revenue
from sales
group by customer_id, region
)
group by region

select sum(revenue) as total_revenue ,
 sum(sum(sales)) over () as total_revenue
from
sales
















