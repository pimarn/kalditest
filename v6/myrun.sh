#!/usr/bin/env bash

. ./path.sh

model_dir=model
tmp=data/local/tmp
dict=data/local/dict
lang=data/lang

rm -rf $dict $lang

[ ! -d $tmp ] && mkdir -p $tmp


#echo "=== Prepare Dict ==="
#echo
#utils/prepare_lang.sh --position-dependent-phones false $dict "<SIL>" $tmp data/lang

#Create LM
echo "=== Create LM ==="
echo
#ngram-count -order 3 -write-vocab $tmp/vocab-full.txt -wbdiscount -text $model_dir/dic5k.formatted.txt  -lm $tmp/lm.arpa

ngram-count -order 4 -write-vocab $tmp/vocab-full.txt -wbdiscount -text $model_dir/dic5k.formatted.txt -ukndiscount 4 -lm $tmp/lm.arpa

#arpa2fst --disambig-symbol=#0 --read-symbol-table=data/lang/words.txt $tmp/lm.arpa data/lang/G.fst

#Prepare model

if [ ! -f $model_dir/model-5 ]; then
	echo "=== Create Model ==="
	cd $model_dir
	g2p.py --train dic5k.formatted.txt --devel 5% --encoding UTF-8 --write-model model-1
	g2p.py --model model-1 --ramp-up --train dic5k.formatted.txt --devel 5% --encoding UTF-8 --write-model model-2
	g2p.py --model model-2 --ramp-up --train dic5k.formatted.txt --devel 5% --encoding UTF-8 --write-model model-3
	g2p.py --model model-3 --ramp-up --train dic5k.formatted.txt --devel 5% --encoding UTF-8 --write-model model-4
	g2p.py --model model-4 --ramp-up --train dic5k.formatted.txt --devel 5% --encoding UTF-8 --write-model model-5
	cd ..
fi
  
#Gen phoneme
echo "=== Create Lexicon ==="
echo
g2p.py --model $model_dir/model-5 --encoding UTF-8 --apply $model_dir/testlex.txt > g2plex.txt


#./prepare_LG.sh data/local/lexicon.txt $tmp/lm.arpa exp/chain/tree_a_sp/phones.txt data/local/dict data/lang

echo "=== Prepare LG ==="
echo
./prepare_LG.sh g2plex.txt $tmp/lm.arpa exp/chain/tree_a_sp/phones.txt $dict $lang

echo "=== Make Graph ==="
echo
utils/mkgraph.sh --self-loop-scale 1.0 data/lang exp/chain/tree_a_sp exp/chain/tree_a_sp/graph


echo "=== Decode ==="
echo
rm -rf exp/chain/tdnn1r_sp_online/decode_test

steps/online/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 --nj 1 exp/chain/tree_a_sp/graph data/test exp/chain/tdnn1r_sp_online/decode_test

#grep WER exp/chain/tdnn1r_sp_online/decode_test/wer*

echo "=== Done ==="