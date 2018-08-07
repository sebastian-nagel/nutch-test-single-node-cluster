#!/bin/bash

export NUTCH_HOME=$(readlink -f $NUTCH_HOME/../deploy)

export LC_ALL=C

function nutch() {
    $NUTCH_HOME/bin/nutch "$@"
}

CYCLES=${CYCLES:-2}

hadoop fs -mkdir -p crawl/seeds
hadoop fs -mkdir -p crawl/crawldbx
hadoop fs -mkdir -p crawl/linkdbx
hadoop fs -mkdir -p crawl/segmentsx
hadoop fs -mkdir -p crawl/webgraphx

set -exo pipefail


echo "https://nutch.apache.org/" >urls.txt
hadoop fs -copyFromLocal -f urls.txt crawl/seeds/
nutch inject crawl/crawldb crawl/seeds/urls.txt
nutch readdb crawl/crawldb -url "https://nutch.apache.org/"

echo "https://www.sitemaps.org/sitemap.xml" >sitemaps.txt
hadoop fs -copyFromLocal -f sitemaps.txt crawl/seeds/
nutch sitemap crawl/crawldb -sitemapUrls crawl/seeds/sitemaps.txt


$NUTCH_HOME/bin/crawl --size-fetchlist 10 --time-limit-fetch 2 --num-threads 5 --num-slaves 2 crawl  $CYCLES

echo "http://www.example.org/" >freegen.txt
echo "http://this-domain-does-not-exist/" >>freegen.txt
hadoop fs -copyFromLocal -f freegen.txt crawl/seeds/
nutch freegen crawl/seeds/freegen.txt crawl/segments
segment=$(hadoop fs -ls -C crawl/segments/ | sort | tail -n 1)
nutch fetch $segment -threads 1
nutch parse $segment
nutch updatedb crawl/crawldb $segment
nutch invertlinks crawl/linkdb $segment -noNormalize -noFilter

### LinkDb
nutch readlinkdb crawl/linkdb -dump crawl/linkdbx/dump -regex '^https?://'
hadoop fs -text crawl/linkdbx/dump/part-r-00000
nutch mergelinkdb crawl/linkdbx/merge crawl/linkdb

### HostDb
nutch updatehostdb -hostdb crawl/hostdb -crawldb crawl/crawldb -checkAll
nutch readhostdb crawl/hostdb -get "nutch.apache.org"
nutch readhostdb crawl/hostdb crawl/crawldbx/hostdump -dumpHostnames
hadoop fs -text crawl/crawldbx/hostdump/part-m-00000

### CrawlDb tools
nutch readdb crawl/crawldb -stats
nutch readdb crawl/crawldb -dump crawl/crawldbx/dump
hadoop fs -text crawl/crawldbx/dump/part-r-00000
nutch readdb crawl/crawldb -dump crawl/crawldbx/dumpcsv -format csv
hadoop fs -text crawl/crawldbx/dumpcsv/part-r-00000
nutch readdb crawl/crawldb -topN 50 crawl/crawldbx/topn

nutch mergedb crawl/crawldbx/merge crawl/crawldb

nutch dedup crawl/crawldb

### Segment tools
nutch mergesegs crawl/segmentsx/merge -dir crawl/segments
nutch readseg -list -dir crawl/segments
segment=$(hadoop fs -ls -C crawl/segmentsx/merge/ | sort | tail -n 1)
nutch readseg -dump $segment crawl/segmentsx/merge-dump
hadoop fs -text crawl/segmentsx/merge-dump/dump
nutch readseg -get $segment "https://nutch.apache.org/"

### Solr indexing
nutch index crawl/crawldb -linkdb crawl/linkdb -dir crawl/segments
nutch clean crawl/crawldb


### webgraph
# initial creation
nutch webgraph   -webgraphdb crawl/webgraph -segmentDir crawl/segments
nutch linkrank   -webgraphdb crawl/webgraph
nutch nodedumper -webgraphdb crawl/webgraph -scores -output crawl/webgraphx/nodes

### warc
nutch warc crawl/warc -dir crawl/segments
