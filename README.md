# Решения домашних заданий по курсу МТС "Введение в платформы данных".  

- [hw1: HDFS](hw1/README.md): установка Java и Hadoop, NameNode, SecondaryNameNode и трёх DataNode.
- [hw2: YARN и веб-интерфейсы](hw2/README.md): ResourceManager, два NodeManager, JobHistoryServer и nginx поверх кластера из ДЗ1.

Запуск с локальной машины из корня репозитория:

```bash
./hw1/scripts/deploy.sh
./hw2/scripts/deploy.sh
```
- [hw3: HDFS, YARN и Hive](hw3/README.md): ДЗ1 + ДЗ2 + ДЗ3, включая HiveServer2, Metastore с PostgreSQL и загрузку партиций.

Для установки всех трёх заданий на чистых серверах: `./hw3/scripts/deploy.sh`.
