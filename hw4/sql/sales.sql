CREATE DATABASE IF NOT EXISTS hw3;
CREATE EXTERNAL TABLE IF NOT EXISTS hw3.sales (
  sale_id BIGINT,
  product STRING,
  quantity INT,
  unit_price DECIMAL(10,2)
)
PARTITIONED BY (sale_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/hive/warehouse-external/hw3/sales';

LOAD DATA LOCAL INPATH '/var/lib/hive/import/sales-2026-10-18.csv'
OVERWRITE INTO TABLE hw3.sales PARTITION (sale_date='2026-10-18');
LOAD DATA LOCAL INPATH '/var/lib/hive/import/sales-2026-10-19.csv'
OVERWRITE INTO TABLE hw3.sales PARTITION (sale_date='2026-10-19');
