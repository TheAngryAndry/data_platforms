export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=/etc/hadoop/conf
export HADOOP_LOG_DIR=/var/log/hadoop-hdfs
export HADOOP_PID_DIR=/run/hadoop-hdfs

# The course VMs have about 3.8 GiB of RAM each.
export HDFS_NAMENODE_OPTS="-Xms512m -Xmx1024m ${HDFS_NAMENODE_OPTS:-}"
export HDFS_DATANODE_OPTS="-Xms256m -Xmx512m ${HDFS_DATANODE_OPTS:-}"
export HDFS_SECONDARYNAMENODE_OPTS="-Xms256m -Xmx512m ${HDFS_SECONDARYNAMENODE_OPTS:-}"
