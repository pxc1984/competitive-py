drop table if exists promo_code;
create table promo_code
(
    promo_id bigserial primary key,
    code varchar(20) not null,
    channel varchar(30) not null,
    description varchar(200),
    discount_percent integer,
    min_order_amount numeric (8,2),
    starts_at date,
    ends_at date,
    is_active boolean
);

-- Промокод с полной информацией.
--     ID: 1
--     Код: WELCOME10
--     Канал: email
--     Описание: Скидка для новых клиентов
--     Скидка: 10%
--     Минимальная сумма заказа: 500.00
--     Действует с 2026-07-01 по 2026-12-31
--     Активен: true
-- 
-- 2. Промокод с частичной информацией (используй значения по умолчанию).
--     ID: 2
--     Код: FLASH20
--     Канал: app_push
--     Скидка: 20%
-- 
-- 3. Добавь несколько промокодов одним запросом:
--     (3, 'SUMMER15', 'sms', 'Летняя акция', 15, 800.00, '2026-06-01', '2026-08-31', true)
--     (4, 'FRIEND5', 'social', 'Приведи друга', 5, 300.00, '2026-01-01', '2026-12-31', true)
--     (5, 'VIP25', 'email', 'Для постоянных клиентов', 25, 1500.00, '2026-05-01', '2026-09-30', false)

insert into promo_code (code, channel, description, discount_percent, min_order_amount, starts_at, ends_at, is_active)
values
    ('WELCOME10', 'email', 'Скидка для новых клиентов', 10, 500.00, '2026-07-01', '2026-12-31', true),
    ('FLASH20', 'app_push', null, 20, null, null, null, null),
    ('SUMMER15', 'sms', 'Летняя акция', 15, 800.00, '2026-06-01', '2026-08-31', true),
    ('FRIEND5', 'social', 'Приведи друга', 5, 300.00, '2026-01-01', '2026-12-31', true),
    ('VIP25', 'email', 'Для постоянных клиентов', 25, 1500.00, '2026-05-01', '2026-09-30', false);


alter table promo_code add column usage_limit integer;
alter table promo_code add column max_discount_amount numeric (8,2);
alter table promo_code alter column channel type varchar(50);
alter table promo_code alter column discount_percent set not null;
alter table promo_code rename column description to promo_description;


update promo_code set usage_limit = 1000 where promo_id = 1;
update promo_code set max_discount_amount = 300.00 where discount_percent > 15;
update promo_code set code = 'FRIEND10' where channel = 'social';
update promo_code set discount_percent = discount_percent + 5 where channel = 'email' and promo_code.is_active = true;
update promo_code set is_active = false where ends_at < '2026-09-01';


select code, channel, discount_percent, min_order_amount from promo_code where is_active = true;
delete from promo_code where is_active = false;
