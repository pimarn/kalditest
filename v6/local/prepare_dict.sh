#!/bin/sh

#cut -d ' ' -f 2- lexicon.txt | sed 's/ /\n/g' | sort -u > nonsilence_phones.txt

dict=data/local/dict

#cut -d ' ' -f 2- $dir_dict/lexicon.txt | sed 's/ /\n/g' |grep -v SIL | sort -u > $dir_dict/nonsilence_phones.txt
awk '{$1=""}1' $dict/lexicon.txt |sed 's/ /\n/g' | sort -u | sed '/^$/d' | grep -v SIL > $dict/nonsilence_phones.txt
echo 'SIL' > $dir_dict/silence_phones.txt
echo 'SIL' > $dir_dict/optional_silence.txt
