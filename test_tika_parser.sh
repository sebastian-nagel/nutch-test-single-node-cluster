#!/bin/bash

### parse all Tika standard parsers test documents
#
# 1. copy the test documents to the local web server
#    git clone https://github.com/apache/tika.git
#    cd tika
#    mkdir /var/www/html/tika/
#    find tika-parsers/tika-parsers-standard/tika-parsers-standard-modules/*/src/test/resources/test-documents/ -type f | while read f; do cp $f /var/www/html/tika/; done; chmod a+r /var/www/html/tika/*
#
# 2. create a seed list with URLs pointing to the test documents on localhost
#    ls /var/www/html/tika/ | sed 's@^@http://localhost/tika/@' >seeds_tika.txt

export NUTCH_HOME=$(readlink -f $NUTCH_HOME/../deploy)

export LC_ALL=C

function nutch() {
    $NUTCH_HOME/bin/nutch "$@"
}

set -ex

hadoop fs -mkdir -p crawl/seeds_tika/
hadoop fs -copyFromLocal seeds_tika.txt crawl/seeds_tika

nutch freegen crawl/seeds_tika crawl/segments
segment=$(hadoop fs -ls -C crawl/segments/ | sort | tail -n 1)
nutch fetch -Dfetcher.server.delay=.0 $segment -threads 4
nutch parse $segment
