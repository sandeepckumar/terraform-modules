#!/bin/bash
echo "Hello, this is ${env}" > index.html
nohup busybox httpd -f -p ${server-port}