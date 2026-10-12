# Платформы данных: team-01

- [hw1: HDFS](hw1/README.md): установка Java и Hadoop, NameNode, SecondaryNameNode и трёх DataNode.
- [hw2: YARN и веб-интерфейсы](hw2/README.md): ResourceManager, два NodeManager, JobHistoryServer и nginx поверх кластера из ДЗ1.

Запуск с локальной машины из корня репозитория:

```bash
./hw1/scripts/deploy.sh
./hw2/scripts/deploy.sh
```

`hw1` содержит всё для установки HDFS. `hw2` добавляет второе задание к работающему кластеру и останавливается на чистых серверах до установки. Повторно выполнять ДЗ1 или хранить его исходники рядом для запуска ДЗ2 не нужно.

Скрипты устанавливают ПО на серверах `team-01`. На edge исходники ДЗ1 копируются в `~/hw1`, ДЗ2 в `~/data-platforms/hw2`.
