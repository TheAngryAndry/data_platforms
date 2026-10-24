# ДЗ4: HDFS + YARN + Hive + Spark

Папка содержит ДЗ1 + ДЗ2 + ДЗ3 + ДЗ4 и запускается самостоятельно, без соседних папок. Устанавливаются Java 11, Python 3, Hadoop 3.4.2, Hive 4.0.0-alpha-2 с PostgreSQL и Spark 3.5.7.

## Полная установка

На локальной машине нужны `bash`, `ssh`, `tar` и ключ `~/.ssh/id_ed25519_mts_course`. На edge нужны `bash`, `curl`, `ssh`, `scp`, `tar` и ключ `~/.ssh/team_internal`. Пользователь `team` должен иметь доступ к внутренним узлам и `sudo` без пароля. Параметры узлов находятся в `cluster.conf`.

Из корня репозитория на чистых серверах:

```bash
./hw4/scripts/deploy.sh
```

Скрипт копирует папку в `~/data-platforms/hw4` на edge и последовательно выполняет:

1. Установку HDFS на `team-01-nn`, `team-01-00`, `team-01-01`, форматирование нового NameNode и запуск трёх DataNode. До запуска демонов `configure-hosts.py` задаёт внутренние IP для коротких и полных имён узлов; `team-01-nn` разрешается в `10.1.0.11`.
2. Установку YARN, JobHistoryServer и nginx. Два NodeManager получают по 2048 MiB и 2 vCPU. Настраиваются каталоги HDFS и агрегация логов.
3. Установку HiveServer2, отдельного Metastore и PostgreSQL. После успешного JDBC-запроса загружаются две партиции таблицы `hw3.sales` из `data/sales-*.csv`.
4. Установку Spark с проверкой SHA-512, запуск `sales.py` под YARN и проверку таблицы `hw4.daily_sales` через Beeline.

Полный запуск предназначен для чистых серверов: при существующей группе `hadoop` установка HDFS остановится. Повторно форматировать действующий кластер не нужно. Перед изменениями установщики сохраняют конфигурацию и состояние сервисов в `/var/backups/data-platforms*`. Пароль PostgreSQL создаётся на сервере и хранится в `/etc/hive/metastore/hive-site.xml` с правами `root:hive 0640`; в исходниках его нет.

## Запуск на готовом кластере

Если HDFS, YARN и Hive уже работают, с локальной машины:

```bash
./hw4/scripts/deploy-spark.sh
```

Этот запуск копирует папку, устанавливает Spark и выполняет только ДЗ4. Имена узлов должны разрешаться во внутренние IP; исправление адресов входит в полную установку HDFS. Python 3 устанавливается на edge и NodeManager при отсутствии.

Повторный запуск непосредственно на `team-01-en`:

```bash
cd ~/data-platforms/hw4
./scripts/run-spark.sh
# Только проверка результата:
./scripts/check-spark.sh
```

Повторный запуск заменяет CSV и результат в `/user/team/hw4`. Выполняйте его вне активных чтений таблицы.

## Обработка данных

`run-spark.sh` загружает `data/sales.csv` в HDFS и запускает `sales.py` через `spark-submit --master yarn --deploy-mode cluster`. Driver и два executor размещаются на `team-01-00` и `team-01-01`; каждому выделено 512 MiB памяти JVM и 384 MiB дополнительно.

В одной SparkSession CSV читается из `hdfs://team-01-nn:8020/user/team/hw4/input/sales.csv`. Дата, количество и цена приводятся к `DATE`, `INT` и `DECIMAL(10,2)`, рассчитывается стоимость, затем число продаж, количество товаров и выручка по дням.

Результат записывается в Parquet в `/user/team/hw4/daily_sales` с партициями по `sale_date`. `sql/daily-sales.sql` создаёт внешнюю таблицу `hw4.daily_sales` в Hive через Beeline и регистрирует партиции. Spark не подключается напрямую к Metastore Hive 4.

`check-spark.sh` читает таблицу стандартным клиентом Hive (Beeline) и сравнивает строки и партиции с `data/expected.tsv`. При несовпадении скрипт завершается с ошибкой.

| sale_date | orders | quantity | revenue |
| --- | --- | --- | --- |
| 2026-10-18 | 3 | 15 | 1660.00 |
| 2026-10-19 | 3 | 8 | 890.00 |

Данные ДЗ3 можно загрузить отдельно на edge:

```bash
cd ~/data-platforms/hw4
./scripts/load-data.sh
./scripts/beeline.sh -e 'SHOW PARTITIONS hw3.sales; SELECT sale_date, COUNT(*), SUM(quantity * unit_price) FROM hw3.sales GROUP BY sale_date;'
```

Ожидается по 3 строки за каждый день, выручка 1660 и 890. `LOAD DATA LOCAL ... OVERWRITE` заменяет две партиции ДЗ3; загрузка не транзакционная.

## Сервисы и доступ

| Узел | Сервисы |
| --- | --- |
| `team-01-en` | ResourceManager, WebAppProxy, JobHistoryServer, nginx, HiveServer2, Metastore, PostgreSQL; клиент Spark |
| `team-01-nn` | NameNode, SecondaryNameNode, DataNode |
| `team-01-00`, `team-01-01` | DataNode, NodeManager; контейнеры Spark |

Конфигурации находятся в `config/`, службы в `systemd/`, настройки nginx в `nginx/`. Веб-интерфейсы доступны через SSH-туннель с локальной машины:

```bash
./hw4/scripts/open-web.sh
```

Порты на `127.0.0.1`: NameNode — 9870, SecondaryNameNode — 9868, DataNode — 9864/9865/9869, ResourceManager — 8088, NodeManager — 8042/8043, JobHistoryServer — 19888. Оставьте туннель открытым на время работы.

Hive слушает loopback. Для внешнего JDBC-клиента:

```bash
ssh -F /dev/null -i ~/.ssh/id_ed25519_mts_course \
  -N -L 10000:127.0.0.1:10000 team@171.22.72.148
```

URL: `jdbc:hive2://127.0.0.1:10000/default`, пользователь `team`, пароль пустой. Аутентификацию обеспечивает SSH; запросы выполняются от `hive` (`doAs=false`). Metastore хранит метаданные в PostgreSQL и обслуживает HiveServer2 по Thrift. Для проверки нескольких клиентов откройте `scripts/beeline.sh` в двух SSH-сессиях. Журналы: `sudo journalctl -u hive-metastore -u hive-server2`.

## Проверка

Локальная проверка объединения (архив, порядок этапов, остановка при ошибке, нормализация `/etc/hosts`):

```bash
python3 hw4/tests/check.py
```

Проверки на кластере описаны в [verification.txt](verification.txt).
