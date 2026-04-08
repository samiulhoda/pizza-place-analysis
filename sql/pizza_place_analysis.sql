CREATE DATABASE pizza_db;
USE pizza_db;

-- show tables
show tables;

-- describing the tables
describe order_details;
describe orders;
describe pizza_types;
describe pizzas;

-- Check row counts (expected numbers)
select count(*) from orders;        -- expect ~21,350
select count(*) from order_details; -- expect ~48,620
select count(*) from pizzas;        -- expect ~96
select count(*) from pizza_types;   -- expect ~32

-- orders table: order_id is the PK
alter table orders
modify column order_id int not null,
add primary key (order_id);

-- order_details table: order_details_id is the PK
alter table order_details
modify column order_details_id int not null,
add primary key (order_details_id);

-- pizza_types table: pizza_type_id is the PK
alter table pizza_types
modify column pizza_type_id varchar(50) not null,
add primary key (pizza_type_id);

-- pizzas table: pizza_id is the PK (it's a text value like "bbq_ckn_s")
alter table pizzas
modify column pizza_id varchar(50) not null,
add primary key (pizza_id);

-- SETTING FOREIGN KEYS
-- orders ──────────── order_details   (via order_id)
-- pizzas ──────────── order_details   (via pizza_id)
-- pizza_types ─────── pizzas          (via pizza_type_id)

-- order_details.order_id → orders.order_id
alter table order_details
add constraint fk_order
foreign key (order_id) references orders(order_id);

-- datatype of column in both the tables should be same
alter table order_details
modify column pizza_id varchar(50);

-- order_details.pizza_id → pizzas.pizza_id
alter table order_details
add constraint fk_pizza
foreign key (pizza_id) references pizzas(pizza_id);

-- pizzas.pizza_type_id → pizza_types.pizza_type_id

-- datatype of column in both the tables should be same
alter table pizzas
modify column pizza_type_id varchar(50);

alter table pizzas
add constraint fk_pizzatype
foreign key (pizza_type_id) references pizza_types(pizza_type_id);

-- FIX datatypes in tables
-- converting date column from text to date in orders table
alter table orders modify column date DATE;

-- converting time column from text to time in orders table
alter table orders modify column time TIME;

-- Fix price in pizzas to DECIMAL for accurate revenue calculations
alter table pizzas modify column price decimal(10,2);


-- Quick Data Quality Check
-- Checking for any nULL values in critical columns
select 
sum(case when order_id is null then 1 else 0 end) as null_orders,
sum(case when date is null then 1 else 0 end) as null_dates,
sum(case when time is null then 1 else 0 end) as null_times
from orders;

select 
sum(case when pizza_id is null then 1 else 0 end) as null_pizza_id,
sum(case when quantity is null then 1 else 0 end) as null_qty
from order_details;

-- date range is the data
select min(date), max(date) from orders;

-- different pizza sizes
select distinct size from pizzas;

-- different pizza categories
select distinct category from pizza_types;


-- testing whether all the relationships work correctly
select
  o.order_id,
  o.date,
  pt.category,
  pt.name as pizza_name,
  p.size,
  p.price,
  od.quantity,
  round(p.price * od.quantity, 2) AS line_total
from orders o
join order_details od  on o.order_id = od.order_id
join pizzas p on od.pizza_id = p.pizza_id
join pizza_types pt on p.pizza_type_id = pt.pizza_type_id
limit 10;


-- 1)Business KPIs ---> total revenue, total orders, total pizzas sold, avg order value
select
count(distinct o.order_id) as total_orders,
round(sum(od.quantity * p.price),2) as total_revenue,
sum(od.quantity) as total_pizzas_sold,
round(sum(od.quantity * p.price)/(count(distinct o.order_id)),2) as avg_order_value
from orders o join order_details od on o.order_id = od.order_id
join pizzas p on od.pizza_id = p.pizza_id;


-- 2)Revenue by Pizza Category
select
pt.category as pizza_category,
count(distinct o.order_id) as total_orders,
sum(od.quantity) as total_pizzas_sold,
round(sum(od.quantity * p.price),2) as total_revenue
from orders o join order_details od on o.order_id = od.order_id
join pizzas p on od.pizza_id = p.pizza_id
join pizza_types pt on p.pizza_type_id = pt.pizza_type_id
group by pt.category
order by total_revenue desc;

-- 3)Top 5 Best-Selling Pizzas by Revenue
select
pt.name as pizza_name,
pt.category,
sum(od.quantity) as total_pizzas_sold,
round(sum(od.quantity * p.price),2) as total_revenue
from orders o join order_details od on o.order_id = od.order_id
join pizzas p on od.pizza_id = p.pizza_id
join pizza_types pt on p.pizza_type_id = pt.pizza_type_id
group by pt.name, pt.category
order by total_revenue desc
limit 5;

-- 4)Peak Hour Analysis (When Are Orders Highest?)

select
hour(o.time) as order_hour,
count(distinct o.order_id) as total_orders,
sum(od.quantity) as total_pizzas_sold
from orders o join order_details od on o.order_id = od.order_id
join pizzas p on od.pizza_id = p.pizza_id
join pizza_types pt on p.pizza_type_id = pt.pizza_type_id
group by order_hour
order by total_orders desc;

-- 5)Month-over-Month Revenue Growth

with monthly_revenue as (
select
month(o.date) as month_,
monthname(o.date) as monthname_,
round(sum(od.quantity * p.price),2) as revenue
from orders o join order_details od on o.order_id = od.order_id
join pizzas p on od.pizza_id = p.pizza_id
group by month_,monthname_
order by month_
)
select month_, monthname_,
revenue,
lag(revenue) over(order by month_) as prev_revenue, 
round((revenue - lag(revenue) over(order by month_))*100/(lag(revenue) over(order by month_)),2) as MoM_growth_pct
from monthly_revenue
order by month_;


-- 6)Category % Contribution to Total Revenue
with cat_revenue as(
select
pt.category as pizza_category,
round(sum(od.quantity * p.price),2) as category_revenue
from orders o join order_details od on o.order_id = od.order_id
join pizzas p on od.pizza_id = p.pizza_id
join pizza_types pt on p.pizza_type_id = pt.pizza_type_id
group by pt.category
order by category_revenue desc
)
select 
pizza_category, category_revenue,
round(category_revenue*100/sum(category_revenue) over(),2) as pct_of_revenue,
round(sum(category_revenue) over (order by category_revenue desc rows between unbounded preceding and current row),2) as running_total
from cat_revenue;




