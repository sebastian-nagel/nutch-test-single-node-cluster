pipeline {
    agent { label 'ubuntu' }
    parameters {
        string(name: 'PULL_REQUEST_ID', defaultValue: '', description: 'Apache Nutch Pull Request ID (e.g., 866). Leave empty to use master branch.')
        string(name: 'EMAIL_RECIPIENT', defaultValue: '', description: 'Email address for job result notification (optional)')
        string(name: 'HADOOP_VERSION', defaultValue: '3.4.2', description: 'Hadoop version to download (e.g., 3.4.2)')
    }
    environment {
        HADOOP_HOME = "${WORKSPACE}/hadoop-${params.HADOOP_VERSION}"
        NUTCH_HOME = "${WORKSPACE}/nutch/runtime/deploy"
        JAVA_HOME = "/home/jenkins/tools/java/latest17"
        CACHE_DIR = "${WORKSPACE}/cache/hadoop"
        HADOOP_TAR = "hadoop-${params.HADOOP_VERSION}.tar.gz"
        HADOOP_CHECKSUM = "hadoop-${params.HADOOP_VERSION}.tar.gz.sha512"
        HADOOP_DIR = "hadoop-${params.HADOOP_VERSION}"
        DOWNLOAD_URL = "https://dlcdn.apache.org/hadoop/common/hadoop-${params.HADOOP_VERSION}"
        PATH = "${WORKSPACE}/hadoop-${params.HADOOP_VERSION}/bin:${WORKSPACE}/hadoop-${params.HADOOP_VERSION}/sbin:${WORKSPACE}/nutch/runtime/deploy/bin:${env.PATH}"
    }
    stages {
        stage('Checkout nutch-test-single-node-cluster') {
            steps {
                git url: 'https://github.com/sebastian-nagel/nutch-test-single-node-cluster.git', branch: 'master'
            }
        }
        stage("Restore Hadoop from Cache") {
            steps {
                sh """
                    echo "Creating cache directory if it doesn't exist..."
                    mkdir -p ${CACHE_DIR}
                    
                    # Restore cached files
                    if [ -f "${CACHE_DIR}/${HADOOP_TAR}" ]; then
                        echo "Restoring Hadoop tarball from cache..."
                        cp "${CACHE_DIR}/${HADOOP_TAR}" .
                    fi
                    
                    if [ -f "${CACHE_DIR}/${HADOOP_CHECKSUM}" ]; then
                        echo "Restoring checksum from cache..."
                        cp "${CACHE_DIR}/${HADOOP_CHECKSUM}" .
                    fi
                    
                    if [ -d "${CACHE_DIR}/${HADOOP_DIR}" ]; then
                        echo "Restoring Hadoop directory from cache..."
                        cp -r "${CACHE_DIR}/${HADOOP_DIR}" .
                    fi
                """
            }
        }
        stage("Download and Install Hadoop") {
            steps {
                script {
                    def stageName = "Download and Install Hadoop ${params.HADOOP_VERSION}"
                    stage(stageName) {
                        sh """
                            # Download tarball if it doesn't exist
                            if [ ! -f "${HADOOP_TAR}" ]; then
                                echo "Downloading Hadoop ${params.HADOOP_VERSION}..."
                                wget ${DOWNLOAD_URL}/${HADOOP_TAR}
                                
                                echo "Downloading checksum file..."
                                wget ${DOWNLOAD_URL}/${HADOOP_CHECKSUM}
                            else
                                echo "Hadoop tarball already exists (restored from cache)"
                                
                                if [ ! -f "${HADOOP_CHECKSUM}" ]; then
                                    echo "Downloading checksum file..."
                                    wget ${DOWNLOAD_URL}/${HADOOP_CHECKSUM}
                                fi
                            fi
                            
                            # Verify checksum
                            echo "Verifying SHA-512 checksum..."
                            if sha512sum -c ${HADOOP_CHECKSUM}; then
                                echo "Checksum verification PASSED"
                            else
                                echo "Checksum verification FAILED"
                                echo "Removing corrupted tarball..."
                                rm -f ${HADOOP_TAR}
                                # Also remove from cache
                                rm -f ${CACHE_DIR}/${HADOOP_TAR}
                                exit 1
                            fi
                            
                            # Update cache with latest files
                            echo "Updating cache..."
                            cp -u ${HADOOP_TAR} ${CACHE_DIR}/
                            cp -u ${HADOOP_CHECKSUM} ${CACHE_DIR}/
                            
                            # Update Hadoop configuration (Ubuntu-compatible sed)
                            sed -i "s|^HADOOP_VERSION=.*|HADOOP_VERSION=${params.HADOOP_VERSION}|" hadoop_install_config.sh
                            sed -i "s|^HADOOP_HOME=.*|HADOOP_HOME=${HADOOP_HOME}|" hadoop_install_config.sh
                            
                            # Comment out chown/sudo chown line before running install script
                            echo "Commenting out chown command in install_hadoop.sh..."
                            sed -i 's|^sudo chown|#sudo chown|' install_hadoop.sh
                            
                            ./install_hadoop.sh
                            
                            if [ ! -d "${CACHE_DIR}/${HADOOP_DIR}" ]; then
                                echo "Caching extracted Hadoop directory..."
                                cp -r ${HADOOP_HOME} ${CACHE_DIR}/
                            fi
                            . ./hadoop_install_config.sh
                        """
                    }
                }
            }
        }
        stage('Clone and Build Nutch') {
            steps {
                dir("nutch") {
                    git url: 'https://github.com/apache/nutch.git', branch: 'master'
                    sh """
                        if [ -n "${params.PULL_REQUEST_ID}" ]; then
                            git fetch origin pull/${params.PULL_REQUEST_ID}/head:pr-${params.PULL_REQUEST_ID}
                            git checkout pr-${params.PULL_REQUEST_ID}
                        else
                            git checkout master
                        fi
                        
                        sed -i '/<name>http.agent.name<\\/name>/,/<\\/property>/d' conf/nutch-site.xml.template
                        sed -i '/<\\/configuration>/i\\
                          <property>\\
                            <name>http.agent.name</name>\\
                            <value>Apache Nutch Single Node Smoke Test</value>\\
                          </property>' conf/nutch-site.xml.template
                        ant runtime
                    """
                }
            }
        }
        stage('Start Hadoop Services') {
            steps {
                sh '''
                    echo "=== Hadoop configuration ==="
                    cat ${HADOOP_HOME}/etc/hadoop/core-site.xml
                    cat ${HADOOP_HOME}/etc/hadoop/hdfs-site.xml
                    cat ${HADOOP_HOME}/etc/hadoop/yarn-site.xml
                    cat ${HADOOP_HOME}/etc/hadoop/mapred-site.xml

                    echo "=== Allow DataNode to register in single-node/CI (hostname check off) ==="
                    grep -q 'dfs.namenode.datanode.registration.ip-hostname-check' ${HADOOP_HOME}/etc/hadoop/hdfs-site.xml || sed -i '/<\\/configuration>/i\\
  <property>\\
    <name>dfs.namenode.datanode.registration.ip-hostname-check</name>\\
    <value>false</value>\\
  </property>' ${HADOOP_HOME}/etc/hadoop/hdfs-site.xml

                    echo "=== Formatting HDFS namenode ==="
                    hdfs namenode -format -force

                    echo "=== Clearing DataNode storage (clusterID must match freshly formatted NameNode) ==="
                    rm -rf /tmp/hadoop-jenkins/dfs/data

                    echo "=== Starting HDFS daemons directly (no SSH) ==="
                    hdfs --daemon start namenode
                    hdfs --daemon start datanode

                    echo "=== Starting YARN daemons directly (no SSH) ==="
                    yarn --daemon start resourcemanager
                    yarn --daemon start nodemanager

                    echo "=== Waiting for daemons to initialize ==="
                    sleep 5

                    echo "=== Waiting for at least one HDFS DataNode to register ==="
                    HDFS_WAIT_TIMEOUT=90
                    HDFS_WAIT_INTERVAL=3
                    elapsed=0
                    while [ $elapsed -lt $HDFS_WAIT_TIMEOUT ]; do
                      if hdfs dfsadmin -report 2>/dev/null | grep -qE "Live datanodes \\([1-9][0-9]*\\)"; then
                        echo "HDFS is ready (DataNode registered after ${elapsed}s)."
                        break
                      fi
                      echo "Waiting for DataNode to register... (${elapsed}s / ${HDFS_WAIT_TIMEOUT}s)"
                      sleep $HDFS_WAIT_INTERVAL
                      elapsed=$((elapsed + HDFS_WAIT_INTERVAL))
                    done
                    if [ $elapsed -ge $HDFS_WAIT_TIMEOUT ]; then
                      echo "ERROR: No DataNode registered after ${HDFS_WAIT_TIMEOUT}s. HDFS report:"
                      hdfs dfsadmin -report || true
                      echo "=== DataNode process check ==="
                      jps -l 2>/dev/null | grep -i datanode || ps aux | grep -i datanode | grep -v grep || true
                      echo "=== Last 200 lines of DataNode log ==="
                      ls -la ${HADOOP_HOME}/logs/*datanode*.log 2>/dev/null || true
                      tail -n 200 ${HADOOP_HOME}/logs/*datanode*.log 2>/dev/null || echo "No DataNode log found under ${HADOOP_HOME}/logs/"
                      echo "=== Last 100 lines of NameNode log ==="
                      tail -n 100 ${HADOOP_HOME}/logs/*namenode*.log 2>/dev/null || echo "No NameNode log found under ${HADOOP_HOME}/logs/"
                      exit 1
                    fi

                    echo "=== Verifying Hadoop daemons ==="
                    hdfs dfsadmin -report || echo "WARNING: HDFS report failed"
                    yarn node -list || echo "WARNING: YARN node list failed"
                '''
            }
        }
        stage('Smoke Test Nutch Core Tools') {
            steps {
                sh """
                    sed -i '/nutch index crawl\\/crawldb -linkdb crawl\\/linkdb -dir crawl\\/segments/s/^/#/' test_nutch_tools.sh
                    sed -i '/nutch clean crawl\\/crawldb/s/^/#/' test_nutch_tools.sh
                    ./test_nutch_tools.sh
                """
            }
        }
        stage('Stop Hadoop Services') {
            steps {
                sh '''
                    echo "=== Stopping YARN daemons ==="
                    yarn --daemon stop nodemanager || true
                    yarn --daemon stop resourcemanager || true

                    echo "=== Stopping HDFS daemons ==="
                    hdfs --daemon stop datanode || true
                    hdfs --daemon stop namenode || true
                '''
            }
        }
    }
    post {
        always {
            script {
                if (params.EMAIL_RECIPIENT != '') {
                    emailext (
                        to: params.EMAIL_RECIPIENT,
                        subject: "Jenkins Job ${env.JOB_NAME} #${env.BUILD_NUMBER} - ${currentBuild.currentResult}",
                        body: """
                            Build ${currentBuild.currentResult}
                            Job: ${env.JOB_NAME}
                            Build Number: ${env.BUILD_NUMBER}
                            Pull Request: ${params.PULL_REQUEST_ID ?: 'master branch'}
                            Hadoop Version: ${params.HADOOP_VERSION}
                            Build URL: ${env.BUILD_URL}
                        """
                    )
                }
            }
        }
    }
}