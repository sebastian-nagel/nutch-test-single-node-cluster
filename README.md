Test Apache Nutch on a single-node Hadoop cluster
=================================================

Scripts and configuration to test [Apache Nutch]() on Ubuntu 16.04 in pseudo-distributed mode (single-node Hadoop cluster).


# Installation of Hadoop

Please download first a [stable Hadoop binary package](https://hadoop.apache.org/releases.html). Following the configuration and setup of [Hadoop: Setting up a Single Node Cluster](https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/SingleCluster.html) the shell script [install_hadoop.sh](install_hadoop.sh) will install Hadoop and configure it for pseudo-distributed mode:

    sudo ./install_hadoop.sh

Hadoop version and installation path need to be configured in [hadoop_install_config.sh](hadoop_install_config.sh) which is shared by all scripts. You also may want to source the file to make the command-line tools available in your shell:

    . ./hadoop_install_config.sh


# Compile Nutch

Please follow the [Nutch installation description](https://wiki.apache.org/nutch/NutchTutorial#Option_2:_Set_up_Nutch_from_a_source_distribution) to compile Nutch. Or to test the master branch just run:

    git clone https://github.com/apache/nutch.git
    cd nutch/
    # NOTE: need to configure at least http.agent.name in conf/nutch-site.xml
    ant runtime
    cd ..

If compiled point the environment variable `NUTCH_HOME` (`NUTCH_RUNTIME_HOME` also works) to the folder `.../runtime/deploy/` which is created by `ant runtime`. The Nutch job file `apache-nutch-1.*.job` is expected to be located in this folder.

Please note that you need to recompile if the configuration is changed because configuration files are contained in the job file.


# Start Hadoop services

Run

    ./start_hadoop.sh

To verify whether HDFS and YARN services are running check:
- http://localhost:50070/
- http://localhost:8088/cluster/apps/RUNNING

Alternatively, check the services from command-line

    . ./hadoop_install_config.sh   # adds $HADOOP_HOME/bin to PATH
    
    hdfs dfsadmin -report
    
    yarn top

Note: with the default configuration, the Hadoop files system is stored in `/tmp/hadoop-$USER/dfs/` and probably is not preserved over system restarts. That's an acceptable setup for testing but not for any production environment!


# Test Nutch

First, copy your seed URL file to HDFS:

    hadoop fs -mkdir -p /user/$USER/seeds
    hadoop fs -copyFromLocal -f mySeedUrls.txt seeds/
    hadoop fs -ls  # list content of /user/$USER/
      drwxr-xr-x   - user hadoop          0 2018-04-12 11:37 seeds


Second, let Nutch create a CrawlDb and inject your seed URLs:

    ./run_nutch.sh inject crawldb/ seeds/

and continue with fetch list generation and so on:

    ./run_nutch.sh generate crawldb/ segments/


The script [run_nutch.sh](./run_nutch.sh) is just for convenience - if everything is properly set up, you could just run `$NUTCH_HOME/bin/nutch` or even `$NUTCH_HOME/bin/crawl`. Alternatively, you can launch Nutch jobs the "normal" way Hadoop MapReduce jobs are launched, e.g.

    hadoop jar $NUTCH_HOME/apache-nutch-1.15-SNAPSHOT.job org.apache.nutch.crawl.Injector ...


# Stop Hadoop services

    ./stop_hadoop.sh
