import pandas as pd
import psycopg2  # noqa: F401
from sqlalchemy import create_engine, event

your_login = 'srw6QmYF'
your_pass = 'BQk2tAw2rOB8vgsiuSIU2jQENX8MPs8u'

engine = create_engine(
    f"postgresql+psycopg2://{your_login}:{your_pass}@db.cu3rd.ru:5432/cu-db?sslmode=require",
    connect_args={"options": "-csearch_path=db_vzhukh,public -ctimezone=Europe/Moscow"},
)

print(f"postgresql+psycopg2://{your_login}:{your_pass}@db.cu3rd.ru:5432/cu-db?sslmode=require")

@event.listens_for(engine, "connect")
def set_search_path(dbapi_conn, conn_record):
    """У меня стоит pgbouncer перед базой данных, так что connect_args из темплейта дропались"""
    cur = dbapi_conn.cursor()
    cur.execute("SET search_path TO db_vzhukh, public")
    cur.execute("SET timezone TO 'Europe/Moscow'")
    cur.close()
    dbapi_conn.commit()


def execute_sql(query):
    conn = engine.raw_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(query)
        conn.commit()

        # вывод сообщений PL/pgSQL (только RAISE NOTICE)
        if conn.notices:
            print("PostgreSQL messages:")
            for notice in conn.notices:
                print(" ", notice.strip())
            conn.notices.clear()

        # DQL
        if cursor.description is not None:
            columns = [desc[0] for desc in cursor.description]
            rows = cursor.fetchall()
            return pd.DataFrame(rows, columns=columns)

        # DDL / DML
        if cursor.rowcount != -1:
            print(f"Command executed successfully, affected rows: {cursor.rowcount}")
        else:
            print("Command executed successfully")

        return None

    except Exception as e:  # noqa: BLE001
        conn.rollback()
        print("Error:", e)
    finally:
        cursor.close()
        conn.close()

def main():
    print(execute_sql("select 1 as ok"))


if __name__ == "__main__":
    main()
