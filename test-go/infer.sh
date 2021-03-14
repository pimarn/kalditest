#!/bin/bash

train_cmd='run.pl'
decode_cmd='run.pl'
nj=1

source ./path.sh

echo "Compute MFCC"
steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data/test exp/make_mfcc/test $mfccdir  || exit 1
steps/compute_cmvn_stats.sh data/test exp/make_mfcc/test $mfccdir

echo "Decoding..."
#utils/mkgraph.sh --mono data/lang exp/mono exp/mono/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/mono/graph data/test exp/mono/decode

#utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1/graph data/test exp/tri1/decode

exit

#utils/mkgraph.sh data/lang exp/tri3b exp/tri3b/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3b/graph data/test exp/tri3b/decode

echo "Done"
