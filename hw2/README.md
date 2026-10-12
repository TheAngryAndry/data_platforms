# YARN cluster

Установка YARN и публикация веб-интерфейсов Hadoop через nginx. Перед запуском нужно выполнить [ДЗ1](../hw1/README.md): на внутренних узлах должны быть Java 11, Hadoop 3.4.2 и работающий HDFS с тремя DataNode.

На локальной машине нужны `bash`, `ssh`, `tar` и ключ `~/.ssh/id_ed25519_mts_course`.
На edge-ноде нужны `bash`, `ssh`, `scp`, `tar` и ключ `~/.ssh/team_internal`.
Пользователь `team` должен иметь доступ к внутренним узлам и `sudo` без пароля.

Из корня репозитория:

```bash
cd hw2
./scripts/deploy.sh
```

Скрипт копирует файлы в `~/data-platforms/hw2` на edge и проверяет, что HDFS из ДЗ1 работает. С NameNode берёт конфигурацию HDFS и дистрибутив Hadoop для edge. Затем создаёт пользователей `yarn` и `mapred`, каталоги, конфигурацию и systemd-сервисы, устанавливает nginx и запускает YARN. HDFS не форматируется и не перезапускается.

ResourceManager, встроенный WebAppProxy, JobHistoryServer и nginx работают на `team-01-en`. Два NodeManager работают на `team-01-00` и `team-01-01`: на каждом для контейнеров выделены 2048 MiB и 2 vCPU. MapReduce настроен на запуск через YARN с агрегацией логов в HDFS.

Параметры установки находятся в `cluster.conf`, настройки YARN в `config/`, systemd-сервисы в `systemd/`, конфигурация nginx в `nginx/`.

При повторном запуске скрипт сохраняет предыдущую конфигурацию в `/var/backups/data-platforms.*` и перезапускает YARN. Перед запуском дождитесь завершения работающих задач. При ошибке команды выполнение останавливается.

Для доступа к веб-интерфейсам запустите на локальной машине из папки `hw2`:

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
- `scripts/deploy-yarn-edge.sh`: копирование файлов и запуск установки на узлах.
- `scripts/install-yarn.sh`: установка YARN и nginx, резервная копия настроек.
- `scripts/configure-hosts.py`: настройка внутренних адресов кластера в `/etc/hosts`.
- `scripts/setup-hdfs.sh`: создание пользователей и каталогов для YARN и истории задач в существующем HDFS.
- `scripts/firewall.sh`: ограничение доступа к backend-портам внутренней сетью.
- `scripts/open-web.sh`: SSH-туннель для веб-интерфейсов.
