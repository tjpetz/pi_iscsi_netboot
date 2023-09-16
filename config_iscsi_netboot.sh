#!/bin/bash

SERIAL=$(cat /proc/cpuinfo | grep Serial | head -n 1 | cut -d : -f 2 | sed 's/ 10000000//')
IQN=$(iscsi-iname)

echo "Serial: $SERIAL"
echo "IQN: $IQN"




