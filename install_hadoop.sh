#!/bin/bash

# install Hadoop
# - default: install globally (run as user root)

source hadoop_install_config.sh

set -x
set -e

tgz=hadoop-$HADOOP_VERSION.tar.gz
if ! [ -e $tgz ]; then
    echo "Please download the binary Hadoop package $tgz from"
    echo "  https://hadoop.apache.org/releases.html"
    echo "and place it in the current directory"
    exit 1
fi

tgz=$PWD/$tgz
mkdir -p $HADOOP_HOME
cd $HADOOP_HOME
tar --transform "s@^hadoop-$HADOOP_VERSION@.@" -xzf $tgz
cd -

cp -v etc/hadoop/* $HADOOP_HOME/etc/hadoop/

# add JAVA_HOME to hadoop-env.sh
sed -i 's@^export JAVA_HOME=\${JAVA_HOME}@export JAVA_HOME=${JAVA_HOME:-'"$JAVA_HOME"'}@' $HADOOP_HOME/etc/hadoop/hadoop-env.sh
grep JAVA_HOME $HADOOP_HOME/etc/hadoop/hadoop-env.sh

mkdir $HADOOP_HOME/logs
chmod a+rxwt $HADOOP_HOME/logs

chown -R root:root $HADOOP_HOME
find $HADOOP_HOME/ -type d -exec chmod a+rx '{}' \;
find $HADOOP_HOME/ -type f -exec chmod a+r '{}' \;
chmod a+x $HADOOP_HOME/sbin/*.sh
chmod a+x $HADOOP_HOME/bin/*

