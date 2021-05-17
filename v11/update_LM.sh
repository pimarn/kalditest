#!/bin/bash
. ./path.sh || exit 1

lm_order=3 # language model order (n-gram quantity) - 1 is enough for digits grammar


# Removing previously created data (from last run.sh execution)
rm -rf data/lang data/local/dict data/local/tmp


echo "===== PREPARING LANGUAGE DATA ====="
echo
# Needs to be prepared by hand (or using self written scripts):
#
# lexicon.txt           [<word> <phone 1> <phone 2> ...]
# nonsilence_phones.txt [<phone>]
# silence_phones.txt    [<phone>]
# optional_silence.txt  [<phone>]
# Preparing language data
#utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang
#utils/prepare_lang.sh data/local/dict "<SIL>" data/local/lang data/lang
echo
echo "===== LANGUAGE MODEL CREATION ====="
echo "===== MAKING lm.arpa ====="
echo
loc=`which ngram-count`;
if [ -z $loc ]; then
        if uname -a | grep 64 >/dev/null; then
                sdir=$KALDI_ROOT/tools/srilm/bin/i686-m64
        else
                        sdir=$KALDI_ROOT/tools/srilm/bin/i686
        fi
        if [ -f $sdir/ngram-count ]; then
                        echo "Using SRILM language modelling tool from $sdir"
                        export PATH=$PATH:$sdir
        else
                        echo "SRILM toolkit is probably not installed.
                                Instructions: tools/install_srilm.sh"
                        exit 1
        fi
fi
local=data/local
mkdir $local/tmp
ngram-count -order $lm_order -write-vocab $local/tmp/vocab-full.txt -wbdiscount -text $local/corpus.txt -lm $local/tmp/lm.arpa

./prepare_LG.sh lexicon.src $local/tmp/lm.arpa phones.txt data/local/dict data/lang

echo
echo "===== Update LM model finished ====="
echo
