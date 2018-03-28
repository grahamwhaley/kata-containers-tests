#!/bin/bash

set -x

# Delete the index if it already exists
echo ">>> DELETING"
curl -X "DELETE" 'http://192.168.0.131:9200/test2'

echo ">>> CREATING"
# Send the mapping and create the index
#curl -XPUT -H 'Content-Type: application/json' 'http://192.168.0.131:9200/test2' -d '@t.m.json'
curl -XPUT -H 'Content-Type: application/json' 'http://192.168.0.131:9200/test2' -d '@test2.mapping.json'

echo ">>> VERIFYING"
# get the current mapping
curl 'http://192.168.0.131:9200/test2/_mapping'
