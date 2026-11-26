#!/usr/bin/env bash
# Cuts the YouTube trailer (16:9, ~57 s) and the vertical Short (9:16, ~27 s)
# from a raw take recorded with:
#   godot --write-movie raw.avi --fixed-fps 30 -- --capture=DIR --trailer --trailer-long
# (window_*_override removed from project.godot for the recording so it is 1920x1080).
# Usage: tools/make_trailer.sh raw.avi OUT_DIR
set -euo pipefail
RAW="$1"; OUT="$2"
export PATH="$(cd "$(dirname "$0")/../../.." && pwd)/tools/bin/path:$PATH"
FONT=/usr/share/fonts/truetype/Poppins-Bold.ttf
TMP="$(mktemp -d /tmp/kavi-trl-XXXXXX)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"
calc() { awk "BEGIN{v=$1; printf(v==int(v)?\"%d\":\"%.2f\", v)}"; }
# Movie-writer frames are double-gamma: convert sRGB back to linear.
L="if(lt(val\,10.3)\,val/12.92\,pow((val/255+0.055)/1.055\,2.4)*255)"
FIX="lutrgb=r='$L':g='$L':b='$L'"
ENC=(-c:v libx264 -crf 17 -preset slow -pix_fmt yuv420p -r 30 -c:a aac -b:a 192k -ar 48000 -ac 2)

caption() { # text, duration, y-expression, size -> drawtext filter with fade
  local t="$1" d="$2" y="$3" s="$4"
  local a="if(lt(t\,0.35)\,0\,if(lt(t\,0.85)\,(t-0.35)/0.5\,if(lt(t\,$d-0.7)\,1\,max(0\,($d-0.2-t)/0.5))))"
  echo "drawtext=fontfile=$FONT:text='$t':fontsize=$s:fontcolor=white:alpha='$a':shadowcolor=black@0.6:shadowx=3:shadowy=3:x=(w-text_w)/2:y=$y"
}

seg() { # name start dur caption geometry(land|short)
  local n="$1" ss="$2" d="$3" cap="$4" g="$5" vf
  if [ "$g" = land ]; then
    vf="$FIX,format=yuv420p"
    [ -n "$cap" ] && vf="$vf,$(caption "$cap" "$d" "h*0.36" 76)"
  else
    # 1080x1080 window around Kavi over a blurred full-frame background.
    vf="split[a][b];[a]$FIX,scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,gblur=sigma=30,eq=brightness=-0.12[bg];[b]$FIX,crop=1080:1080:120:0[fg];[bg][fg]overlay=0:420,format=yuv420p"
    vf="$vf,drawtext=fontfile=$FONT:text='KAVI':fontsize=120:fontcolor=white:shadowcolor=black@0.6:shadowx=4:shadowy=4:x=(w-text_w)/2:y=170"
    [ -n "$cap" ] && vf="$vf,$(caption "$cap" "$d" "1600" 64)"
  fi
  vf="$vf,fade=in:0:9,fade=out:st=$(calc "$d-0.3"):d=0.3"
  ffmpeg -v error -y -ss "$ss" -t "$d" -i "$RAW" -filter_complex "$vf" \
    -af "afade=in:d=0.3,afade=out:st=$(calc "$d-0.35"):d=0.35" "${ENC[@]}" "$TMP/$n.mp4"
  echo "file '$TMP/$n.mp4'" >> "$TMP/$g.txt"
}

endcard() { # geometry, frame time for background
  local g="$1" W H fs
  if [ "$g" = land ]; then W=1920; H=1080; fs=1; else W=1080; H=1920; fs=0.8; fi
  local txt="drawtext=fontfile=$FONT:fontcolor=white:shadowcolor=black@0.6:shadowx=3:shadowy=3:x=(w-text_w)/2"
  ffmpeg -v error -y -ss 61.0 -i "$RAW" -ss 0.5 -t 5 -i "$RAW" -filter_complex \
    "[0:v]trim=end_frame=1,$FIX,scale=$W:$H:force_original_aspect_ratio=increase,crop=$W:$H,gblur=sigma=24,eq=brightness=-0.18,loop=150:1:0,setpts=N/30/TB,\
$txt:fontsize=$(calc "150*$fs/1"):text='KAVI':y=h*0.30,\
$txt:fontsize=$(calc "54*$fs/1"):text='Letters to Lia':y=h*0.30+$(calc "190*$fs/1"),\
$txt:fontsize=$(calc "64*$fs/1"):text='Play free in your browser':y=h*0.58,\
$txt:fontsize=$(calc "48*$fs/1"):text='badcool-interactive.github.io/KAVI-Letters-To-Lia':fontcolor=0xFFD27A:y=h*0.58+$(calc "90*$fs/1"),\
$txt:fontsize=$(calc "38*$fs/1"):text='Badcool Studio':y=h*0.88,format=yuv420p,fade=in:0:12,fade=out:st=4.4:d=0.6[v];\
[1:a]afade=in:d=0.5,afade=out:st=4.0:d=1.0[a]" -map "[v]" -map "[a]" -t 5 "${ENC[@]}" "$TMP/end-$g.mp4"
  echo "file '$TMP/end-$g.mp4'" >> "$TMP/$g.txt"
}

# ---- 16:9 trailer (raw take timestamps)
seg l0 0.3  3.2 ""                              land
seg l1 4.0  7.5 "GREECE  ·  hop, scoot, glide"  land
seg l2 12.5 7.0 "BULGARIA  ·  the lantern forest" land
seg l3 19.6 4.6 "Kind strangers lend a hand"    land
seg l4 26.0 8.5 "ROMANIA  ·  pick your road"    land
seg l5 37.0 8.0 "Chase the Carpathian aurora"   land
seg l6 47.0 6.0 "Endless Road  ·  Daily Relay"  land
seg l7 55.6 7.4 "...all the way to Lumi."       land
endcard land
ffmpeg -v error -y -f concat -safe 0 -i "$TMP/land.txt" -c copy -movflags +faststart "$OUT/youtube-trailer-1920x1080.mp4"

# ---- 9:16 Short: hook first (the rescue), then the journey, then the reunion
seg s0 19.6 4.6 "Kite falls... a stranger swoops in" short
seg s1 5.0  5.0 "Hop across Greece"             short
seg s2 14.0 4.5 "Through Bulgarian forests"     short
seg s3 30.0 4.5 "Pick your road"                short
seg s4 38.0 4.5 "Under the aurora"              short
seg s5 55.6 7.4 "...to reach Lumi."             short
endcard short
ffmpeg -v error -y -f concat -safe 0 -i "$TMP/short.txt" -c copy -movflags +faststart "$OUT/youtube-short-1080x1920.mp4"
ls -la "$OUT"
