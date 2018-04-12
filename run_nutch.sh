#!/bin/bash

source hadoop_install_config.sh

if [ -z "$NUTCH_HOME" ]; then
    if [ -n "$NUTCH_RUNTIME_HOME" ]; then
        NUTCH_HOME="$NUTCH_RUNTIME_HOME"
    fi
    echo "NUTCH_HOME needs to be defined"
    exit 1
fi

if ! [ -f "${NUTCH_HOME}"/*nutch*.job ]; then
    if [ -f "${NUTCH_HOME}"/../deploy/*nutch*.job ]; then
        echo "Redefining local NUTCH_HOME ($NUTCH_HOME)"
        NUTCH_HOME="$NUTCH_HOME/../deploy"
        echo "NUTCH_HOME=$NUTCH_HOME"
    else
        echo "No Nutch job file found in NUTCH_HOME ($NUTCH_HOME)"
        exit 1
    fi
fi

echo "Running Nutch from $NUTCH_HOME"

exec $NUTCH_HOME/bin/nutch "$@"
