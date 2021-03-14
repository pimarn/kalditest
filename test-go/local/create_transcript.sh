#!/usr/bin/env bash

txt_file=$1

awk '{$1=""}1' $txt_file | sed 's/^ //g'
