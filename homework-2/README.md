# YARN cluster

Развертывание YARN и публикация веб-интерфейсов Hadoop 3.4.2 поверх [ДЗ 1](../homework-1/).

На локальной машине нужны `bash`, `ssh`, `tar`, `curl` и ключ `~/.ssh/id_ed25519_mts_course`.
На edge-ноде нужны `bash`, `ssh`, `scp`, `tar` и ключ `~/.ssh/team_internal`.
Пользователь `team` должен иметь доступ к внутренним узлам и `sudo` без пароля. HDFS из ДЗ 1 должен быть запущен.

Из корня репозитория:

```bash
cd homework-2
./scripts/deploy.sh
```

Другой путь к ключу можно передать через `LOCAL_SSH_KEY`. Скрипт копирует `homework-2` на edge, переносит установленный Hadoop с NameNode на edge и устанавливает Java и nginx. Затем создает пользователей `yarn` и `mapred`, конфигурацию, каталоги и systemd-сервисы, запускает YARN и проверяет кластер.

ResourceManager, встроенный WebAppProxy и JobHistoryServer работают на `team-01-en`. NodeManager работают на `team-01-00` и `team-01-01`: по 2048 MiB и 2 vCPU для контейнеров. На `team-01-nn` остаются NameNode, SecondaryNameNode и DataNode из ДЗ 1. Это оставляет память для HDFS на узле с 3.8 GiB RAM.

Настройки находятся в `config/`, сервисы — в `systemd/`, конфигурация nginx — в `nginx/`. Адреса соответствуют кластеру `team-01`; при переносе на другой кластер нужно изменить `cluster.conf`, XML и конфигурацию nginx.

Конфигурация YARN устанавливается в `/etc/hadoop/yarn-conf`. Скрипт не форматирует NameNode и не перезапускает HDFS. В HDFS создаются каталоги `/logs`, `/mr-history`, `/user/team` и общий `/tmp`. Включены `mapreduce_shuffle`, запуск MapReduce через YARN и агрегация логов в HDFS. Контейнеры AM, map и reduce получают по 512 MiB, Java heap — 256 MiB.

На edge и узлах NodeManager скрипт исправляет записи имен кластера в `/etc/hosts`: короткие имена и FQDN должны разрешаться во внутренние IP, а не в `127.0.1.1`. Исходный файл сохраняется в резервной копии. Без этого Hadoop RPC может привязаться к loopback даже при указанном внутреннем IP.

Пользователи `yarn` и `mapred` также создаются на NameNode: именно там HDFS определяет их группы. После этого обновляется кеш групп без перезапуска HDFS. Это нужно для чтения истории задач и агрегации логов.

Для доступа из браузера запустить на локальной машине и оставить терминал открытым:

```bash
./scripts/open-web.sh
```

Скрипт открывает девять локальных портов через одно SSH-соединение к edge. Остановка — `Ctrl+C`. Внешняя сеть учебного стенда пропускает только порт 22; этот способ работает без доступа к панели облака. Порты на локальной машине должны быть свободны.

Веб-интерфейсы доступны через туннель и nginx на edge:

| Демон | Узел | Адрес после запуска туннеля |
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

nginx переписывает внутренние адреса в ссылках и перенаправлениях на адрес, с которого открыт интерфейс. Разрешены только GET и HEAD. Это учебный кластер без Kerberos; при использовании туннеля доступ защищен SSH-ключом. Отдельное правило iptables ограничивает новые backend-порты `8030–8033`, `10020`, `10033`, `18088`, `19889` внутренней сетью `10.1.0.0/24`. Правило восстанавливается сервисом `hadoop-web-firewall`; общая политика firewall и SSH не меняются. Для прямого HTTP-доступа без SSH администратор облака должен открыть веб-порты из таблицы. Тогда вместо `127.0.0.1` используется `171.22.72.148`; nginx уже настроен. Сам по себе root-доступ на VM не позволяет изменить внешний firewall.

Проверку можно повторить на edge:

```bash
bash ~/homework-2/scripts/verify-edge.sh
```

Скрипт проверяет сервисы, два зарегистрированных NodeManager и три DataNode, запускает WordCount через YARN и сравнивает результат с ожидаемым. Затем проверяет `SUCCEEDED`, наличие задачи в JobHistoryServer, агрегированные логи, `hdfs fsck /` и все веб-интерфейсы. Вход и результат остаются в отдельном каталоге `/user/team/homework-2-*` в HDFS.

Проверка веб-интерфейсов с локальной машины с автоматическим открытием и закрытием туннеля:

```bash
./scripts/open-web.sh --check
```

Если туннель уже открыт, использовать `./scripts/verify-web.sh`. Для проверки прямого публичного доступа после открытия портов — `VERIFY_HOST=171.22.72.148 ./scripts/verify-web.sh`. Финальная проверка в `deploy.sh` использует SSH-туннель.

Повторный запуск `deploy.sh` сохраняет предыдущую конфигурацию в `/var/backups/homework-2.*`, обновляет настройки и перезапускает YARN. Выполнять его нужно без работающих задач. При ошибке скрипты останавливаются; логи сервисов доступны через `sudo journalctl -u yarn-resourcemanager`, `-u yarn-nodemanager` и `-u mapred-historyserver` на соответствующем узле. Логи Hadoop находятся в `/var/log/hadoop-yarn` и `/var/log/hadoop-mapred`.

- `scripts/deploy.sh` — запуск с локальной машины.
- `scripts/deploy-edge.sh` — установка и запуск на узлах через edge.
- `scripts/install.sh` — конфигурация одного узла и резервная копия.
- `scripts/configure-hosts.py` — исправление адресов кластера в `/etc/hosts`.
- `scripts/setup-hdfs.sh` — пользователи, группы и каталоги на NameNode.
- `scripts/firewall.sh` — ограничение доступа к backend-портам.
- `scripts/verify-edge.sh` — проверка HDFS, YARN и MapReduce.
- `scripts/verify-web.sh` — проверка веб-интерфейсов.
- `scripts/open-web.sh` — доступ к интерфейсам с локальной машины через SSH.

Проверено на кластере 2026-10-12: повторный запуск `deploy.sh`, WordCount, история, логи, HDFS и девять интерфейсов через SSH. Результат — в [verification.txt](verification.txt).

Параметры Hadoop сверены с [документацией Apache Hadoop 3.4.2](https://hadoop.apache.org/docs/r3.4.2/hadoop-project-dist/hadoop-common/ClusterSetup.html).

Переадресация портов описана в [руководстве OpenSSH](https://man.openbsd.org/ssh.1#L).
