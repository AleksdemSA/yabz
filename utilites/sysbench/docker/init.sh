#!/bin/bash

echo "######## CPU Test ########"
sysbench --test=cpu --cpu-max-prime=20000 run

echo "######## Memory Test ########"
sysbench --test=memory run
