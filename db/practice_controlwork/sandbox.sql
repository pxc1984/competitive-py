-- Подготовка, не решения. Выполнять целиком на одном соединении.
-- Завершить свою задачу командой ROLLBACK. Не выполнять COMMIT.
SET LOCAL search_path TO db_vzhukh,
    public;
SET LOCAL timezone TO 'Europe/Moscow';
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '3s';

-- CTAS копирует только выбранные данные, без исходных триггеров и DEFAULT nextval.
CREATE TEMP TABLE lab_stock ON COMMIT DROP AS
SELECT darkstore_id,
       sku_id,
       qty_available,
       qty_reserved,
       updated_at
FROM db_vzhukh.stock;
ALTER TABLE pg_temp.lab_stock ADD PRIMARY KEY(darkstore_id, sku_id), ADD CHECK (qty_available >= 0), ADD CHECK (qty_reserved >= 0);
ALTER TABLE pg_temp.lab_stock ALTER COLUMN qty_available
SET NOT NULL,
    ALTER COLUMN qty_reserved
SET NOT NULL;

-- Своя временная identity-последовательность, не sequence реальной таблицы.
CREATE TEMP TABLE lab_price
(
    price_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku_id integer NOT NULL,
    price numeric NOT NULL CHECK (price > 0),
    valid_from timestamptz NOT NULL,
    valid_to timestamptz
) ON COMMIT DROP;
INSERT INTO pg_temp.lab_price(sku_id, price, valid_from, valid_to)
SELECT sku_id,
       price,
       valid_from,
       valid_to
FROM db_vzhukh.product_price
ORDER BY price_id;
-- price_id учебной копии не обязан совпадать с исходным.
-- Проверки интервалов и уникальности открытой версии намеренно не добавлены:
-- их требуется исследовать в задачах 13 и 24.
SET LOCAL search_path TO pg_temp,
    db_vzhukh,
    public;

SELECT 'lab_stock' AS object_name,
       count(*) AS rows
FROM pg_temp.lab_stock
UNION ALL
SELECT 'lab_price',
       count(*)
FROM pg_temp.lab_price;
-- Здесь выполняй одну задачу, затем ROLLBACK.

select o.order_id,
       o.total_amount
from orders o
where o.status = 'delivered'
  and o.total_amount > (select avg(total_amount) as avg_total_amount
                        from orders)
order by o.total_amount desc, o.order_id asc;

select c.customer_id,
       c.full_name
from db_vzhukh.customer c
where not exists (select 1
                  from db_vzhukh.orders o
                  where o.customer_id = c.customer_id)
order by c.customer_id;

select o.order_id,
       case when o.total_amount > (select avg(total_amount)
                                   from orders
                                   where darkstore_id = o.darkstore_id) then 'more' else 'less' end
from orders o
order by o.darkstore_id;

select *
from product p
where not exists (select 1
                  from order_item oi
                           left join orders o on oi.order_id = o.order_id
                  where o.status = 'delivered'
                    and oi.sku_id = p.sku_id
                    and oi.qty_collected > 0);

select orders.customer_id,
       order_id,
       created_at,
       row_number() over(partition by c order by created_at) as order_number
from orders
         left join customer c on orders.customer_id = c.customer_id
where orders.customer_id = 23
order by orders.customer_id, created_at, order_id;

create temp view lab_delivery_report as
select o.order_id,
       d.name as darkstore_name,
       c.name as city_name,
       o.total_amount,
       case when o.delivered_at is null then null else greatest(o.delivered_at - o.promised_at, interval '0 seconds') end as delay_minutes
from orders o
         left join darkstore d on o.darkstore_id = d.darkstore_id
         left join city c on d.city_id = c.city_id
where o.status = 'delivered';

