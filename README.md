# Решения домашних заданий по курсу МТС "Введение в платформы данных".  

- [hw1: HDFS](hw1/README.md): установка Java и Hadoop, NameNode, SecondaryNameNode и трёх DataNode.
- [hw2: YARN и веб-интерфейсы](hw2/README.md): ResourceManager, два NodeManager, JobHistoryServer и nginx поверх кластера из ДЗ1.
- [hw3: HDFS, YARN и Hive](hw3/README.md): HiveServer2, отдельный Metastore с PostgreSQL и автоматическая загрузка данных в партиционированную таблицу.
- [hw4: Spark под YARN](hw4/README.md): чтение HDFS, трансформации, Parquet и проверка таблицы через Beeline.

Папка `hw3` содержит ДЗ1 + ДЗ2 + ДЗ3. Установка на чистых серверах с локальной машины из корня репозитория:

```bash
./hw3/scripts/deploy.sh
```

`hw3` ещё на ревью, поэтому `hw4` пока содержит только ДЗ4 и запускается поверх готового кластера:

```bash
./hw4/scripts/deploy-spark.sh
```

После ревью объединить `hw3` и `hw4` в `hw4`: перед сдачей в ней должны быть ДЗ1 + ДЗ2 + ДЗ3 + ДЗ4. При объединении перенести исправление адреса DataNode из `hw4/scripts/fix-hdfs-address.sh` в настройку HDFS.
