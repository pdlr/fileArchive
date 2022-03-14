#!/bin/bash

TARGET=/backup
for dn in Monday Tuesday Wednesday Thursday Friday Saturday Sunday monthly semiannual annual; do
    DIRECTORY=$TARGET/tar_$dn
    mkdir $DIRECTORY
    chmod 700 $DIRECTORY
    chown root.root $DIRECTORY
done
