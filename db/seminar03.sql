select darkstore_id,
       count(*)          as cnt,
       max(delivered_at) as last_order
from orders
group by darkstore_id
order by darkstore_id;

select orders.customer_id
from orders
group by orders.customer_id
having count(*) = 2;

-- моя версия
select (select count(*) from orders)                              as cnt_all,
       (select count(*) from orders where courier_id is not null) as cnt_with,
       (select count(*) from orders where courier_id is null)     as cnt_without;

-- версия с семинара
select count(*)                            as cnt_all,
       count(orders.courier_id)            as cnt_with_courier,
       count(*) - count(orders.courier_id) as cnt_without_courier
from orders;


select orders.status,
       extract(month from created_at) as mon,
       count(*)                       as cnt
from orders
group by status, mon
order by status, mon;

select darkstore_id,
       count(orders)                                                     as orders_cnt,
       count(orders.delivered_at)                                        as delivered_cnt_at,
       count(orders) filter ( where status = 'delivered' )               as delivered_cnt,
       count(orders) filter ( where status = 'cancelled' )               as cancelled_cnt,
       round(avg(total_amount) filter ( where status = 'delivered' ), 2) as avg_delivered
from orders
group by darkstore_id
order by darkstore_id;

select order_item_id,
       name,
       brand,
       qty_ordered,
       price
from order_item
         join product on order_item.sku_id = product.sku_id and order_item.order_id = 34
order by order_item_id;

select darkstore.darkstore_id
from darkstore
where darkstore_id not in (select darkstore_id
                           from orders
                           group by darkstore_id
                           having count(*) > 0);

select darkstore.darkstore_id,
       darkstore.name
from orders
         right join darkstore on orders.darkstore_id = darkstore.darkstore_id
group by darkstore.darkstore_id
having count(orders) = 0;

select customer.customer_id,
       count(orders)
from customer
         left join orders on customer.customer_id = orders.customer_id and orders.created_at >= '1 August 2026' and
                             orders.created_at < '1 September 2026'
where customer.customer_id >= 20
  and customer.customer_id <= 25
group by customer.customer_id
order by customer.customer_id;

select sku_id
from product
except
select order_item.sku_id
from order_item
order by sku_id;

select city.name,
       m.month_title,
       count(o.order_id) as cnt
from city
         cross join (select extract(month from d)::int as month_num,
                            to_char(d, 'Month')        as month_title,
                            extract(year from d)::int  as year_num
                     from generate_series(
                                  '2024-07-01'::date,
                                  '2024-08-01'::date,
                                  '1 month'::interval
                          ) as d) as m
         left join darkstore d on city.city_id = d.city_id
         left join orders o on d.darkstore_id = o.darkstore_id
    and extract(month from created_at) = m.month_num
group by city.name, m.month_num, m.month_title
order by city.name, m.month_num;

explain analyze
select 
    d.darkstore_id as "ID даркстора",
    c.name as "город",
    count(distinct o) as "число заказов",
    count(distinct oi.sku_id) as "число различных товаров",
    round(sum(oi.qty_collected * oi.price), 2) as выручка,
    round(sum(o.total_amount), 2) as "выручка полная"
from darkstore d
         left join db_vzhukh.orders o on d.darkstore_id = o.darkstore_id
         left join db_vzhukh.order_item oi on o.order_id = oi.order_id
         left join db_vzhukh.city c on c.city_id = d.city_id
group by d.darkstore_id, c.name
having count(distinct o) > 5
order by выручка;

