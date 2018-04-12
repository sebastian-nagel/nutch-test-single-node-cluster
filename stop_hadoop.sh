#!/bin/bash

source hadoop_install_config.sh

set -e

# launch Hadoop services
$HADOOP_HOME/sbin/stop-dfs.sh
$HADOOP_HOME/sbin/stop-yarn.sh

