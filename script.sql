use dominos;
select * from customers;
select * from order_details;
select * from orders;
select * from pizza_types;
select * from pizzas;

-- cleaning Dominos / store / ecommerce Database

-- step 1 :- To check for duplicate values
-- step 2 :- check for null values
-- step 3 :- Treating null vlaues
-- step 4 :- Handling negative values
-- step 5 :- Fixing inconsistent date fromat & invalid dates
-- step 6 :- checking the datatype
---------------------------------------------------------------------------------------------------

-- step 1 :- To check for duplicate values

WITH CTE AS (
SELECT *,
	ROW_NUMBER() OVER(PARTITION BY lower(email) ) row_num
FROM customers
)
select * FROM CTE 
WHERE row_num >=1;

SET SQL_SAFE_UPDATES = 0;




-----------------------------------------------------------------------------------
-- step 2 :- check for null values

select * from customers where phone is null;
-----------------------------------------------------------------------------------------

-- step 4 :- Handling negative values

select * from order_details  where quantity <1 ;
-- if some value exist use abs to treat negative values

-------------------------------------------------------------------------------------------------

-- cheking for invalid excel
SELECT * FROM customers
WHERE email  LIKE '%@%';

----------------------------------------------------------------------------------------------------
-- step 6 :- checking the datatype
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME='customers';

------------------------------------------------------------------------------------------------------
-- 1:- ORDERS VOLUME ANALYSIS QUERIES 
--------------------------------------------------------------------------------------------------------

/*
we are trying to understand our order value in detail so we measure store performance and benchmark growth.
Instead of just knowing the total number of unique order
*/
-----------------------------------------------------------------------------------------------------------------------
-- What is the total Number of unique order placed so far ?

select count(*) from orders;
select count(distinct(order_id)) from orders;

----------------------------------------------------------------------------------------------------------------------------

-- How has this order volume changed month-over-month year-over-year?

with monthly_orders as (
select date_format(order_date,'%Y-%m-01') as months ,
 count(order_id)  order_count 
from orders
 group by months
)
select months , order_count ,
lag(order_count) over (order by months) as pev_months,
(order_count - lag(order_count) over (order by months)) as order_diff,
round(100.0 *(order_count - lag(order_count) over (order by months))/ nullif(lag(order_count) over(order by months),0),2) mom_growth_pct
from monthly_orders
order by months;

with yearly_orders as (
select date_format(order_date,'%Y-01-01') as years,
count(order_id) order_count
from orders
group by years
)
select years,order_count,
lag(order_count) over (order by years) as pev_count,
round(100.0*(order_count - lag(order_count) over (order by years))/nullif(lag(order_count) over (order by years),0),2) yoy_growth_pct
from yearly_orders
order by years;

-----------------------------------------------------------------------------------------------------------------------------------------

-- can we identify peak and off-peak ordering days ?

with days_order as (
select date_format(order_date,'%Y-%m-%d') as days,
count(order_id) order_count
from orders
group by days
)
select days, order_count
from days_order
order by order_count desc;

with days_orders as(
select DAYNAME(order_date) AS weekday,
COUNT(order_id) AS orders
FROM orders
GROUP BY weekday
)
select weekday,orders,
case
    when orders= (select max(orders) from days_orders) then 'Peak Day'
    when orders=(select min(orders) from days_orders ) then 'off-Peak Day'
    else 'Normal Day'
end as Trends
from days_orders
order by orders desc;

--------------------------------------------------------------------------------------------------------------------------------------

-- How do order volumes vary by day of the weak (e.g weekend vs weekdays)?

with days_order as (
select dayname(order_date) as days_name,
 count(order_id) order_count
from orders
group by days_name
)
select days_name,order_count,
lag(order_count) over (order by order_count) as pev_days_orders,
round(100.0*(order_count - lag(order_count) over (order by order_count))/ nullif(lag(order_count) over (order by order_count),0),2) dod_perct
from days_order
order by order_count;

--------------------------------------------------------------------------------------------------------------------------------------

-- what is the avg number of order per cusotmer?

select * from orders;

WITH orders_per_customer AS (
    SELECT o.custid, COUNT(*) AS total_orders
    FROM orders o
    GROUP BY o.custid
)
SELECT AVG(total_orders) AS avg_orders_per_customer
FROM orders_per_customer;

------------------------------------------------------------------------------------------------------------------------------------------

-- who are our top repeat customer driving the order volumnes?

select c.custid ,c.first_name,c.last_name , count(distinct o.order_id) as frequency 
from orders o join customers c
on o.custid=c.custid
group by c.custid,c.first_name,c.last_name
order by  frequency desc;


-----------------------------------------------------------------------------------------------------------------------------------------
-- can you also project the expercted order growth trend bases on historical data?
-- cumulative trends

SELECT order_date,daily_orders,
SUM(daily_orders) OVER (ORDER BY order_date) AS cumulative_orders
FROM (
SELECT  order_date, COUNT(DISTINCT order_id) AS daily_orders
FROM orders
GROUP BY order_date
) AS t
ORDER BY order_date;


----------------------------------------------------------------------------------------------------------------------------------------
-- Total Revenue from Pizza sales
-----------------------------------------------------------------------------------------------------------------------------------------
/*
we need to report monthly revenue to management.
can you calculate the total revenue generated from all pizza sales.
considering price*quantity from each orders?

Analysis Task :- join order_details with pizza and sum (prize*quantity).
*/
 
select * from order_details;
select * from pizzas;
select * from orders;


select date_format(o.order_date,'%Y-%m-01') as months , 
round(sum(p.price*od.quantity),2) as Total_revenue from order_details od join pizzas p 
on od.pizza_id=p.pizza_id
join orders o on od.order_id=o.order_id
group by months
order by months;

---------------------------------------------------------------------------------------------------------------------------------
-- Highest-Priced Pizza
------------------------------------------------------------------------------------------------------------------------------------
/*
our premium pizza must be correctly priced . can you find out which pizza has the
highest price on our menu and config its category and size.
*/

select * from pizzas;
select * from pizza_types;

select p.pizza_id,pt.name,
pt.category,p.size,
concat('$',p.price) from pizzas p join pizza_types pt
on p.pizza_type_id=pt.pizza_type_id
order by p.price desc 
limit 1;

----------------------------------------------------------------------------------------------------------------------------------
-- MOST COMMON PIZZA SIZE ORDERED
-------------------------------------------------------------------------------------------------------------------------------------------
/*
To optimize packaging and row material supply. i need to know which
pizza size ( S , M , L , XL , XXL ) is orderes the most
*/
select * from pizzas;
select * from pizza_types;
select * from order_details;

select p.size ,count(*) total_order from order_details od join pizzas p
on od.pizza_id = p.pizza_id 
group by p.size
order by total_order desc
limit 1;

--------------------------------------------------------------------------------------------------------------------------------------
-- TOP 5 MOST ORDERED PIZZA TYPES
------------------------------------------------------------------------------------------------------------------------------------
/*
we want to promote our top-selling pizzas.can you provide the top 5 pizza
types orders by quanitity,along with the exact number of unit sold?
*/

select p.pizza_id,pt.name,pt.category ,sum(od.quantity) total_quantity from order_details od join pizzas p
on od.pizza_id = p.pizza_id 
join pizza_types pt on p.pizza_type_id=pt.pizza_type_id
group by p.pizza_id
order by total_quantity desc
limit 5;

---------------------------------------------------------------------------------------------------------------------------------
-- TOTAL QUANTITY BY PIZZA CATEGORY
-------------------------------------------------------------------------------------------------------------------------------------
/*
we run promothin bases on category (classic,veggie,supreme,chicken ect)
can you calculate the total number of pizza sold in each category 
so we can plan targeted compaigns?
*/
select * from pizzas;
select * from pizza_types;
select * from order_details;

select pt.category,sum(od.quantity) total_order
from order_details od join pizzas p on od.pizza_id=p.pizza_id
join pizza_types pt on p.pizza_type_id=pt.pizza_type_id
group by pt.category
order by total_order desc;

----------------------------------------------------------------------------------------------------------------------------------------
-- ORDER BY HOUR OF THE DAY
----------------------------------------------------------------------------------------------------------------------------------------
/*
when are customer ordering the most? do they prefer lunch(12-2 PM).
evening(6-9 PM), or late-night? please give me a distribution 
of orders by hours of the day so we can adjust stafffing.
*/
select * from orders;

SELECT DATE_FORMAT(STR_TO_DATE(order_time, '%H:%i:%s'), '%H:00')   hour_slot,
COUNT(*) AS total_orders
FROM orders
GROUP BY hour_slot
ORDER BY hour_slot;

-----------------------------------------------------------------------------------------------------------------------------------------
-- CATEGORY-WISE PIZZA DISTRIBUTION
-----------------------------------------------------------------------------------------------------------------------------------------
/*
Which categories dominate our menu sales?
can you prepare a breakdown of orders per category with percentage share?
*/
with revenue as (
select sum(od.quantity*p.price) as total_revenue from order_details od join pizzas p 
on od.pizza_id=p.pizza_id
)
select pt.category,sum(od.quantity) total_quantity,
round(sum(od.quantity*p.price),2) cate_total_revenue ,
concat(round((sum(od.quantity*p.price)/max(r.total_revenue))*100,2),'%') as percenatge_share
from order_details od join pizzas p 
on od.pizza_id=p.pizza_id
join pizza_types pt on p.pizza_type_id=pt.pizza_type_id
CROSS JOIN revenue r
group by pt.category
order by cate_total_revenue desc;

----------------------------------------------------------------------------------------------------------------------------------------
-- AVERAGE PIZZAS ORDERES PER DAY
-----------------------------------------------------------------------------------------------------------------------------------------
/*
I want to see if our daily demand is consistent.
can you group orders by date and tell me the averge number(quantity) of pizzas orderes per day?
*/

select round(avg(daily_total),0) as avg_pizzas_per_day
from ( select o.order_date,sum(od.quantity) as daily_total
from order_details od join orders o on od.order_id=o.order_id
group by o.order_date
)t;

-------------------------------------------------------------------------------------------------------------------------------------
-- TOP 3 PIZZAS BY REVENUE
--------------------------------------------------------------------------------------------------------------------------------------
/*
we need to know which pizzas are biggest revnue deriver
please provide the top 3 pizzas by revenue generated
*/
WITH  pizza_revenue as(
select pt.name,round(sum(od.quantity*p.price),0) total_revenue ,
rank() over (order by round(sum(od.quantity*p.price),0) desc) as rnk
from order_details od join pizzas p on od.pizza_id=p.pizza_id
join pizza_types pt on p.pizza_type_id=pt.pizza_type_id
group by pt.name
)
select name,total_revenue
from pizza_revenue
where rnk <=3;

-- revenue of top 3 pizza by size also
select od.pizza_id,round(sum(od.quantity*p.price),0) total_revenue from order_details od join pizzas p 
on od.pizza_id=p.pizza_id
join pizza_types pt on p.pizza_type_id=pt.pizza_type_id
group by od.pizza_id
order by total_revenue desc
limit 3;

---------------------------------------------------------------------------------------------------------------------------------------
-- REVENUE CONTRIBUTION PER PIZZA
-----------------------------------------------------------------------------------------------------------------------------------------
/*
for our revenue mix analysis , I need to know what percentage of 
total revenue each pizza contribute.
This will show items carry the business.
*/
-- METHOD 1
with total_revenue as (
select round(sum(od.quantity*p.price),0) total_revenue 
from order_details od join pizzas p on od.pizza_id=p.pizza_id
)
select pt.name,round(sum(od.quantity*p.price),0) pizza_revenue, 
concat(round((sum(od.quantity*p.price)/max(total_revenue))*100,2),'%') as percentage_conti
from order_details od join pizzas p on od.pizza_id=p.pizza_id
join pizza_types pt on p.pizza_type_id=pt.pizza_type_id
cross join total_revenue
group by pt.name
order by percentage_conti desc;

-- METHOD 2
select pt.name,round(sum(od.quantity*p.price),0) pizza_revenue,
concat(round(100*(sum(od.quantity*p.price)/sum(sum(od.quantity*p.price))over()),2),'%') as pct_contribution
from order_details od join pizzas p on od.pizza_id=p.pizza_id
join pizza_types pt on p.pizza_type_id=pt.pizza_type_id
group by pt.name
order by pct_contribution desc;

------------------------------------------------------------------------------------------------------------------------------------------
-- CUMULATIVE REVENUE OVER TIME
-----------------------------------------------------------------------------------------------------------------------------------------
/*
we want to see how oue cumulative revenue has grow month by month
since launch. can you prepare a cunulative revenue trend line?
*/

select order_date,daily_revenue,
sum(daily_revenue) over (order by order_date) as culumative_revenue
from
(
select o.order_date,
round(sum(od.quantity*p.price),0) as daily_revenue
from orders o join order_details od on o.order_id=od.order_id
join pizzas p on od.pizza_id=p.pizza_id
group by o.order_date
) t;

----------------------------------------------------------------------------------------------------------------------------------------
-- TOP 3 PIZZAS BY CATEGORY (REVENUE_BASED)
--------------------------------------------------------------------------------------------------------------------------------------
/*
 within each pizza category,which 3 pizzas bring the most revenue?
This will help us decide which pizzas to promote or expand. 
*/
with cat_rank as (
select pt.category,pt.name,sum(p.price*od.quantity) as revenue,
rank() over (partition by pt.category order by sum(p.price*od.quantity) desc )as rnk
from order_details od join pizzas p on od.pizza_id=p.pizza_id
join pizza_types pt on p.pizza_type_id=pt.pizza_type_id
group by pt.category,pt.name
)
select category,name,revenue
from cat_rank
where rnk <=3;


----------------------------------------------------------------------------------------------------------------------------------------
-- TOP 10 CUSTOMER BY SPENDING
-----------------------------------------------------------------------------------------------------------------------------------------
/* 
who are our top 10 customers based on total spend?
we want to reward them with loyality offer. 
*/
select * from customers;
select * from orders;
select * from order_details;
select * from pizzas;

select c.custid,c.first_name,c.last_name ,round(sum(od.quantity*p.price),2) total_spend
from customers c join orders o on c.custid=o.custid
join order_details od on o.order_id=od.order_id
join pizzas p on od.pizza_id=p.pizza_id
group by c.custid,c.first_name,c.last_name 
order by total_spend desc
limit 10;

----------------------------------------------------------------------------------------------------------------------------------------
-- ORDER BY WEEKDAYS
-----------------------------------------------------------------------------------------------------------------------------------------
/* 
which days of the week are bussiest for orders?
Do customers order more on weekends?
*/
select dayname(order_date) as Week_day ,
count(order_id) as count_order
from orders
group by week_day
order by count_order desc
;

------------------------------------------------------------------------------------------------------------------------------------------
-- AVG ORDER SIZE
-----------------------------------------------------------------------------------------------------------------------------------------
/*
 what the average number of pizzas per order?
this help us in planning inventory and staffing
*/

select round(avg(per_order_count),0) as order_size
from (
select od.order_id,sum(od.quantity) as per_order_count
from order_details od 
group by od.order_id
) t;

--------------------------------------------------------------------------------------------------------------------------------------
-- SEASONAL TRENDS
--------------------------------------------------------------------------------------------------------------------------------------
/*
Do we see peak sales in certain months or holidays?
This will help us manage seasona demand. 
*/
select month(order_date) months, count(*) as total_orders 
from orders
group by months
order by months;

--------------------------------------------------------------------------------------------------------------------------------------
-- REVENUE BY PIZZA SIZE
-------------------------------------------------------------------------------------------------------------------------------------
/*
what are revenue contribution of each pizza 
size(S,M,L,XL,XXL)
*/

select  p.size,round(sum(od.quantity*p.price),2) revenue
from order_details od join pizzas p on od.pizza_id=p.pizza_id
group by p.size
order by revenue desc;

---------------------------------------------------------------------------------------------------------------------------------------
-- CUSTOMER SEGMENTATION
---------------------------------------------------------------------------------------------------------------------------------------
/*
do our high-value customer prefer premium pizza or
regular pizza? we want to personalized marketing. 
*/
with cust_spend as(
select c.custid,sum(od.quantity*p.price) total_spend
from customers c join orders o on c.custid=o.custid
join order_details od on o.order_id=od.order_id
join pizzas p on od.pizza_id=p.pizza_id
group by c.custid
)
select
case 
when total_spend > 40000 then 'High-value'
else 'Regual'
end as segment,
count(*) as customer_count
from cust_spend 
group by segment;

---------------------------------------------------------------------------------------------------------------------------------------
-- REPEAT CUSTOMER RATE
---------------------------------------------------------------------------------------------------------------------------------------
/*
we want to measure customer loyality . can you calculate the percentage of repeat cy=ustomers (customer who place more than one order
versus ont-time buyers? this will help us design retention campaings. 
*/
select count(distinct custid)
from orders;

with cust_order as (
select custid,count(*) total_cust_count
from orders 
group by custid
)
select 
round(100.0*sum(case when total_cust_count>1 then  1 else 0 end )/count(*),2)as repeat_rate
from cust_order;














