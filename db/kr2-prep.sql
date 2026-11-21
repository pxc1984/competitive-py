-- postgres://student:local_practice_2026@127.0.0.1:5432/cu-db?sslmode=disable

DROP TABLE IF EXISTS rate_test_9;
DROP TABLE IF EXISTS rate_test_10;

CREATE TABLE rate_test_9 AS
SELECT employee_id,
       full_name,
       role,
       hourly_rate
FROM employee
WHERE darkstore_id = 3;

CREATE TABLE rate_test_10
(
    employee_id int NOT NULL,
    hourly_rate numeric(8, 2) NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    PRIMARY KEY(employee_id, valid_from)
);

INSERT INTO rate_test_10 (employee_id, hourly_rate, valid_from, valid_to)
SELECT employee_id,
       hourly_rate,
       hired_dt,
       NULL
FROM employee
WHERE darkstore_id = 2;


--Выведи товары, которые были хотя бы в одном отменённом заказе (`status = 'cancelled'`). Используй два вложенных подзапроса с `IN`, без соединений таблиц. Столбцы: `sku_id`, `name`, `brand`. Сортировка по `sku_id`.

select sku_id,
       name,
       brand
from product
where product.sku_id in (select oi.sku_id
                         from order_item oi
                         where oi.order_id in (select o.order_id
                                               from orders o
                                               where o.status = 'cancelled'))
order by sku_id;

--Для доставленных заказов Купчино (`darkstore_id = 4`) посчитай накопленную сумму `total_amount` по времени доставки `delivered_at`. Столбцы: `order_id`, `delivered_at`, `total_amount`, `running_amount`. Сортировка по `delivered_at`.

select order_id,
       delivered_at,
       total_amount,
       sum(total_amount) over(partition by darkstore_id order by delivered_at asc) as running_amount
from orders
where darkstore_id = 4
order by delivered_at;



--1. Создай представление `current_price_test_8`: действующие цены товаров (`valid_to` пустое). Столбцы: `sku_id`, `name`, `price`.
--2. Выведи из представления товары дороже 550 рублей. Сортировка по `price` по убыванию, при равной цене по `sku_id`.

drop view if exists current_price_test_8;
create view current_price_test_8 as
select product_price.sku_id,
       name,
       price
from product_price
         left join product p on product_price.sku_id = p.sku_id
where valid_to is null;

select *
from current_price_test_8
where price > 550
order by price desc, sku_id;



--В `rate_test_9` сотрудники Петроградской. Одной транзакцией:
--
--1. подними ставку сборщикам Крыловой (`employee_id = 10`) и Носову (`employee_id = 11`) на 15 рублей;
--2. поставь точку сохранения;
--3. по ошибке поставь курьеру Шарипову (`employee_id = 12`) ставку 5000;
--4. откатись к точке сохранения и зафиксируй транзакцию.
--
--Затем выведи `employee_id`, `hourly_rate` из `rate_test_9`. Сортировка по `employee_id`.

begin;
              update employee
              set hourly_rate = hourly_rate + 15
              where employee_id in (10, 11);
       savepoint sv1;
              update employee
              set hourly_rate = 5000
              where employee_id = 12;
       rollback to savepoint sv1;
commit;
select employee_id,
       hourly_rate
from rate_test_9
order by employee_id;



--Для каждого города найди курьера с наибольшим числом доставленных заказов. При равном числе выше курьер с большей суммой `total_amount`, дальше - с меньшим `courier_id`. Число доставок и сумму посчитай в общем табличном выражении, место - через `row_number`. Столбцы: `city_name`, `courier_id`, `full_name`, `deliveries_count`, `delivered_amount`. Сортировка по `city_name`.

begin;
       create view employee_scores as
       select e.employee_id as courier_id,
              e.full_name as full_name,
              (select count(o)
               from orders o
               where o.courier_id = e.employee_id) as deliveries_count,
              (select sum(o.total_amount)
               from orders o
               where o.courier_id = e.employee_id) as delivered_amount,
              c.city_id,
              c.name as city_name
       from employee e
                left join darkstore d on e.darkstore_id = d.darkstore_id
                left join city c on d.city_id = c.city_id;

       create view employee_ranks as
       select row_number() over(partition by city_id order by deliveries_count desc, delivered_amount desc) as city_rank,
              city_name,
              courier_id,
              full_name,
              deliveries_count,
              delivered_amount
       from employee_scores;

       select city_name,
              courier_id,
              full_name,
              deliveries_count,
              delivered_amount
       from employee_ranks
       where city_rank = 1;

rollback;

--Чай (`sku_id = 25`) и протеиновый батончик (`sku_id = 40`) подорожали 15 июля. Для позиций доставленных заказов с этими товарами найди в `product_price` версию цены, которая действовала в момент `order_item.created_at`. Для каждой версии цены выведи `sku_id`, `price`, `valid_from`, число позиций `positions_count` и собранное количество `qty_collected_total`. Сортировка по `sku_id` и `valid_from`.

select pp.sku_id,
       pp.price,
       valid_from,
       count(oi) as positions_count,
       sum(oi.qty_collected) as qty_collected_total
from product_price pp
         left join order_item oi on pp.sku_id = oi.sku_id
where oi.sku_id in (25, 40)
  and exists (select 1
              from orders o
              where o.order_id = oi.order_id
                and o.status = 'delivered')
  and oi.created_at between pp.valid_from and pp.valid_to
group by pp.sku_id, pp.price, pp.valid_from
order by pp.sku_id, valid_from;

--В `rate_test_10` история почасовых ставок сотрудников Академической. Действующая ставка - строка с пустым `valid_to`. Ставку меняют одним `UPDATE` действующей строки: в `hourly_rate` новая ставка, в `valid_from` дата её начала.
--
--Напиши функцию `keep_rate_history_test_10` и триггер `rate_history_test_10`, который вызывает её перед обновлением каждой строки `rate_test_10`. Что должен делать триггер:
--
--- если ставка не изменилась, то вывести сообщение "Обновление отклонено, так как ставка сотрудника {employee_id} не изменилась."
--- прежняя ставка остаётся в истории: её строка получает в `valid_to` дату начала новой ставки, остальные поля не меняются;
--- новая ставка появляется отдельной строкой с пустым `valid_to`;
--- снижение ставки отклоняется с ошибкой «Ставку сотрудника {employee_id} нельзя снизить».
--
--Проверь двумя изменениями с 1 сентября 2026 года: Дроздовой (`employee_id = 7`) ставка 470.00, Абдулову (`employee_id = 9`) ставка 500.00. Затем выведи `employee_id`, `hourly_rate`, `valid_from`, `valid_to` из `rate_test_10`. Сортировка по `employee_id` и `valid_from`.

--create or replace function keep_rate_history_test_10() returns as $$
--       declare
--       begin
--       return value;
--exception
--       $$ language plpgsql;


-- cleanup
DROP VIEW IF EXISTS current_price_test_8;
DROP TABLE IF EXISTS rate_test_9;
DROP TABLE IF EXISTS rate_test_10;
DROP FUNCTION IF EXISTS keep_rate_history_test_10 ();
drop view if exists employee_scores;
drop view if exists employee_ranks;
