#!/bin/bash

TAKTUK_CONNECTOR='oarsh'
PROGNAME=$HOME/mdrAnalysis.R

NB_COMPUTING_RESOURCES=`wc -l $OAR_NODEFILE | cut -d " " -f 1`

echo "=== Resources used for exec of ${PROGNAME}"

cat $OAR_NODEFILE

kash -M ${OAR_NODEFILE} -- ${PROGNAME} \$TAKTUK_COUNT \$TAKTUK_RANK
