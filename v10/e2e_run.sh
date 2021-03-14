#!/usr/bin/env bash

# Change this location to somewhere where you want to put the data.
data=/opt/kaldi/egs/mini_librispeech/corpus/

data_url=www.openslr.org/resources/31
lm_url=www.openslr.org/resources/11

. ./cmd.sh
. ./path.sh

stage=0
trainset=train_clean_5
. utils/parse_options.sh

set -euo pipefail

mkdir -p $data

for part in dev-clean-2 train-clean-5; do
  local/download_and_untar.sh $data $data_url $part
done

if [ $stage -eq 0 ]; then
  local/download_lm.sh $lm_url $data data/local/lm
fi

if [ $stage -eq 1 ]; then
  # format the data as Kaldi data directories
  for part in dev-clean-2 train-clean-5; do
    # use underscore-separated names in data directories.
    local/data_prep.sh $data/LibriSpeech/$part data/$(echo $part | sed s/-/_/g)
  done

  local/prepare_dict.sh --stage 3 --nj 30 --cmd "$train_cmd" \
    data/local/lm data/local/lm data/local/dict_nosp

  utils/prepare_lang.sh data/local/dict_nosp \
    "<UNK>" data/local/lang_tmp_nosp data/lang_nosp

  local/format_lms.sh --src-dir data/lang_nosp data/local/lm
fi

if [ $stage -eq 2 ]; then
  # make MFCC features for the test data. Only hires since it's flat-start.
  echo "$0: extracting MFCC features for the test sets"
  for x in dev_clean_2; do
    cp -r data/$x data/${x}_hires
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 20 \
                       --mfcc-config conf/mfcc_hires.conf data/${x}_hires
    steps/compute_cmvn_stats.sh data/${x}_hires
  done
fi

if [ $stage -eq 3 ]; then
  echo "$0: perturbing the training data to allowed lengths"
  utils/data/get_utt2dur.sh data/$trainset  # necessary for the next command

  # 12 in the following command means the allowed lengths are spaced
  # by 12% change in length.
  utils/data/perturb_speed_to_allowed_lengths.py 12 data/${trainset} \
                                                 data/${trainset}_spe2e_hires
  cat data/${trainset}_spe2e_hires/utt2dur | \
    awk '{print $1 " " substr($1,5)}' >data/${trainset}_spe2e_hires/utt2uniq
  utils/fix_data_dir.sh data/${trainset}_spe2e_hires
fi

if [ $stage -eq 4 ]; then
  echo "$0: extracting MFCC features for the training data"
  steps/make_mfcc.sh --nj 50 --mfcc-config conf/mfcc_hires.conf \
                     --cmd "$train_cmd" data/${trainset}_spe2e_hires
  steps/compute_cmvn_stats.sh data/${trainset}_spe2e_hires
fi

if [ $stage -eq 5 ]; then
  echo "$0: calling the flat-start chain recipe..."
  local/chain/e2e/run_tdnn_flatstart.sh
fi

######################################
# for old GMM training
######################################


if [ $stage -eq 22 ]; then
  mfccdir=mfcc

  for part in dev_clean_2 train_clean_5; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 10 data/$part exp/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
  done

  # Get the shortest 500 utterances first because those are more likely
  # to have accurate alignments.
  utils/subset_data_dir.sh --shortest data/train_clean_5 500 data/train_500short
fi

# train a monophone system
if [ $stage -eq 33 ]; then
  # TODO(galv): Is this too many jobs for a smaller dataset?
  steps/train_mono.sh --boost-silence 1.25 --nj 5 --cmd "$train_cmd" \
    data/train_500short data/lang_nosp exp/mono

  steps/align_si.sh --boost-silence 1.25 --nj 5 --cmd "$train_cmd" \
    data/train_clean_5 data/lang_nosp exp/mono exp/mono_ali_train_clean_5
fi

# train a first delta + delta-delta triphone system on all utterances
if [ $stage -eq 44 ]; then
  steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
    2000 10000 data/train_clean_5 data/lang_nosp exp/mono_ali_train_clean_5 exp/tri1

  steps/align_si.sh --nj 5 --cmd "$train_cmd" \
    data/train_clean_5 data/lang_nosp exp/tri1 exp/tri1_ali_train_clean_5
fi

# train an LDA+MLLT system.
if [ $stage -eq 55 ]; then
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
    data/train_clean_5 data/lang_nosp exp/tri1_ali_train_clean_5 exp/tri2b

  # Align utts using the tri2b model
  steps/align_si.sh  --nj 5 --cmd "$train_cmd" --use-graphs true \
    data/train_clean_5 data/lang_nosp exp/tri2b exp/tri2b_ali_train_clean_5
fi

# Train tri3b, which is LDA+MLLT+SAT
if [ $stage -eq 6 ]; then
  steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
    data/train_clean_5 data/lang_nosp exp/tri2b_ali_train_clean_5 exp/tri3b
fi

# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
if [ $stage -eq 7 ]; then
  steps/get_prons.sh --cmd "$train_cmd" \
    data/train_clean_5 data/lang_nosp exp/tri3b
  utils/dict_dir_add_pronprobs.sh --max-normalize true \
    data/local/dict_nosp \
    exp/tri3b/pron_counts_nowb.txt exp/tri3b/sil_counts_nowb.txt \
    exp/tri3b/pron_bigram_counts_nowb.txt data/local/dict

  utils/prepare_lang.sh data/local/dict \
    "<UNK>" data/local/lang_tmp data/lang

  local/format_lms.sh --src-dir data/lang data/local/lm

#  utils/build_const_arpa_lm.sh \
#    data/local/lm/lm_tglarge.arpa.gz data/lang data/lang_test_tglarge

  steps/align_fmllr.sh --nj 5 --cmd "$train_cmd" \
    data/train_clean_5 data/lang exp/tri3b exp/tri3b_ali_train_clean_5
fi


if [ $stage -eq 8 ]; then
  # Test the tri3b system with the silprobs and pron-probs.

  # decode using the tri3b model
  utils/mkgraph.sh data/lang_test_tgsmall \
                   exp/tri3b exp/tri3b/graph_tgsmall
  for test in dev_clean_2; do
    steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" \
                          exp/tri3b/graph_tgsmall data/$test \
                          exp/tri3b/decode_tgsmall_$test

    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
                       data/$test exp/tri3b/decode_{tgsmall,tgmed}_$test
#x    steps/lmrescore_const_arpa.sh \
#      --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
#x      data/$test exp/tri3b/decode_{tgsmall,tglarge}_$test
  done
fi

# Train a chain model
if [ $stage -eq 9 ]; then
  local/chain2/run_tdnn.sh
fi

# local/grammar/simple_demo.sh
