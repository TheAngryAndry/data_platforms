# Решения домашних заданий по курсу МТС "Введение в платформы данных".

- [hw1: HDFS](hw1/README.md): установка Java и Hadoop, NameNode, SecondaryNameNode и трёх DataNode.
- [hw2: YARN и веб-интерфейсы](hw2/README.md): ResourceManager, два NodeManager, JobHistoryServer и nginx поверх кластера из ДЗ1.
- [hw3: HDFS, YARN и Hive](hw3/README.md): HiveServer2, отдельный Metastore с PostgreSQL и загрузка данных в партиционированную таблицу.
- [hw4: HDFS, YARN, Hive и Spark](hw4/README.md): все четыре ДЗ, чтение HDFS, трансформации, Parquet и проверка таблицы через Beeline.

Папка `hw3` содержит ДЗ1 + ДЗ2 + ДЗ3. Папка `hw4` содержит ДЗ1 + ДЗ2 + ДЗ3 + ДЗ4 и не зависит от соседних папок. Полная установка ДЗ4 на чистых серверах с локальной машины из корня репозитория:

```bash
./hw4/scripts/deploy.sh
```

Если HDFS, YARN и Hive уже работают, запустите только Spark:

```bash
./hw4/scripts/deploy-spark.sh
```

Инструкции, ожидаемый результат и проверки находятся в [hw4/README.md](hw4/README.md).
