-- «У меня своя таблица остатков: строка - это товар на конкретном дарксторе, дальше сколько лежит и сколько зарезервировано под собранные заказы. Ещё там бренд, категория и родительская категория - без них я не понимаю, по какому направлению закупаться.
-- 
-- Поставщик переименовал бренд, и правку пришлось разносить по всем дарксторам, где товар лежит. Новую категорию тоже не завести: строка без товара и даркстора не пишется.
-- 
-- Разложите таблицу так, чтобы бренд и категория товара были записаны по одному разу».


DROP TABLE IF EXISTS i_a_mamaev.stock_report_v2_test_4;

CREATE TABLE i_a_mamaev.stock_report_v2_test_4 (
                                                   darkstore_name       varchar(100) NOT NULL,
                                                   darkstore_address    text         NOT NULL,
                                                   product_name         varchar(200) NOT NULL,
                                                   brand                varchar(100) NOT NULL,
                                                   category_name        varchar(100) NOT NULL,
                                                   parent_category_name varchar(100) NOT NULL,
                                                   quantity_available   integer      NOT NULL,
                                                   quantity_reserved    integer      NOT NULL
);

INSERT INTO i_a_mamaev.stock_report_v2_test_4
SELECT
    darkstore.name,
    darkstore.address,
    product.name,
    product.brand,
    category.name,
    parent_category.name,
    stock.qty_available,
    stock.qty_reserved
FROM db_vzhukh.stock
         JOIN db_vzhukh.darkstore
              ON darkstore.darkstore_id = stock.darkstore_id
         JOIN db_vzhukh.product
              ON product.sku_id = stock.sku_id
         JOIN db_vzhukh.product_category AS category
              ON category.category_id = product.category_id
         JOIN db_vzhukh.product_category AS parent_category
              ON parent_category.category_id = category.parent_category_id
WHERE stock.darkstore_id IN (2, 4)
  AND stock.sku_id IN (5, 24, 25, 39);

-- Вот что лежит в таблице Кирилла:
SELECT
    darkstore_name, product_name, brand, category_name,
    parent_category_name, quantity_available, quantity_reserved
FROM i_a_mamaev.stock_report_v2_test_4
ORDER BY darkstore_name, product_name;

-- Восьмой столбец в выдачу не поместился - это адрес даркстора:
SELECT DISTINCT darkstore_name, darkstore_address
FROM i_a_mamaev.stock_report_v2_test_4
ORDER BY darkstore_name;

-- 1. Какие функциональные зависимости выполняются в таблице остатков? Ключа в ней нет, его тоже предстоит найти.
    
-- 2. Определите первичный ключ через замыкание атрибутов и объясните, почему он минимален.
-- 3. Укажите для каждой зависимости, требование какой нормальной формы она ломает - второй или третьей.
-- 4. Соберите третью нормальную форму в базе: таблицы с суффиксом `_test_4`, первичные и внешние ключи, наполнение из выгрузки, сверка соединением с исходными восемью строками.
-- 5. Убедитесь, что внешний ключ не пустая декларация: заведите товар в категорию, которой нет в каталоге, и приведите текст ошибки.
