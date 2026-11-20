#!/bin/bash
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

FFMPEG="ffmpeg"

SRC_FORMAT=wav

ALBUM=""
ARTIST=""
COVER_SRC_PATH=""

# this don't do nothing yet. these values are current default behavior
OUTPUT_FORMATS=("flac" "mp3" "alac")

while getopts "r:l:c:o:i:" flag; do
  case "${flag}" in
    r)
      ARTIST="${OPTARG}"
      ;;
    l)
      ALBUM="${OPTARG}"
      ;;
    c)
      COVER_SRC_PATH="${OPTARG}"
      ;;
    o)
      IFS=',' read -r -a OUTPUT_FORMATS <<< "${OPTARG}"
      ;;
    i)
      SRC_FORMAT="${OPTARG}"
      ;;
    *)
      echo "Usage: $0 [-r artist] [-l album] [-c cover_path] [-i input_file_extension]"
      exit 1
      ;;
  esac
done

TRACKS=( *.${SRC_FORMAT} )
TOTAL_TRACKS=${#TRACKS[@]}

ASK_CONTINUE=false
if [[ -z "$ARTIST" ]]; then
  printf "${YELLOW}Artist not provided!${NC}\n"
  ASK_CONTINUE=true
else
  echo Artist = $ARTIST
fi
if [[ -z "$ALBUM" ]]; then
  printf "${YELLOW}Album title not provided!${NC}\n"
  ASK_CONTINUE=true
else
  echo Album = $ALBUM
fi
if [[ -z "$COVER_SRC_PATH" ]]; then
  printf "${YELLOW}Cover art path not provided!${NC}\n"
  ASK_CONTINUE=true
else
  echo Cover art path = $COVER_SRC_PATH
fi
echo Total tracks = ${TOTAL_TRACKS}
if [[ "$ASK_CONTINUE" == "true" ]]; then
  printf "${YELLOW}"
  read -p "Info missing. Continue anyway? (y/N): " -n 1 -r
  printf "${NC}"
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "Proceeding..."
  else
      echo "Action canceled."
      exit 1
  fi
fi

mkdir -p mastered/flac mastered/mp3 mastered/alac
for f in *.${SRC_FORMAT}; do
  BASE="${f%.*}"
  TRACK="${BASE%% *}"
  SONG_TITLE="${BASE#* }"
  echo TRACK = $TRACK
  echo SONG = $SONG_TITLE
  echo "Processing $f"
  ${FFMPEG} \
    -i "${f%.*}.${SRC_FORMAT}" \
    -i "${COVER_SRC_PATH}" \
    -metadata title="${SONG_TITLE}" \
    -metadata artist="${ARTIST}" \
    -metadata album="${ALBUM}" \
    -filter_complex "
    [0:a]
      aformat=channel_layouts=stereo,
      loudnorm=I=-18:TP=-3:LRA=50,
      aresample=44100,
      highpass=f=20:p=2,
      asplit=2[main][sidechain];

    [sidechain]
      highpass=f=90[detector];

    [main][detector]
      sidechaincompress=threshold=0.07:ratio=4:knee=4:attack=15:release=100:mix=0.6[compressed];

    [compressed]
      volume=14dB,
      asplit=2[low][high];

    [low]
      lowpass=f=120,
      lowpass=f=120,
      pan=stereo|c0=0.5*c0+0.5*c1|c1=0.5*c0+0.5*c1,
      asoftclip=type=tanh:oversample=4[low_clipped];

    [high]
      highpass=f=120,
      highpass=f=120,
      asoftclip=type=tanh:oversample=4,
      extrastereo=m=1.3[high_clipped];

    [low_clipped][high_clipped]
      amix=inputs=2:normalize=0[summed];

    [summed]
      alimiter=limit=0.9:attack=5:release=80:asc=1:asc_level=0.5:level=0,
      loudnorm=I=-10:TP=-1.5:LRA=50,
      aresample=44100:osf=s16:dither_method=triangular_hp[audio_out];
    
    [1:v]
      scale='min(800,iw)':-1[scaled_cover];
  " \
  -map "[audio_out]" \
  -map "[scaled_cover]" \
  -c:a flac \
  -c:v mjpeg \
  -sample_fmt s16 \
  -disposition:v attached_pic \
  "mastered/flac/${TRACK} ${SONG_TITLE}.flac"
${FFMPEG} \
  -i "mastered/flac/${TRACK} ${SONG_TITLE}.flac" \
  -map 0:a \
  -map 0:v \
  -c:a libmp3lame \
  -b:a 192k \
  -c:v copy \
  -map_metadata 0 \
  -id3v2_version 3 \
  -write_id3v1 1 \
  "mastered/mp3/${TRACK} ${SONG_TITLE}.mp3"
${FFMPEG} \
  -i "mastered/flac/${TRACK} ${SONG_TITLE}.flac" \
  -map 0:a \
  -map 0:v \
  -c:a alac \
  -c:v copy \
  -disposition:v:0 attached_pic \
  -map_metadata 0 \
  "mastered/alac/${TRACK} ${SONG_TITLE}.m4a"
done