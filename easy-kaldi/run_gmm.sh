#!/bin/bash

# Joshua Meyer (2017)


# USAGE:
#
#      ./run.sh <corpus_name>
#
# INPUT:
#
#    input_dir/
#       lexicon.txt
#       lexicon_nosil.txt
#       phones.txt
#       task.arpabo
#       transcripts
#
#       audio_dir/
#          utterance1.wav
#          utterance2.wav
#          utterance3.wav
#               .
#               .
#          utteranceN.wav
#
#    config_dir/
#       mfcc.conf
#       topo_orig.proto
#
#
# OUTPUT:
#
#    exp_dir
#    feat_dir
#    data_dir
#

corpus_name=$1
run=$2

if [ "$#" -ne 2 ]; then
    echo "ERROR: $0"
    echo "USAGE: $0 <corpus_name> <run>"
    exit 1
fi


### STAGES
##
#
prep_train_audio=1
extract_train_feats=1
compile_Lfst=0
train_gmm=1
compile_graph=1
prep_test_audio=1
extract_test_feats=1
decode_test=1
#
##
###


### HYPER-PARAMETERS
##
#
tot_gauss_mono=1000
num_leaves_tri=1000
tot_gauss_tri=2000
num_iters_mono=25
num_iters_tri=25
#
##
###


### SHOULD ALREADY EXIST
##
#
num_processors=$(nproc)
unknown_word="<unk>"
unknown_phone="SPOKEN_NOISE"
silence_phone="SIL"
input_dir=input_${corpus_name}
train_data_dir=`cat $input_dir/train_audio_path`
test_data_dir=`cat $input_dir/test_audio_path`
config_dir=config
cmd="utils/run.pl"
#
##
###


### GENERATED BY SCRIPT
##
#
data_dir=data_${corpus_name}
exp_dir=exp_${corpus_name}
plp_dir=plp_${corpus_name}
#
##
###


if [ 1 ]; then

    for i in $data_dir $exp_dir $plp_dir ; do
	if [ -d $i ]; then
	    echo "WARNING: $i already exists... should I delete it?"
	    echo "enter: y/n"
	    read del_dir
	    if [ "$del_dir" == "y" ]; then
		rm -rf $i
	    else
		echo "Exiting script."
		exit 0;
	    fi
	fi
    done
fi





if [ "$prep_train_audio" -eq "1" ]; then

    printf "\n####==========================####\n";
    printf "#### TRAINING AUDIO DATA PREP ####\n";
    printf "####==========================####\n\n";

    # since for multitask learning scripts, I can't have different labels
    # for one audio file path, I make softlinks here to audio files and the
    # softlinks have different filenames for each experiment

    # the softlinks should be stored in this location, and since the links are
    # renamed relative to the current experiment, I delete and remake the dir
    # here I've put in an if loop in case someone else just puts their data where the softlinks
    # go, I don't wanna delete data accidentally
    
    if [ -d "$input_dir/audio" ]; then
        echo "You have an audio dir in $input_dir..."
	echo "Should I delete it (assuming softlinks)?"
	echo "Enter: y / n"
	
	read delete_audio_dir

	if [ "$delete_audio_dir" == "y" ]; then
	    rm -rf $input_dir/audio
	else
	    echo "Exiting the program, if you want to move the files, go ahead."
	    echo "They're sitting in $input_dir/audio"
	    exit 0;
	fi
    fi
    
    mkdir $input_dir/audio
    
    # clean up old generated files
    rm -f $input_dir/phones.txt $input_dir/transcripts
        
    ## BEGIN HACK
    # this is my hack to make sure file names don't get mixed up in MTL training
    
    cwd=`pwd`
    cd $input_dir/audio

    echo "$0: Assuming your train audio data is in ${train_data_dir}"
    echo "$0: Making soflinks to original audio data with ${corpus_name}_ as prefix"
    
    for i in ${train_data_dir}/*.wav; do
        ln -s $i ${corpus_name}_${i##*/};
    done

    # Now that we have new filenames, we need to update our transcripts file to
    # reflect them
    
    cd $cwd
    while read line; do
        echo "${corpus_name}_$line" >> $input_dir/transcripts 
    done<$input_dir/transcripts.train
    
    ## END HACK
    
    local/prepare_audio_data.sh \
        $input_dir/audio\
        $input_dir/transcripts \
        $data_dir \
        train
fi



if [ "$extract_train_feats" -eq "1" ]; then

    printf "\n####==========================####\n";
    printf "#### TRAIN FEATURE EXTRACTION ####\n";
    printf "####==========================####\n\n";

    ./extract_feats.sh \
        $data_dir/train \
        $plp_dir \
        $num_processors

fi




if [ "$compile_Lfst" -eq "1" ]; then
    
    printf "\n####==============####\n";
    printf "#### Create L.fst ####\n";
    printf "####==============####\n\n";

    ./compile_Lfst.sh \
        $input_dir \
        $data_dir
   
else
    ./prepare_LG.sh \
	$input_dir/lexicon.txt $data_dir/local/tmp/lm.arpa "dummy" $data_dir/local/dict $data_dir/lang \
	|| exit 1;
fi


if [ "$train_gmm" -eq "1" ]; then

    printf "\n####===============####\n";
    printf "#### TRAINING GMMs ####\n";
    printf "####===============####\n\n";

    ./train_gmm.sh \
        $data_dir \
        $num_iters_mono \
        $tot_gauss_mono \
        $num_iters_tri \
        $tot_gauss_tri \
        $num_leaves_tri \
        $exp_dir \
        $num_processors;
fi



if [ "$compile_graph" -eq "1" ]; then
    
    printf "\n####===================####\n";
    printf "#### GRAPH COMPILATION ####\n";
    printf "####===================####\n\n";

    utils/mkgraph.sh \
        $input_dir \
        $data_dir \
        $data_dir/lang_decode \
        $exp_dir/triphones/graph \
        $exp_dir/triphones/tree \
        $exp_dir/triphones/final.mdl \
        || printf "\n####\n#### ERROR: mkgraph.sh \n####\n\n" \
        || exit 1;

fi




if [ "$prep_test_audio" -eq "1" ]; then

    printf "\n####==========================####\n";
    printf "#### TESTING AUDIO DATA PREP ####\n";
    printf "####==========================####\n\n";

    local/prepare_audio_data.sh \
        $test_data_dir \
        $input_dir/transcripts.test \
        $data_dir \
        test
fi



if [ "$extract_test_feats" -eq "1" ]; then

    printf "\n####=========================####\n";
    printf "#### TEST FEATURE EXTRACTION ####\n";
    printf "####=========================####\n\n";

    ./extract_feats.sh \
        $data_dir/test \
        $plp_dir \
        $num_processors
    
fi




if [ "$decode_test" -eq "1" ]; then
    
    printf "\n####================####\n";
    printf "#### BEGIN DECODING ####\n";
    printf "####================####\n\n";

    suffix=${corpus_name}_${run}
    
    ./test_gmm.sh \
        $exp_dir/triphones/graph/HCLG.fst \
        $exp_dir/triphones/final.mdl \
        $data_dir/test \
        $suffix \
        $num_processors;
    
fi

exit;


