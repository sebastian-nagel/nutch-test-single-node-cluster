#!/bin/bash

source hadoop_install_config.sh

bash -c 'echo "JAVA_HOME=$JAVA_HOME"'

set -x

$HADOOP_HOME/bin/hdfs namenode -format

set -e

# launch Hadoop services
$HADOOP_HOME/sbin/start-dfs.sh 
$HADOOP_HOME/sbin/start-yarn.sh

