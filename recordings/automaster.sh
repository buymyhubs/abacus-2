#!/usr/bin/env bash
# quick master for live recordings
# usage: [VAR=val ...] ./automaster.sh [--analyze] file.wav ...
# outputs <name>_master_24.flac and <name>_master_16.flac next to the input
set -eu

: "${TARGET:=-9}" "${TP:=-1.5}" "${DRIVE:=17}" "${EQ:=1}" "${EQ_STRENGTH:=0.6}" "${EQ_MAX:=3}" "${WINDOW:=6}"
# reference balance vs. average of the 5 bands (low, low-mid, mid, presence, high), rough guess
: "${REF:=8 5 1 -4 -10}"

analyze=0
if [ "${1:-}" = --analyze ]; then analyze=1; shift; fi

bands=(
  "highpass=f=40,highpass=f=40,lowpass=f=150,lowpass=f=150"
  "highpass=f=150,highpass=f=150,lowpass=f=500,lowpass=f=500"
  "highpass=f=500,highpass=f=500,lowpass=f=2000,lowpass=f=2000"
  "highpass=f=2000,highpass=f=2000,lowpass=f=6000,lowpass=f=6000"
  "highpass=f=6000,highpass=f=6000,lowpass=f=16000,lowpass=f=16000"
)

for f in "$@"; do
  sr=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$f" | head -n1)
  echo "==> $f ($sr Hz)"

  # recorder can die before fixing the wav header, so read to EOF if the file is bigger than the header says
  ign=""
  case $f in *.wav|*.WAV)
    size=$(wc -c < "$f")
    info=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate:format=duration -of default=nw=1 "$f" || true)
    if awk -v size="$size" -F= '/bit_rate/{br=$2+0} /duration/{d=$2+0} END{exit !(d<=0 || size > d*br/8*1.01+65536)}' <<< "$info"; then
      ign="-ignore_length 1"; echo "    header length looks wrong, reading to EOF"
    fi ;;
  esac

  eqchain=""
  if [ "$EQ" = 1 ] || [ "$analyze" = 1 ]; then
    win=""
    if [ "$WINDOW" != 0 ]; then
      # find the loudest WINDOW seconds using momentary loudness (100ms steps)
      st=$(ffmpeg -hide_banner -nostats -nostdin $ign -i "$f" -af ebur128 -f null - 2>&1 | tr '\r' '\n' |
        awk -v w="$WINDOW" 'BEGIN{N=int(w*10+0.5)}
          match($0,/ t: *[0-9.]+/){t=substr($0,RSTART+4,RLENGTH-4)+0
            if(match($0,/ M: *-?[0-9.a-z]+/)){m=substr($0,RSTART+4,RLENGTH-4); e=(m~/inf/)?0:10^(m/10)
              n++; E[n]=e; s+=e; if(n>N)s-=E[n-N]
              if(n>=N && s>best){best=s; start=t-w}}}
          END{printf "%.1f", (start<0)?0:start}')
      win="-ss $st -t $WINDOW"
      echo "    analyzing $WINDOW s from ${st}s"
    fi

    levels=""
    for b in "${bands[@]}"; do
      v=$(ffmpeg -hide_banner -nostdin $ign $win -i "$f" -af "aformat=channel_layouts=stereo,$b,volumedetect" -f null - 2>&1 |
        sed -n 's/.*mean_volume: \(-\{0,1\}[0-9.]\{1,\}\) dB.*/\1/p' | tail -n1)
      levels="$levels $v"
    done

    if [ "$(echo $levels | wc -w)" -eq 5 ]; then
      # gain = strength * (reference - measured), both relative to the 5-band average, clamped
      gains=$(awk -v ref="$REF" -v s="$EQ_STRENGTH" -v mx="$EQ_MAX" '{
        split(ref, r, " "); for(i=1;i<=5;i++) m+=$i; m/=5
        for(i=1;i<=5;i++){ g=s*(r[i]-($i-m)); if(g>mx)g=mx; if(g<-mx)g=-mx; printf "%.1f ", g }}' <<< "$levels")
      echo "    levels: $levels"
      echo "    gains:  $gains"
      read -r g0 g1 g2 g3 g4 <<< "$gains"
      eqchain="bass=g=$g0:f=100,equalizer=f=300:t=q:w=0.8:g=$g1,equalizer=f=1000:t=q:w=0.8:g=$g2,equalizer=f=3500:t=q:w=0.8:g=$g3,treble=g=$g4:f=8000,"
    else
      echo "    band measurement failed, skipping EQ" >&2
    fi
  fi
  if [ "$analyze" = 1 ]; then continue; fi

  base="${f%.*}"
  fc="[0:a]aformat=channel_layouts=stereo,loudnorm=I=-18:TP=-3:LRA=20,aresample=$sr,highpass=f=20:p=2,${eqchain}asplit=2[main][sc];
[sc]highpass=f=90[sc_hp];
[main][sc_hp]sidechaincompress=threshold=0.07:ratio=4:knee=4:attack=15:release=100:mix=0.6[comp];
[comp]volume=${DRIVE}dB,asplit=2[lo][hi];
[lo]lowpass=f=120,lowpass=f=120,pan=stereo|c0=0.5*c0+0.5*c1|c1=0.5*c0+0.5*c1,asoftclip=type=tanh:oversample=4[lo_mono];
[hi]highpass=f=120,highpass=f=120,asoftclip=type=tanh:oversample=4[hi_st];
[lo_mono][hi_st]amix=inputs=2:normalize=0[mixed];
[mixed]alimiter=limit=0.89:attack=5:release=80:asc=1:asc_level=0.5:level=0,loudnorm=I=$TARGET:TP=$TP:LRA=30,aresample=$sr,asplit=2[m24][m16pre];
[m16pre]aresample=$sr:osf=s16:dither_method=triangular_hp[m16]"

  ffmpeg -hide_banner -loglevel error -nostdin -y $ign -i "$f" -filter_complex "$fc" \
    -map "[m24]" -c:a flac -sample_fmt s32 -bits_per_raw_sample 24 "${base}_master_24.flac" \
    -map "[m16]" -c:a flac -sample_fmt s16 "${base}_master_16.flac"

  ffmpeg -hide_banner -nostdin -i "${base}_master_24.flac" -af ebur128=peak=true -f null - 2>&1 |
    tr '\r' '\n' | grep -E "^\s+(I|Peak):" || true
done