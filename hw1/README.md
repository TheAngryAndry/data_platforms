# Домашнее задание №1: HDFS

Автоматизированное развёртывание Apache Hadoop 3.4.2: NameNode, SecondaryNameNode и три DataNode. Дедлайн: 12.10, 23:59.

| Узел | Внутренний IP | Сервисы ДЗ1 |
| --- | --- | --- |
| team-01-en | 10.1.0.10 | SSH-доступ и запуск установки |
| team-01-nn | 10.1.0.11 | NameNode, SecondaryNameNode, DataNode |
| team-01-00 | 10.1.0.12 | DataNode |
| team-01-01 | 10.1.0.13 | DataNode |

Коэффициент репликации: 3. На учебном стенде NameNode и SecondaryNameNode работают на одном узле. Установка YARN и публикация веб-интерфейсов описаны в [ДЗ2](../hw2/README.md).

## Подготовка

На серверах установлена Ubuntu 24.04. Пользователь `team` может выполнять `sudo` без пароля. Edge доступен по `171.22.72.148`; подключение к внутренним узлам возможно только через него. На edge имена `team-01-nn`, `team-01-00`, `team-01-01` должны разрешаться во внутренние IP из таблицы.

На локальной машине нужны `bash`, `ssh`, `tar` и ключ `~/.ssh/id_ed25519_mts_course`. На edge нужны `bash`, `curl`, `ssh`, `tar` и ключ `~/.ssh/team_internal` для внутренних узлов. Не копируйте ключи в репозиторий. Серверам нужен доступ к пакетам Ubuntu, а edge должен иметь возможность скачать Hadoop.

## Запуск

Из корня репозитория на локальной машине:

```bash
./hw1/scripts/deploy.sh
```

Из папки `hw1` запускайте `./scripts/deploy.sh`. Другой SSH-ключ можно указать через `LOCAL_SSH_KEY`. Скрипт передаёт исходники на edge в `~/data-platforms/hw1`, затем в такой же каталог на трёх внутренних узлах.

Если NameNode уже отформатирован, скрипт проверяет сервисы и целостность существующего HDFS. При незавершённой установке он останавливается. Перед повторной попыткой нужно проверить состояние узлов.

На чистом кластере скрипт:

1. Скачивает Hadoop на edge, передаёт архив и файлы ДЗ1 внутренним узлам.
2. Устанавливает Java 11 и Hadoop в `/opt/hadoop-3.4.2`, создаёт ссылку `/opt/hadoop`, пользователя `hdfs` и группу `hadoop`.
3. Устанавливает конфигурацию в `/etc/hadoop/conf`, создаёт каталоги данных `/data/hdfs/{namenode,datanode,secondary}`, логи и systemd-сервисы.
4. Однократно форматирует новый NameNode без `-force`, запускает NameNode, SecondaryNameNode и три DataNode, включает автозапуск.
5. Дожидается регистрации трёх DataNode и проверяет HDFS.

Повторный запуск сохраняет данные и не перезапускает работающий HDFS. При ошибке скрипты останавливаются. Если на узлах уже есть другая установка Hadoop, сначала проверьте её совместимость вручную.

## Проверка

На edge (`team-01-en`):

```bash
bash ~/data-platforms/hw1/scripts/verify-edge.sh
```

Проверка должна подтвердить, что сервисы работают, все три DataNode имеют нормальный статус, а мёртвых и выводимых из эксплуатации узлов нет. Скрипт также проверяет отсутствие недореплицированных, повреждённых и потерянных блоков. Затем запускает `hdfs fsck /` и ожидает `Status: HEALTHY`.

Для доступа к веб-интерфейсу NameNode запустите команду локально и оставьте терминал открытым:

```bash
ssh -i ~/.ssh/id_ed25519_mts_course -N \
  -L 127.0.0.1:9870:10.1.0.11:9870 team@171.22.72.148
```

Откройте [NameNode](http://127.0.0.1:9870/dfshealth.html) и убедитесь, что видны три живых DataNode без деградации. Туннель работает после ДЗ1 без nginx. Чтобы закрыть его, нажмите `Ctrl+C`.

На `team-01-nn` доступны команды:

```bash
sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf dfsadmin -report
sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf fsck /
sudo journalctl -u hdfs-namenode -u hdfs-secondarynamenode
```

Логи DataNode можно посмотреть командой `sudo journalctl -u hdfs-datanode` на каждом внутреннем узле. Логи Hadoop хранятся в `/var/log/hadoop-hdfs`.

## Файлы

- `cluster.conf`: версия Hadoop, адреса и пакет Java.
- `config/`: настройки HDFS, окружение и список DataNode.
- `systemd/`: только сервисы HDFS.
- `scripts/deploy.sh`: запуск с локальной машины.
- `scripts/deploy-hdfs-edge.sh`: установка с edge и защита существующего кластера.
- `scripts/install-hdfs.sh`: установка на отдельном внутреннем узле.
- `scripts/verify-edge.sh`: проверка HDFS через edge.
- `tests/deploy.sh`: локальные проверки запуска и остановки при ошибке: `bash hw1/tests/deploy.sh` из корня репозитория.
- [verification.txt](verification.txt): результаты проверки на стенде.

При переносе на другой стенд нужно изменить `cluster.conf`, XML и `config/workers`.
