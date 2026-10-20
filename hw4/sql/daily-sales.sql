CREATE DATABASE IF NOT EXISTS hw4;
CREATE EXTERNAL TABLE IF NOT EXISTS hw4.daily_sales (
  orders BIGINT,
  quantity BIGINT,
  revenue DECIMAL(20,2)
)
PARTITIONED BY (sale_date DATE)
STORED AS PARQUET
LOCATION '/user/team/hw4/daily_sales';

MSCK REPAIR TABLE hw4.daily_sales;
