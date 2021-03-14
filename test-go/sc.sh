#!/bin/bash

#for x in exp/*/decode*; do [ -d  ] && grep WER /wer_* | utils/best_wer.sh; done
for x in exp/*/decode*; 
do [ -d x ]
	echo $x
	grep WER $x/wer_* | utils/best_wer.sh; 
done
