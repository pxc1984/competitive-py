-- i_a_mamaev
-- a9-wLgwTJmw1mIxisjVSY1gckh8
select darkstore.darkstore_id             as "ID даркстора",
       count(orders)                      as "колво заказов",
       round(sum(orders.total_amount), 2) as "сумма"
from darkstore
         left outer join orders on darkstore.darkstore_id = orders.darkstore_id
group by 1
order by 1;

select distinct payment_card.customer_id
from payment_card
group by customer_id
having count(*) - count(deleted_at) > 1;

select distinct sku_id          as "айди продукта",
                max(valid_from) as "дата начала самой свежей цены"
from product_price
group by sku_id
having count(product_price) > 1;

select distinct employee.full_name,
                employee.role,
                count(orders),
                max(orders.assembled_at)
from employee
         left outer join orders on employee_id = picker_id
         left join darkstore on darkstore.darkstore_id = orders.darkstore_id
where darkstore.darkstore_id = 4
group by employee.employee_id, employee.full_name
order by employee.full_name;

select orders.customer_id
from orders
         left join db_vzhukh.darkstore d on d.darkstore_id = orders.darkstore_id
         left join db_vzhukh.city c on d.city_id = c.city_id
where c.city_id = 1
intersect
select orders.customer_id
from orders
         left join db_vzhukh.darkstore d on d.darkstore_id = orders.darkstore_id
         left join db_vzhukh.city c on d.city_id = c.city_id
where c.city_id = 2;

select
    e.full_name,
    count(orders)
from orders
left join db_vzhukh.employee e on e.employee_id = orders.courier_id
group by orders.courier_id, e.full_name
order by count(orders) desc, e.full_name;
