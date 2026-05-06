Test Apache Nutch on a single-node Hadoop cluster
=================================================

Scripts and configuration to test [Apache Nutch](https://nutch.apache.org/) using OpenJDK 17 in pseudo-distributed mode (single-node Hadoop cluster).

The project has been tested on the following operating systems
* Ubuntu 22.04, 24.04, 26.04
* MacOS Tahoe 26.0.1 (Apple M4 Chip) - Note, install the following package `brew install gnu-tar`

# Nutch and Hadoop version compatibility

Nutch versions are bundled with a specific Hadoop version and also require a specific Java JDK version. The following table gives an overview of version compatibilities. Other combinations may also work, but there is no guarantee.

| Nutch | Hadoop | JDK | Released   |
|:------|:-------|:----|:-----------|
|  1.23 |  3.5.0 |  17 |            |
|  1.22 |  3.4.2 |  11 | 2026-02-12 |
|  1.21 |  3.3.6 |  11 | 2025-07-15 |
|  1.20 |  3.3.6 |  11 | 2024-04-09 |
|  1.19 |  3.3.4 |  11 | 2022-08-22 |
|  1.18 |  3.1.3 |   8 | 2021-01-14 |

If you want to use the single-node cluster setup with previous outdated releases of Nutch and Hadoop, please see the corresponding Git tags `nutch-1.xx`.

# Installation of Hadoop

Please download first a [stable Hadoop binary package](https://hadoop.apache.org/releases.html). Following the configuration and setup of [Hadoop: Setting up a Single Node Cluster](https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/SingleCluster.html) the shell script [install_hadoop.sh](install_hadoop.sh) will install Hadoop and configure it for pseudo-distributed mode:

    sudo ./install_hadoop.sh

Hadoop version and installation path need to be configured in [hadoop_install_config.sh](hadoop_install_config.sh) which is shared by all scripts. After installation, you also may want to source the file to make the Hadoop command-line tools available in your shell:

    . ./hadoop_install_config.sh


# Compile Nutch

Please follow the [Nutch installation description](https://wiki.apache.org/nutch/NutchTutorial#Option_2:_Set_up_Nutch_from_a_source_distribution) to compile Nutch. Or to test the master branch just run:

    git clone https://github.com/apache/nutch.git
    cd nutch/
    # NOTE: need to configure at least http.agent.name in conf/nutch-site.xml
    ant runtime
    cd ..

If compiled point the environment variable `NUTCH_HOME` (`NUTCH_RUNTIME_HOME` also works) to the folder `.../nutch/runtime/deploy/` which is created by `ant runtime`. The Nutch job file `apache-nutch-1.*.job` is expected to be located in this folder.

Please note that you need to recompile if the configuration is changed because configuration files are contained in the job file.


# Start Hadoop services

<details>

<summary>If running on MacOS...</summary>

You must enable Remote Login. To do that you need to grant Full Disk Access to the Terminal application you use to start the Hadoop services. You can check this by executing `sudo systemsetup -getremotelogin`. You should see `Remote Login: On`. If remote login in `Off` follow the steps below

* Open System Settings: go to Apple Menu > `System Settings` (or `System Preferences` on older macOS versions).
* Navigate to Privacy & Security: select `Privacy & Security` > `Full Disk Access`.
* Add Terminal: click the `+` button to add an application.
* Navigate to `Applications` > `Utilities` > `Terminal.app` (or whatever terminal you use), select it, and click `Open`.
* Ensure the toggle next to Terminal is enabled (checked).
* Restart Terminal: quit Terminal (if open) by typing exit or closing the window.
* Reopen Terminal. 
* Now that Terminal has Full Disk Access, try enabling Remote Login: `sudo systemsetup -setremotelogin on`. You should see `Remote Login: On`.
* Confirm the SSH server is running: run `sudo launchctl list | grep ssh`, look for `com.openssh.sshd` in the output. If it’s not running, start it: `sudo launchctl start com.openssh.sshd`

</details>

Run

    ./start_hadoop.sh

To verify whether HDFS and YARN services are running check:
- http://localhost:9870/
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

    hadoop jar $NUTCH_HOME/apache-nutch-*.job org.apache.nutch.crawl.Injector ...

## Automatic Testing of Nutch Core Tools

The script [test_nutch_tools.sh](./test_nutch_tools.sh) can be used to test multiple Nutch core tools in pseudo-distributed mode.

Note: Solr must be up and running in order to run the indexing step with the default configuration. If Solr (or any other indexing backend in a customized configuration) is not installed, please disable the indexing command in the test script.


# Stop Hadoop services

    ./stop_hadoop.sh

