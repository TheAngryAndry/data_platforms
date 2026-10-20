from pyspark.sql import SparkSession, functions as F

spark = (
    SparkSession.builder.appName("hw4-daily-sales")
    .config("spark.sql.ansi.enabled", "true")
    .getOrCreate()
)
assert spark.sparkContext.master == "yarn"

sales = (
    spark.read.option("header", True).option("mode", "FAILFAST")
    .csv("hdfs://team-01-nn:8020/user/team/hw4/input/sales.csv")
    .select(
        F.to_date("sale_date").alias("sale_date"),
        F.col("quantity").cast("int").alias("quantity"),
        F.col("unit_price").cast("decimal(10,2)").alias("unit_price"),
    )
    .withColumn("amount", F.col("quantity") * F.col("unit_price"))
)
daily = sales.groupBy("sale_date").agg(
    F.count("*").alias("orders"),
    F.sum("quantity").alias("quantity"),
    F.sum("amount").cast("decimal(20,2)").alias("revenue"),
)
daily.write.mode("overwrite").partitionBy("sale_date").parquet(
    "hdfs://team-01-nn:8020/user/team/hw4/daily_sales"
)
spark.stop()
