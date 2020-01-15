#!/bin/bash

# Joshua Meyer (2017)
# Edited by Thomas Rolland (2020)

# USAGE:
#
#      ./run.sh <corpus_name>
#
# INPUT:
#
#    input_dir/
#       lexicon.txt
#       phones.txt
#       task.arpa
#       transcripts.train
#       transcripts.test
#       wav_train.scp
#       wav_test.scp
#       [segments_train]
#       [segments_test]
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
compile_Lfst=1
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
num_processors=10 #$(nproc)
unknown_word="<unk>"
unknown_phone="SPOKEN_NOISE"
silence_phone="SIL"
input_dir=input_${corpus_name}
#train_data_dir=`cat $input_dir/train_audio_path`
#test_data_dir=`cat $input_dir/test_audio_path`
config_dir=config
cmd="utils/run.pl"
#
##
###

set -e
### GENERATED BY SCRIPT
##
#
data_dir=data_${corpus_name}
exp_dir=exp_${corpus_name}
plp_dir=plp_${corpus_name}
#
##
###


. ./path.sh

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

    # Here I want to keep J. Meyer's hack to avoid having files mixed up in the MTL
    # training. However, since we can deal if large dataset (such as Librispeech)
    # we can't use one directory to put all softlink/wav files, my own hack is to
    # change utt_id directly in the wav and the transcription


    # clean up old generated files
    rm -f $input_dir/lexicon/phones.txt $input_dir/audio/transcripts

    ## BEGIN HACK
    # this is my hack to make sure file names don't get mixed up in MTL training

    #cwd=`pwd`
    #cd $input_dir/audio

    echo "$0: Assuming your train audio data is listed in wav_train.scp"
    echo "$0: Change original utt_id with ${corpus_name}_ as prefix"

    #for i in ${train_data_dir}/*.wav; do
    #    ln -s $i ${corpus_name}_${i##*/};
    #done
    rm -f $input_dir/audio/wav_train_tmp.scp
    while read LINE
    do
        # Split the input line to get the utt_id and the wav path
        IFS=" "
        read -ra tokens <<< "$LINE"
        # Change the utt_id with by adding corpus_name into the new wav.scp
        echo "${corpus_name}_${tokens[0]} ${tokens[1]}" >> $input_dir/audio/wav_train_tmp.scp

    done < $input_dir/audio/wav_train.scp

    # Check if there is an segments_train file in the audio directory, if it's
    # the case, apply the same hack here
    is_segments=false
    if test -f "$input_dir/audio/segments_train" ; then
        echo "$0: Add to utt_id and segments_id a ${corpus_name}_ prefix in segments.train file"
        is_segments=true
        # Read all segments_train file
        rm -f $input_dir/audio/segments.train
        while read LINE
        do
            # Split the input line
            IFS=" "
            read -ra tokens <<< "$LINE"
            echo "${corpus_name}_${tokens[0]} ${corpus_name}_${tokens[1]} ${tokens[2]} ${tokens[3]}" >> $input_dir/audio/segments.train
        done < $input_dir/audio/segments_train

    fi

    # Now that we have new utt_id, we need to update our transcripts file to
    # reflect them

    #cd $cwd
    while read line; do
        echo "${corpus_name}_$line" >> $input_dir/audio/transcripts
    done<$input_dir/audio/transcripts.train

    ## END HACK
    echo "$0: utt-id changed. Now Enter to the data preparation"
    if $is_segments; then
        local/prepare_audio_data.sh \
            $input_dir/audio/wav_train_tmp.scp\
            $input_dir/audio/transcripts \
            $data_dir \
            train \
            $input_dir/audio/segments.train
    else
        local/prepare_audio_data.sh \
            $input_dir/audio/wav_train_tmp.scp\
            $input_dir/audio/transcripts \
            $data_dir \
            train
    fi
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
        $input_dir/lexicon \
        $data_dir

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

    if $is_segments;then

        local/prepare_audio_data.sh \
            $input_dir/audio/wav_test.scp\
            $input_dir/audio/transcripts.test \
            $data_dir \
            test \
            $input_dir/audio/segments_test
    else

        local/prepare_audio_data.sh \
            $input_dir/audio/wav_test_tmp.scp \
            $input_dir/audio/transcripts.test \
            $data_dir \
            test
    fi
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


