select name as darkstore_name, city_id, opened_dt as opened_at
from darkstore
order by name;

select *
from orders
where created_at > '20:00 1 august 2026'
order by created_at;

select distinct orders.status
from orders
where
    orders.created_at > '1 august 2026' and orders.created_at < '1 september 2026'
or 
    orders.delivery_address like '%екатеринбург%';

select
    card_id,
    customer_id,
    payment_system as card_network,
    last4,
    added_at
from payment_card
where
    (payment_system in ('visa', 'mastercard'))
and
    last4 not like '1%'
and deleted_at is null
order by payment_system, added_at;

select 
    order_id, 
    status,
    promised_at,
    delivery_address,
    case
        when status = 'delivered' and delivered_at > promised_at then 'late_delivery'
        when delivered_at <= promised_at then 'on_time_delivery'
        when status = 'cancelled' then 'cancelled'
        else 'in_progress'
    end as category
from orders
where created_at > '1 august 2026'
order by category, created_at desc;
