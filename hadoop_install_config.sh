
HADOOP_VERSION=3.2.1
export HADOOP_HOME=/opt/hadoop/$HADOOP_VERSION

export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/default-java}

# bin/nutch expects that the "hadoop" command is on the PATH
PATH="$HADOOP_HOME/bin:$PATH"
