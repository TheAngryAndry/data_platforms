# HDFS cluster

Установка Apache Hadoop 3.4.2 с NameNode, SecondaryNameNode и тремя DataNode на чистые Ubuntu/Debian VM.

На локальной машине нужны `bash`, `ssh`, `scp` и ключ `~/.ssh/id_ed25519_mts_course`.
На edge-ноде нужны `bash`, `curl`, `ssh`, `scp` и ключ `~/.ssh/team_internal`.
Пользователь `team` должен иметь доступ к внутренним узлам и `sudo` без пароля.

Из корня репозитория:

```bash
cd homework-1
./scripts/deploy.sh
```

Скрипт копирует папку `homework-1` в домашний каталог на edge, скачивает Hadoop и передает папку на внутренние узлы. На каждом узле устанавливаются Java и Hadoop, создаются пользователь `hdfs`, каталоги, конфигурация и systemd-сервисы. Затем форматируется NameNode и запускаются сервисы.

NameNode, SecondaryNameNode и один DataNode работают на `team-01-nn`. Еще два DataNode — на `team-01-00` и `team-01-01`.

Параметры установки находятся в `cluster.env`, настройки HDFS — в `config/`, systemd-сервисы — в `systemd/`.

Скрипты предназначены для первоначальной установки: повторный запуск остановится, если группа `hadoop` уже существует. Форматирование выполняется без `-force`. Проверок состояния кластера и ожидания готовности сервисов нет; `set -e` останавливает выполнение при ошибке команды.

- `scripts/deploy.sh` — запуск с локальной машины.
- `scripts/deploy-edge.sh` — скачивание Hadoop, копирование файлов и запуск команд на узлах.
- `scripts/install.sh` — установка Java, Hadoop и конфигурации на узле.
