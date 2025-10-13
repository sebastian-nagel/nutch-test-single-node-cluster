
HADOOP_VERSION=3.4.2
export HADOOP_HOME=/opt/hadoop/$HADOOP_VERSION

export JAVA_HOME=${JAVA_HOME:-/opt/homebrew/opt/openjdk@11}

# bin/nutch expects that the "hadoop" command is on the PATH
PATH="$HADOOP_HOME/bin:$PATH"
