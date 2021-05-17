#!/bin/sh

awk '{for (i=2;i<=NF;i++) printf ("%s\n",$i)}' $1
