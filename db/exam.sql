CREATE TABLE if not exists i_a_mamaev.supplier_test_2
(
    supplier_id  INT PRIMARY KEY,
    company      VARCHAR(60) NOT NULL,
    category     VARCHAR(40) NOT NULL,
    manager      VARCHAR(60) NOT NULL,
    city         VARCHAR(50),
    contract_dt  DATE,
    delay_days   INT,
    contract_sum NUMERIC(10,
                     2),
    audit_dt     DATE,
    is_active    BOOLEAN
);

INSERT INTO supplier_test_2 (supplier_id,
                             company,
                             category,
                             manager,
                             city,
                             contract_dt,
                             delay_days,
                             contract_sum,
                             audit_dt,
                             is_active)
VALUES (1,
        'Мычалово',
        'молочное',
        'Волошина Ирина',
        'Москва',
        '2026-02-10',
        1,
        240000.00,
        '2026-07-01',
        true),
       (2,
        'Кудахтпром',
        'яйца',
        'Седов Артур',
        'Санкт-Петербург',
        '2026-03-05',
        4,
        158000.00,
        '2026-07-14',
        true),
       (3,
        'Похрустелкино',
        'снеки',
        'Бельских Олег',
        NULL,
        '2026-04-18',
        2,
        NULL,
        '2026-07-20',
        false),
       (4,
        'Сырно-Дырск',
        'сыры',
        'Ким Наталья',
        'Санкт-Петербург',
        '2026-05-22',
        NULL,
        96000.00,
        NULL,
        true),
       (5,
        'Зевсогурт',
        'йогурты',
        'Рахимов Тимур',
        'Екатеринбург',
        '2026-06-30',
        7,
        51000.00,
        '2026-07-28',
        false);

-- 1. Добавь столбец `rating` (целое число) со значением по умолчанию 5.
alter table i_a_mamaev.supplier_test_2
    add column rating int default 5;
-- 2. Переименуй столбец `manager` в `manager_name`.
alter table i_a_mamaev.supplier_test_2
    rename column manager to manager_name;
-- 3. У поставщика с `supplier_id` = 3 замени `category` на «снеки и орехи», а `city` на «Казань».
update i_a_mamaev.supplier_test_2
set category = 'снеки и орехи',
    city     = 'Казань'
where supplier_id = 3;
-- 4. Снизь `contract_sum` на 10% для петербургских поставщиков, где сумма контракта указана.
update i_a_mamaev.supplier_test_2
set contract_sum = contract_sum - 10
where city = 'Санкт-Петербург'
  and contract_sum is not null;
-- 5. Удали поставщиков, у которых не указан город или не проставлена дата аудита.
delete
from i_a_mamaev.supplier_test_2
where city is null
   or audit_dt is null;
-- 6. Выведи итоговый реестр: `supplier_id`, `company`, `category`, `manager_name`, `city`, `contract_sum`, `rating`, отсортировав по `supplier_id`.
select s.supplier_id,
       s.company,
       s.category,
       s.manager_name,
       s.city,
       s.contract_sum,
       s.rating
from i_a_mamaev.supplier_test_2 s
order by s.supplier_id;
-- 7. Удали таблицу.
drop table if exists i_a_mamaev.supplier_test_2;


-- Руководитель доставки разбирает работу за середину июля. 
-- Найди уникальные статусы заказов,

-- оформленных с 5 по 25 июля 2026 года,

-- у которых адрес доставки не в Москве. 
-- Результат отсортируй по статусу.

select distinct o.status
from db_vzhukh.orders o
where o.created_at between '5 July 2026' and '25 July 2026'
  and o.delivery_address not ilike '%Москва%'
order by o.status;



-- Операционный отдел разбирает нагрузку по площадкам в разрезе месяцев.
-- Нужны пары «даркстор - месяц», в которых было не меньше трёх заказов.
-- 
-- Выведи `darkstore_id`,
-- номер месяца,
-- количество заказов,
-- количество отменённых и средний чек,
-- округлённый до двух знаков.
-- Количество отменённых посчитай конструкцией `FILTER`.
-- Поля в группировке и сортировке укажи порядковыми номерами.
-- Операционный отдел разбирает нагрузку по площадкам в разрезе месяцев.
-- Нужны пары «даркстор - месяц»,
-- в которых было не меньше трёх заказов.
-- 
-- Выведи `darkstore_id`,
-- номер месяца,
-- количество заказов,
-- количество отменённых и средний чек,
-- округлённый до двух знаков.
-- Количество отменённых посчитай конструкцией `FILTER`.
-- Поля в группировке и сортировке укажи порядковыми номерами.


select darkstore.darkstore_id,
       extract(month from o.created_at)                        as "номер месяца",
       count(o)                                                AS "количество заказов",
       count(o.status) filter ( where o.status = 'cancelled' ) as "количество отмененных",
       round(sum(o.total_amount) / count(o.total_amount), 2)   as "средний чек округленный до двух знаков"
from db_vzhukh.darkstore
         left join db_vzhukh.orders o on darkstore.darkstore_id = o.darkstore_id
group by 1, 2
having count(o) >= 3
order by 1, 2;

-- Отдел удержания ищет «спящих»: клиентов, которые зарегистрированы в сервисе, но не оформили ни одного заказа.
-- 
-- Выведи один столбец `customer_id`, отсортированный по возрастанию. Используй операцию над множествами.

select c.customer_id
from db_vzhukh.customer c
except
select o.customer_id
from db_vzhukh.orders o
order by 1;

-- HR считает премию сборщикам. Нужна витрина по сотрудникам, собравшим не меньше четырёх доставленных заказов.
-- 
-- Выведи имя сотрудника, название его даркстора, количество заказов, количество собранных позиций и выручку по этим заказам, округлённую до двух знаков. Выручка - сумма произведения `qty_collected` на `price`. Отсортируй по количеству заказов от большего к меньшему, при равенстве - по имени.

select e.full_name as "имя сотрудника",
       d.name as "название даркстора",
       count(o) as "количество заказов",
       round(sum(oi.qty_collected * oi.price), 2) as "выручка по этим заказам"
from db_vzhukh.employee e
         left join db_vzhukh.darkstore d on e.darkstore_id = d.darkstore_id
         left join db_vzhukh.orders o on e.employee_id = o.picker_id
        left join db_vzhukh.order_item oi on o.order_id = oi.order_id
group by e.full_name, d.name
having count(o) >= 4
order by "количество заказов" desc, e.full_name;

