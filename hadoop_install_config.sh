
HADOOP_VERSION=3.4.2
HADOOP_HOME=/opt/hadoop/$HADOOP_VERSION

if ! [ -d "$JAVA_HOME" ]; then
    if [ -d /opt/homebrew/opt/openjdk@11 ]; then
        # MacOS
        JAVA_HOME=/opt/homebrew/opt/openjdk@11
    elif [ -d /usr/lib/jvm/java-11-openjdk-amd64 ]; then
        # Ubuntu Linux
        JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
    else
        echo "Please configure JAVA_HOME !"
        echo "If Java is installed, you may try to run"
        echo "  java -XshowSettings:properties -version 2>&1 | grep java.home"
        echo "to figure out the right path to JAVA_HOME."
    fi
fi

export JAVA_HOME
export HADOOP_HOME

# bin/nutch expects that the "hadoop" command is on the PATH
PATH="$HADOOP_HOME/bin:$PATH"
