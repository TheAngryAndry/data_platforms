# Решения домашних заданий по курсу МТС "Введение в платформы данных".  

- [hw1: HDFS](hw1/README.md): установка Java и Hadoop, NameNode, SecondaryNameNode и трёх DataNode.
- [hw2: YARN и веб-интерфейсы](hw2/README.md): ResourceManager, два NodeManager, JobHistoryServer и nginx поверх кластера из ДЗ1.
- [hw3: HDFS, YARN и Hive](hw3/README.md): HiveServer2, отдельный Metastore с PostgreSQL и автоматическая загрузка данных в партиционированную таблицу.

Папка `hw3` содержит ДЗ1 + ДЗ2 + ДЗ3. Установка на чистых серверах с локальной машины из корня репозитория:

```bash
./hw3/scripts/deploy.sh
```
