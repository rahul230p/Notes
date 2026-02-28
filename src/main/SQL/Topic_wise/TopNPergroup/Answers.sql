
Q1)

select rnk.city, rnk.item_name from
(select t.city, t.item_name, rank() over (partition by t.city order by t.total_cnt desc) as rnk from
(select o.city, oi.item_name
count(order_id) as total_cnt
from fact_orders o join fact_order_items oi on o.order_id = oi.order_id
group by o.city, oi.item_name
) t
)x
where x.rnk=1


























Q2)
select rank.city, rank.customer_id from
(
select t.city, t.customer_id , row_number() over (partition by t.city order by t.total_orders desc) as rnk from
(select city,customer_id, count(order_id) as total_orders
from fact_orders
group by city, customer_id
)t
)rank
where rnk < 3


Q3)
select rnk.city, rnk.item_id from
(select t.city, t.item_id, rank() over (partition by t.city order by t.total_item_cost desc) as ranked from
(select o.city, oi.item_id, sum(oi.quantity * oi.item_price) as total_item_cost
from fact_orders o join fact_order_items oi on o.order_id = oi.order_id
group by o.city, oi.item_id
) t
)rnk
where rnk.ranked = 1

select cte2.city_id, cte2.date_id from
(
select cte.city_id, cte.date_id, row_number() over (partition by city_id, date_id order by total_items desc) as rnk from
(select oi.city_id ,t.date_id, count(item_id) as total_items
from orders o join order_items oi on o.order_id = oi.order_id
join city c on o.city_id = c.city_id
join date t on o.date_id = t.date_id
group by city_id,t.date_id
)cte
) cte2
where rnk<=3














