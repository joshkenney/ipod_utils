#!/usr/bin/env bash

convert_audio() {
  local file="$1"
  local out_dir="$2"
  local type="$3"
  local base_name="$(basename "${file%.*}")"
  local ext="${file##*.}"
  local target_file="$out_dir/${base_name}.$type"

  # Check for non-standard ID3 tags and remove them if found
  if [[ "$ext" == "flac" ]]; then
    local has_id3=$(ffprobe -v error -show_entries format_tags=ID3v1,ID3v2 -of default=noprint_wrappers=1:nokey=1 "$file")
    if [[ -n "$has_id3" ]]; then
      echo "ID3 tags found in $file, removing..."
      ffmpeg -i "$file" -map_metadata -1 -acodec copy "${file}.temp"
      mv "${file}.temp" "$file"
    fi
  fi

  case "$ext" in
    flac)
      echo "Converting FLAC to $type: $file"
      if [[ "$type" == "aiff" ]]; then
        # Convert FLAC to AIFF using ffmpeg
        if ffmpeg -i "$file" -acodec pcm_s16be "$target_file" 2>&1; then
          echo "Successfully converted FLAC to AIFF: $file"
        else
          echo "Failed to convert FLAC: $file"
          # Log error details for later review
          ffmpeg -v error -i "$file" -acodec pcm_s16be "$target_file" 2>> error_log.txt
        fi
      else
        # Convert FLAC to ALAC
        local aiff="$out_dir/${base_name}.aiff"
        if flac -d -o "$aiff" "$file" && afconvert -f m4af -d alac "$aiff" "$target_file"; then
          echo "Successfully converted FLAC to ALAC: $file"
          rm "$aiff"
        else
          echo "Failed to convert FLAC: $file"
          rm -f "$aiff"
          # Log error details for later review
          flac -d -o "$aiff" "$file" 2>> error_log.txt
        fi
      fi
      ;;
    wav)
      echo "Converting WAV to $type: $file"
      if [[ "$type" == "aiff" ]]; then
        # Convert WAV to AIFF using ffmpeg
        if ffmpeg -i "$file" -acodec pcm_s16be "$target_file" 2>&1; then
          echo "Successfully converted WAV to AIFF: $file"
        else
          echo "Failed to convert WAV: $file"
          # Log error details for later review
          ffmpeg -v error -i "$file" -acodec pcm_s16be "$target_file" 2>> error_log.txt
        fi
      else
        # Convert WAV directly to ALAC within M4A container
        if afconvert -f m4af -d alac "$file" "$target_file"; then
          echo "Successfully converted WAV: $file"
        else
          echo "Failed to convert WAV: $file"
          # Log error details for later review
          afconvert -v error -f m4af -d alac "$file" "$target_file" 2>> error_log.txt
        fi
      fi
      ;;
    wma)
      echo "Converting WMA to AAC: $file"
      # Convert WMA directly to AAC within M4A container using ffmpeg
      if ffmpeg -i "$file" -acodec aac "$target_file" 2>&1; then
        echo "Successfully converted WMA: $file"
      else
        echo "Failed to convert WMA: $file"
        # Log error details for later review
        ffmpeg -v error -i "$file" -acodec aac "$target_file" 2>> error_log.txt
      fi
      ;;
    *)
      echo "Skipping unsupported file type: $file"
      ;;
  esac
}

type="m4a"  # default type is ALAC (m4a)
while getopts ":t:" opt; do
  case ${opt} in
    t )
      type=$OPTARG
      [[ "$type" == "m4a" || "$type" == "aiff" ]] || { echo "Invalid type: $type"; exit 1; }
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ $# -ne 2 ]; then
  echo "Usage: $0 [-t type] <source_dir> <output_dir>"
  echo "Options:"
  echo "  -t  Specify output type for FLAC files (m4a or aiff). Default is m4a."
  echo "Requirements: Mac OS, flac, afconvert, and ffmpeg installed"
  exit 1
fi

source_dir="$1"
output_dir="$2"

# Ensure output directory exists
mkdir -p "$output_dir"

# Process FLAC, WAV, and WMA files
shopt -s nullglob
for ext in flac wav wma; do
  for file in "$source_dir"/*.$ext; do
    convert_audio "$file" "$output_dir" "$type"
  done
done

echo "Conversion complete."

