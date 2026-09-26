drop table if exists i_a_mamaev.courier_shift;

create table if not exists i_a_mamaev.courier_shift
(
    shift_id      integer primary key,
    employee_id   integer     not null,
    darkstore_id  integer     not null,
    shift_date    date        not null,
    hours_planned numeric(8, 1)        default 8.0,
    orders_done   integer     not null default 0,
    vehicle       varchar(20) not null,
    is_closed     boolean     not null default false,

    constraint one_courier_shift_per_day
        unique (employee_id, shift_date),
    constraint check_hours_planned_positive
        check (hours_planned > 0),
    constraint check_vehicle_allowed
        check (vehicle in ('bike', 'scooter', 'foot'))
);

insert into i_a_mamaev.courier_shift (shift_id, employee_id, darkstore_id, vehicle, orders_done, shift_date)
values (1, 3, 1, 'bike', 14, '10 August 2026'::date),
       (2, 4, 1, 'scooter', 11, '10 August 2026'::date),
       (3, 12, 3, 'foot', 6, '10 August 2026'::date);

alter table i_a_mamaev.courier_shift
    add column distance_km numeric(8, 2);
alter table i_a_mamaev.courier_shift
    alter column vehicle type varchar(30);
alter table i_a_mamaev.courier_shift
    rename column orders_done to orders_delivered;
select shift_id,
       employee_id,
       hours_planned,
       orders_delivered,
       vehicle,
       is_closed,
       distance_km
from i_a_mamaev.courier_shift
order by shift_id;


select sku_id,
       name as product_name,
       unit,
       shelf_life_days
from db_vzhukh.product
where shelf_life_days > 2
  and brand is null
order by sku_id;


select distinct (darkstore_id, role)
from employee
where employee.dismissed_dt is null;


select darkstore_id, sku_id, qty_available, qty_reserved
from stock
where qty_available between 0 and 5
order by qty_available, darkstore_id, sku_id;


select order_id, delivery_address, status
from orders
where delivery_address ilike '%г. Санкт-Петербург%'
  and not delivery_address ilike '%ул. Садовая%'
  and status != 'cancelled'
order by order_id
limit 5;


select customer_id,
       full_name,
       registered_at,
       case
           when registered_at between '1 January 2026'::date and '1 January 2027'::date then 'new'
           when registered_at between '1 January 2025'::date and '1 January 2026'::date then 'active'
           else 'veteran'
           end as customer_segment
from customer
where customer.full_name notnull
order by customer_segment, registered_at desc, customer_id
offset 18 limit 4;

