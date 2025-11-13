#!/bin/bash

infile=$1
nr_lines=`wc -l ${infile} | awk '{print $1}'`

while [ ${infile} ];
do
  clear
  echo ""
  q=`seq 1 2 ${nr_lines} | shuf -n 1` # Questions are the odd lines
  a=$((q+1)) # Answers are the even lines
  awk -v Q=${q} '{if(NR==Q) print $0}' ${infile}
  read
  awk -v A=${a} '{if(NR==A) print $0}' ${infile}
  read
done

exit 0
