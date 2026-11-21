# Локальная учебная PostgreSQL

Запуск из этой папки: `docker compose up -d --wait`.
Остановка: `docker compose stop`. Данные сохраняются в Docker volume.

Подключение: `postgres://student:local_practice_2026@127.0.0.1:5432/cu-db?sslmode=disable`

PostgreSQL 18, база `cu-db`, search_path `db_vzhukh,public`, часовой пояс Europe/Moscow.
Порт открыт только на localhost. Пользователь student имеет права на создание временных таблиц и учебных функций.

21.11.2026 перенесена схема db_vzhukh удалённой cu-db через pg_dump/pg_restore:
таблицы, данные, последовательности, ограничения, представления и объекты схемы.
Другие схемы и удалённые роли не копировались; локальный владелец — student.
Для ограничения пересечения истории цен установлено расширение btree_gist.
Исходная база не изменялась, экспорт выполнялся в режиме только чтения через SSL.

Резервный снимок: `.local-postgres/cu-db.dump` (исключён из Git).
При восстановлении в НОВУЮ пустую локальную базу:

```sh
docker compose exec -T postgres psql -U student -d cu-db -v ON_ERROR_STOP=1 -c 'CREATE EXTENSION IF NOT EXISTS btree_gist;'
docker compose exec -T postgres pg_restore -U student -d cu-db --no-owner --no-acl --exit-on-error --single-transaction < .local-postgres/cu-db.dump
```

Не выполняй восстановление повторно поверх заполненной базы.
`practice_controlwork/sandbox.sql` теперь можно запускать на этом локальном подключении.
