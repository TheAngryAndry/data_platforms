# Spark под YARN

Пока здесь только ДЗ4. Нужен работающий кластер из ДЗ3: HDFS, YARN, HiveServer2 и Metastore. На узлах должна быть установлена Java 11; Python 3 скрипт установит при его отсутствии.

Из корня репозитория:

```bash
./hw4/scripts/deploy-spark.sh
```

На локальной машине нужны `bash`, `ssh`, `tar` и ключ `~/.ssh/id_ed25519_mts_course`. Скрипт копирует папку в `~/data-platforms/hw4` на edge, устанавливает Spark 3.5.7 с проверкой SHA-512 и выполняет задание. Перед установкой сохраняет состояние в `/var/backups/data-platforms-spark.*`.

На edge нужен ключ `~/.ssh/team_internal`; для установки Python при его отсутствии пользователь `team` должен иметь `sudo` без пароля на NodeManager. `fix-hdfs-address.sh` исправляет loopback-адрес имени `team-01-nn` в `/etc/hosts` и перезапускает его DataNode. Исходный файл сохраняется в `/var/backups/data-platforms-hdfs-address.*`; при верном адресе шаг пропускается.

`run-spark.sh` загружает `data/sales.csv` в HDFS и запускает `sales.py` через `spark-submit --master yarn --deploy-mode cluster`. Driver и два executor работают на `team-01-00` и `team-01-01`; каждому выделено 512 MiB памяти JVM и 384 MiB дополнительно.

В одной SparkSession CSV читается из `hdfs://team-01-nn:8020/user/team/hw4/input/sales.csv`. Дата, количество и цена приводятся к `DATE`, `INT` и `DECIMAL(10,2)`, рассчитывается стоимость, затем число продаж, количество товаров и выручка по дням.

Результат записывается в Parquet в `/user/team/hw4/daily_sales` с партициями по `sale_date`. `sql/daily-sales.sql` создаёт внешнюю таблицу `hw4.daily_sales` и регистрирует партиции. Spark 3.5 поддерживает Metastore до Hive 3.1.3, поэтому с Hive 4 из ДЗ3 таблица создаётся через Beeline ([документация](https://spark.apache.org/docs/3.5.7/sql-data-sources-hive-tables.html#interacting-with-different-versions-of-hive-metastore)).

`check-spark.sh` читает таблицу стандартным клиентом Hive (Beeline) и сравнивает строки и партиции с `data/expected.tsv`. При несовпадении скрипт завершится с ошибкой.

| sale_date | orders | quantity | revenue |
| --- | --- | --- | --- |
| 2026-10-18 | 3 | 15 | 1660.00 |
| 2026-10-19 | 3 | 8 | 890.00 |

Повторный запуск на edge:

```bash
cd ~/data-platforms/hw4
./scripts/run-spark.sh
# Только проверка:
./scripts/check-spark.sh
```

Повторный запуск заменяет исходный CSV и результат ДЗ4. Запускайте его вне активных чтений таблицы.

Проверено 20.10.2026 с `team-01-en`: приложение `application_1792131230855_0011` завершилось с `SUCCEEDED`, Spark выполнялся на `team-01-00` и `team-01-01`. Повторный запуск и проверка Beeline прошли. `hdfs fsck /user/team/hw4`: `HEALTHY`, по три реплики, потерянных блоков нет.
