#!/bin/bash

# Given a wav,.scp file, create dir for train, create definitive 'wav.scp',
# create 'text', create 'utt2spk' and 'spk2utt'


# USAGE:
#
# local/prepare_data.sh \
#    $wav.scp \
#    $transcripts \
#    $data_dir \
#    $data_type
#    [$segments]

# INPUT:
#
#    wav_tmp.scp
#
#    transcripts
#
#    [segments]

# OUTPUT:

# data_dir/
# │
# └── data_type
#     ├── spk2utt
#     ├── text
#     ├── utt2spk
#     └── wav.scp


wav_tmp=$1
transcripts=$2
data_dir=$3
# data_type = train or test
data_type=$4

is_segments=false
# Check if segments files is provided
if [ "$#" -eq 5 ]; then
    echo "$0: Segments file is provided"
    segments=$5
    is_segments=true

fi



#echo "$0: looking for audio data in $audio_dir"

# Make sure we have the audio data (WAV file utterances)
#if [ ! -d $audio_dir ]; then
#    printf '\n####\n#### ERROR: '"${audio_dir}"' not found \n####\n\n';
#    exit 1;
#fi


# Creating ./${data_dir} directory
mkdir -p ${data_dir}/local
mkdir -p ${data_dir}/local/tmp

local_dir=${data_dir}/local


###                                                     ###
### Check if utt IDs in transcripts and audio dir match ###
###                                                     ###
echo "$0: Check if utt IDs in transcripts and audio match"
#ls -1 $audio_dir > $local_dir/tmp/audio.list
#awk -F"." '{print $1}' $local_dir/tmp/audio.list > $local_dir/tmp/utt-ids-audio.txt
awk -F" " '{print $1}' $wav_tmp > $local_dir/tmp/utt-ids-audio.txt
# If there is a segments file, the utt-ids should be from this file not from the .scp file
if $is_segments;then
    # Remove the one generated using wav.scp
    rm -f $local_dir/tmp/utt-ids-audio.txt
    awk -F" " '{print $1}' $segments > $local_dir/tmp/utt-ids-audio.txt
fi
awk -F" " '{print $1}' $transcripts > $local_dir/tmp/utt-ids-transcripts.txt
for fileName in $local_dir/tmp/utt-ids-audio.txt $local_dir/tmp/utt-ids-transcripts.txt; do
    LC_ALL=C sort -i $fileName -o $fileName;
done;
diff $local_dir/tmp/utt-ids-audio.txt $local_dir/tmp/utt-ids-transcripts.txt > $local_dir/tmp/diff-ids.txt
if [ -s $local_dir/tmp/diff-ids.txt ]; then
    printf "\n####\n#### ERROR: Audio files & transcripts mismatch \n####\n\n";
    exit 0;
fi



###                                         ###
### Make wav.scp & text & utt2spk & spk2utt ###
###                                         ###
echo "$0: Make wav.scp, text, utt2spk and spk2utt"
# make two-column lists of utt IDs and path to audio
cp $wav_tmp $local_dir/tmp/${data_type}_wav.scp
#local/create_wav_scp.pl $audio_dir $local_dir/tmp/audio.list > $local_dir/tmp/${data_type}_wav.scp
# make two-column lists of utt IDs and transcripts
cp $transcripts $local_dir/tmp/${data_type}.txt
#local/create_txt.pl $transcripts $local_dir/tmp/audio.list > $local_dir/tmp/${data_type}.txt


mkdir -p $data_dir/$data_type
# Make wav.scp

cat $data_dir/local/tmp/${data_type}_wav.scp | sort -u > $data_dir/$data_type/wav.scp
# Make text
cat $data_dir/local/tmp/${data_type}.txt | sort -u > $data_dir/$data_type/text
# Make utt2spk
cat $data_dir/$data_type/text | awk '{printf("%s %s\n", $1, $1);}' | sort -u > $data_dir/$data_type/utt2spk
# Make spk2utt
utils/utt2spk_to_spk2utt.pl <$data_dir/$data_type/utt2spk > $data_dir/$data_type/spk2utt
# Make spegments
if $is_segments;then
    cat $segments | sort -u > $data_dir/$data_type/segments
fi

#clean up temp files
rm -rf $local_dir/tmp


