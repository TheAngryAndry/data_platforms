# HDFS + YARN + Hive

Папка содержит ДЗ1 + ДЗ2 + ДЗ3.

На локальной машине нужны `bash`, `ssh`, `tar` и ключ `~/.ssh/id_ed25519_mts_course`.
На edge-ноде нужны `bash`, `curl`, `ssh`, `scp`, `tar` и ключ `~/.ssh/team_internal`.
Пользователь `team` должен иметь доступ к внутренним узлам и `sudo` без пароля.

Из корня репозитория:

```bash
cd hw3
./scripts/deploy.sh
```

Скрипт копирует файлы в `~/data-platforms/hw3` на edge, устанавливает Java 11, Hadoop 3.4.2 и HDFS с тремя DataNode, форматирует NameNode и запускает сервисы. Затем проверяет HDFS, с NameNode берёт конфигурацию HDFS и дистрибутив Hadoop для edge. Создаёт пользователей `yarn` и `mapred`, каталоги, конфигурацию и systemd-сервисы, устанавливает nginx и запускает YARN.

После этого на edge устанавливаются Hive 4.0.0-alpha-2 и PostgreSQL. Metastore и HiveServer2 работают отдельными systemd-сервисами. HiveServer2 обращается к Metastore по Thrift, Metastore хранит метаданные в PostgreSQL. Несколько клиентов подключаются к HiveServer2 по JDBC; embedded Derby не используется.

ResourceManager, встроенный WebAppProxy, JobHistoryServer и nginx работают на `team-01-en`. Два NodeManager работают на `team-01-00` и `team-01-01`: на каждом для контейнеров выделены 2048 MiB и 2 vCPU. MapReduce настроен на запуск через YARN с агрегацией логов в HDFS.

Параметры установки находятся в `cluster.conf`, настройки HDFS и YARN в `config/`, systemd-сервисы в `systemd/`, конфигурация nginx в `nginx/`.

Полный запуск рассчитан на чистые серверы: повторная установка HDFS остановится, если группа `hadoop` уже существует. Этап YARN сохраняет предыдущую конфигурацию в `/var/backups/data-platforms.*`. При ошибке команды выполнение останавливается.

Для установки только Hive поверх готового ДЗ2 скопируйте папку на edge:

```bash
scp -F /dev/null -i ~/.ssh/id_ed25519_mts_course -r hw3 team@171.22.72.148:~/data-platforms/
ssh -F /dev/null -i ~/.ssh/id_ed25519_mts_course team@171.22.72.148
cd ~/data-platforms/hw3
./scripts/deploy-hive-edge.sh
```

Настройки Hive сохраняются перед установкой в `/var/backups/data-platforms-hive.*`. Пароль PostgreSQL создаётся на сервере и записывается в `/etc/hive/metastore/hive-site.xml` с правами `root:hive 0640`. Схема БД инициализируется только для пустой базы.

После запуска HiveServer2 выполните на edge:

```bash
cd ~/data-platforms/hw3
./scripts/load-data.sh
./scripts/beeline.sh
```

Загрузка создаёт внешнюю таблицу `hw3.sales` и две партиции по `sale_date`: `2026-10-18` и `2026-10-19`. Исходные CSV лежат в `data/`. `LOAD DATA LOCAL` читает файлы на edge и копирует их в HDFS. `OVERWRITE` заменяет эти партиции при повторной загрузке.

Для проверки откройте `beeline.sh` в двух SSH-сессиях и выполните в каждой:

```sql
SHOW PARTITIONS hw3.sales;
SELECT sale_date, COUNT(*), SUM(quantity * unit_price)
FROM hw3.sales GROUP BY sale_date;
```

Ожидается по 3 строки в каждой партиции, суммы 1660 и 890. Загрузка не транзакционная; выполняйте её вне активных чтений.

Hive слушает только loopback. Для внешнего JDBC-клиента:

```bash
ssh -F /dev/null -i ~/.ssh/id_ed25519_mts_course \
  -N -L 10000:127.0.0.1:10000 team@171.22.72.148
```

URL: `jdbc:hive2://127.0.0.1:10000/default`, пользователь `team`, пароль пустой. Аутентификация обеспечивается SSH; запросы выполняются от `hive` (`doAs=false`). Параметр `hive.support.concurrency=false` отключает блокировки таблиц, а не клиентские сессии.

Журналы: `sudo journalctl -u hive-metastore -u hive-server2` и `/tmp/hive/hive.log`.

Для доступа к веб-интерфейсам запустите на локальной машине из папки `hw3`:

```bash
./scripts/open-web.sh
```

Оставьте терминал открытым. Скрипт создаёт SSH-туннель к edge; для остановки нажмите `Ctrl+C`. Локальные порты из таблицы должны быть свободны.

| Демон | Узел | Адрес через туннель |
| --- | --- | --- |
| NameNode | team-01-nn | [9870](http://127.0.0.1:9870/dfshealth.html) |
| SecondaryNameNode | team-01-nn | [9868](http://127.0.0.1:9868/) |
| DataNode | team-01-nn | [9864](http://127.0.0.1:9864/datanode.html) |
| DataNode | team-01-00 | [9865](http://127.0.0.1:9865/datanode.html) |
| DataNode | team-01-01 | [9869](http://127.0.0.1:9869/datanode.html) |
| ResourceManager / WebAppProxy | team-01-en | [8088](http://127.0.0.1:8088/cluster) |
| NodeManager | team-01-00 | [8042](http://127.0.0.1:8042/node) |
| NodeManager | team-01-01 | [8043](http://127.0.0.1:8043/node) |
| JobHistoryServer | team-01-en | [19888](http://127.0.0.1:19888/jobhistory) |

Внешняя сеть стенда пропускает только порт 22. Для прямого HTTP-доступа администратор облака должен открыть порты из таблицы; тогда вместо `127.0.0.1` используйте `171.22.72.148`. nginx уже настроен на эти порты и разрешает только GET и HEAD. Кластер работает без Kerberos, доступ через туннель защищён SSH-ключом.

- `scripts/deploy.sh`: запуск с локальной машины.
- `scripts/deploy-hdfs-edge.sh`: скачивание Hadoop, копирование файлов и запуск HDFS на узлах.
- `scripts/install-hdfs.sh`: установка Java, Hadoop и конфигурации HDFS на узле.
- `scripts/deploy-yarn-edge.sh`: копирование файлов и запуск установки на узлах.
- `scripts/install-yarn.sh`: установка YARN и nginx, резервная копия настроек.
- `scripts/configure-hosts.py`: настройка внутренних адресов кластера в `/etc/hosts`.
- `scripts/setup-hdfs.sh`: создание пользователей и каталогов для YARN и истории задач в существующем HDFS.
- `scripts/firewall.sh`: ограничение доступа к backend-портам внутренней сетью.
- `scripts/open-web.sh`: SSH-туннель для веб-интерфейсов.
- `scripts/deploy-hive-edge.sh`: установка и запуск Hive на edge.
- `scripts/install-hive.sh`, `scripts/configure-hive.py`: дистрибутив, PostgreSQL и настройки Hive.
- `scripts/setup-hive-hdfs.sh`: пользователь и каталоги Hive на NameNode.
- `scripts/load-data.sh`, `sql/sales.sql`: загрузка партиций.
- `scripts/beeline.sh`: JDBC-клиент.
