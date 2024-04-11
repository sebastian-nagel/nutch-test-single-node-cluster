
HADOOP_VERSION=3.4.0
export HADOOP_HOME=/opt/hadoop/$HADOOP_VERSION

export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-amd64}

# bin/nutch expects that the "hadoop" command is on the PATH
PATH="$HADOOP_HOME/bin:$PATH"
