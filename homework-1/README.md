# HDFS cluster

Автоматизированное развертывание HDFS-кластера Apache Hadoop 3.4.2 с NameNode, SecondaryNameNode и 3 DataNode.

## Инструкция

На локальной машине должны быть доступны `bash`, `ssh`, `scp` и SSH-ключ:

```text
~/.ssh/id_ed25519_mts_course
```

На edge-ноде должен находиться внутренний SSH-ключ:

```text
~/.ssh/team_internal
```

Клонировать репозиторий:

```bash
git clone https://github.com/TheAngryAndry/data_platforms.git
cd data_platforms/homework-1

Параметры кластера находятся в `cluster.env`. В нем указаны версия Hadoop, адрес edge-ноды, внутренние узлы и параметры Java.

Запустить развертывание с локальной машины:

```bash
chmod +x scripts/*.sh
./scripts/deploy-hdfs.sh
```

При запуске скрипт:

1. Копирует конфигурацию и скрипты на edge-ноду.
2. Скачивает Hadoop 3.4.2 и проверяет SHA-512.
3. Передает необходимые файлы на внутренние узлы.
4. Устанавливает OpenJDK 11 и Hadoop.
5. Создает пользователя `hdfs` и необходимые каталоги.
6. Устанавливает конфигурацию Hadoop и systemd-сервисы.
7. Форматирует NameNode при первом запуске.
8. Запускает NameNode, SecondaryNameNode и 3 DataNode.
9. Проверяет состояние кластера.

NameNode, SecondaryNameNode и один DataNode запускаются на `team-01-nn`. Еще два DataNode запускаются на `team-01-00` и `team-01-01`.

Повторный запуск не форматирует уже созданный NameNode и не удаляет данные HDFS.

## Проверка

Проверку можно запустить отдельно с локальной машины:

```bash
./scripts/verify-hdfs.sh
```

Скрипт проверяет:

- состояние HDFS-сервисов
- наличие 3 live DataNode
- отсутствие dead DataNode
- результат `hdfs fsck /`
- отсутствие ошибок в логах HDFS-сервисов

Успешная проверка заканчивается строкой:

```text
PASS: HDFS is healthy; 3 live DataNodes, 0 dead DataNodes
```

## Скрипты

- `scripts/deploy-hdfs.sh` - запуск развертывания с локальной машины
- `scripts/deploy-from-edge.sh` - передача файлов и запуск установки на внутренних узлах
- `scripts/install-node.sh` - установка и настройка Hadoop на отдельном узле
- `scripts/verify-hdfs.sh` - запуск проверки с локальной машины
- `scripts/verify-on-edge.sh` - проверка сервисов, DataNode, `fsck` и логов