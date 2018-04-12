#!/bin/bash

source hadoop_install_config.sh

set -e

# launch Hadoop services
$HADOOP_HOME/sbin/start-dfs.sh 
$HADOOP_HOME/sbin/start-yarn.sh

