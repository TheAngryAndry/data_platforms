# HDFS-кластер team-01

Автоматизированное развёртывание учебного HDFS-кластера Apache Hadoop 3.4.2 на четырёх Ubuntu-серверах. После развёртывания кластер содержит сервисы NameNode и SecondaryNameNode, а также три работающих DataNode с коэффициентом репликации `3`.

## Топология

| Узел | Внутренний IP | Роли |
|---|---:|---|
| `team-01-en` | `10.1.0.10` | только SSH gateway (публичный IP `171.22.72.148`) |
| `team-01-nn` | `10.1.0.11` | NameNode, SecondaryNameNode, DataNode |
| `team-01-00` | `10.1.0.12` | DataNode |
| `team-01-01` | `10.1.0.13` | DataNode |

NameNode RPC доступен внутри сети на `10.1.0.11:8020`, Web UI — на `10.1.0.11:9870`, SecondaryNameNode HTTP — на `10.1.0.11:9868`. Публикуемые адреса используют внутренний IP, а отдельные `*-bind-host` параметры не дают Java ошибочно привязаться только к локальному `127.0.1.1`. HDFS хранит метаданные и блоки в `/data/hdfs`; программы установлены в `/opt/hadoop-3.4.2`, конфигурация — в `/etc/hadoop/conf`, журналы — в `/var/log/hadoop-hdfs` и systemd journal.

Проверенное исходное состояние на 22 сентября 2026 года: Ubuntu 24.04.5 LTS, около 3.8 GiB RAM и 46 GiB свободного места на каждом узле; Java и Hadoop отсутствовали, порты HDFS были свободны, DNS-имена всех четырёх узлов взаимно разрешались.

## Состав репозитория

- `cluster.env` — несекретные параметры кластера, версия Hadoop и закреплённая SHA-512 сумма;
- `config/` — единая Hadoop-конфигурация и список workers;
- `systemd/` — unit-файлы NameNode, DataNode и SecondaryNameNode;
- `scripts/deploy-hdfs.sh` — полный запуск с локальной машины;
- `scripts/install-node.sh` и `scripts/deploy-from-edge.sh` — установка на узлах;
- `scripts/verify-hdfs.sh` — автоматическая проверка сервисов, трёх DataNode, `fsck` и критических сообщений journal.

Приватные ключи в артефакты не входят. Локальный ключ используется только клиентом SSH, внутренний ключ остаётся на edge-ноде.

## Автоматическое развёртывание

Требования к локальной машине: Bash, `ssh`, `scp` и доступный ключ `~/.ssh/id_ed25519_mts_course`. Внутренний ключ `/home/team/.ssh/team_internal` уже должен находиться на `team-01-en`.

Из корня репозитория выполнить:

```bash
chmod +x scripts/*.sh
./scripts/deploy-hdfs.sh
```

Если локальный ключ расположен иначе:

```bash
LOCAL_SSH_KEY=/absolute/path/to/key ./scripts/deploy-hdfs.sh
```

Скрипт выполняет следующую целостную последовательность:

1. Создаёт временный staging-каталог на edge-ноде и загружает туда артефакты.
2. Загружает Hadoop 3.4.2 только с официального зеркала Apache и сверяет закреплённую SHA-512 сумму.
3. Передаёт проверенный архив на внутренние узлы через edge.
4. Ставит OpenJDK 11, создаёт системного пользователя `hdfs` и группу `hadoop`.
5. Устанавливает Hadoop и конфигурацию, создаёт каталоги данных с ограниченными правами.
6. На edge-ноде ничего не устанавливает: она используется только как SSH-шлюз и временная точка передачи проверенного архива.
7. Форматирует NameNode только при отсутствии `/data/hdfs/namenode/current/VERSION`. Существующий NameNode повторно не форматируется.
8. Запускает NameNode, ждёт RPC-порт, затем запускает SecondaryNameNode и DataNode на `team-01-nn`, а также DataNode на `team-01-00` и `team-01-01` через systemd.
9. Сразу запускает автоматическую проверку целостности.

Повторный запуск безопасно обновляет дистрибутив той же версии, конфигурацию и unit-файлы. Он не удаляет данные HDFS. Скрипт не предназначен для смены версии Hadoop или пересоздания уже инициализированного кластера без отдельного плана миграции.

## Проверка результата

Повторить полную CLI-проверку можно независимо от установки:

```bash
./scripts/verify-hdfs.sh
```

Успешный итог заканчивается строкой:

```text
PASS: HDFS is healthy; 3 live DataNodes, 0 dead DataNodes
```

Скрипт проверяет:

- active-состояние пяти systemd-сервисов на соответствующих узлах;
- `Live datanodes (3)` и `Dead datanodes (0)` в `hdfs dfsadmin -report`;
- `Status: HEALTHY` в `hdfs fsck /`;
- отсутствие записей уровня `err` за последние 10 минут в journal HDFS-сервисов.

### Подтверждённый результат

22 сентября 2026 года развёртывание проверено на серверах `team-01`:

```text
team-01-nn: hdfs-namenode, hdfs-secondarynamenode, hdfs-datanode — active
team-01-00: hdfs-datanode — active
team-01-01: hdfs-datanode — active
Live datanodes (3), Dead datanodes (0)
Under replicated blocks: 0
Blocks with corrupt replicas: 0
Missing blocks: 0
Status: HEALTHY
PASS: HDFS is healthy; 3 live DataNodes, 0 dead DataNodes
```

NameNode Web/JMX независимо вернул `NumLiveDataNodes=3` и `NumDeadDataNodes=0`. На `team-01-en` подтверждено отсутствие Hadoop, HDFS unit-файлов и HDFS-сервисов: узел используется только как SSH-шлюз.

Для ручной проверки на edge-ноде:

```bash
ssh -i ~/.ssh/id_ed25519_mts_course team@171.22.72.148
ssh -i ~/.ssh/team_internal team@team-01-nn sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf dfsadmin -report
ssh -i ~/.ssh/team_internal team@team-01-nn sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf fsck /
ssh -i ~/.ssh/team_internal team@team-01-nn systemctl status hdfs-namenode hdfs-secondarynamenode hdfs-datanode --no-pager
```

Для доступа к Web UI создать SSH-туннель с локальной машины:

```bash
ssh -N -L 9870:10.1.0.11:9870 \
  -i ~/.ssh/id_ed25519_mts_course team@171.22.72.148
```

Затем открыть [http://localhost:9870](http://localhost:9870), перейти в **Datanodes** и убедиться, что показаны 3 live и 0 dead узлов.

## Диагностика

Статус и последние журналы читаются без изменения данных:

```bash
# На NameNode
sudo systemctl status hdfs-namenode --no-pager
sudo journalctl -u hdfs-namenode -n 100 --no-pager

# На DataNode или SecondaryNameNode
sudo systemctl status hdfs-datanode --no-pager
sudo journalctl -u hdfs-datanode -n 100 --no-pager
sudo journalctl -u hdfs-secondarynamenode -n 100 --no-pager
```

Не удаляйте `/data/hdfs`, не запускайте повторное форматирование NameNode и не меняйте `dfs.replication` при диагностике: эти операции могут привести к потере или недорепликации данных.
