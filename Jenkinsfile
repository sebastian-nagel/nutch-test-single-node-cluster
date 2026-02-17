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

                    echo "=== Formatting HDFS namenode ==="
                    hdfs namenode -format -force

                    echo "=== Starting HDFS daemons directly (no SSH) ==="
                    hdfs --daemon start namenode
                    hdfs --daemon start datanode

                    echo "=== Starting YARN daemons directly (no SSH) ==="
                    yarn --daemon start resourcemanager
                    yarn --daemon start nodemanager

                    echo "=== Waiting for daemons to initialize ==="
                    sleep 10

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
