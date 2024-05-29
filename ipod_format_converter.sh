#!/usr/bin/env bash

convert_audio() {
  local file="$1"
  local out_dir="$2"
  local type="$3"
  local base_name="$(basename "${file%.*}")"
  local ext="${file##*.}"
  local target_file="$out_dir/${base_name}.$type"

  case "$ext" in
    flac)
      echo "Converting FLAC to $type: $file"
      if [ "$type" == "aiff" ]; then
        # Convert FLAC to AIFF directly
        if flac -s -d --force-aiff-format -o "$target_file" "$file"; then
          echo "Successfully converted FLAC to AIFF: $file"
        else
          echo "Failed to convert FLAC: $file"
        fi
      else
        # Convert FLAC to ALAC
        local aiff="$out_dir/${base_name}.aiff"
        if flac -s -d --force-aiff-format -o "$aiff" "$file" && afconvert -f m4af -d alac "$aiff" "$target_file"; then
          echo "Successfully converted FLAC to ALAC: $file"
          rm "$aiff"
        else
          echo "Failed to convert FLAC: $file"
          rm -f "$aiff"
        fi
      fi
      ;;
    wav)
      echo "Converting WAV to ALAC: $file"
      # Convert WAV directly to ALAC within M4A container
      if afconvert -f m4af -d alac "$file" "$target_file"; then
        echo "Successfully converted WAV: $file"
      else
        echo "Failed to convert WAV: $file"
      fi
      ;;
    wma)
      echo "Converting WMA to AAC: $file"
      # Convert WMA directly to AAC within M4A container using ffmpeg
      if ffmpeg -i "$file" -acodec aac "$target_file"; then
        echo "Successfully converted WMA: $file"
      else
        echo "Failed to convert WMA: $file"
      fi
      ;;
    *)
      echo "Skipping unsupported file type: $file"
      ;;
  esac
}

TEMP=$(getopt -o t: --long type: -n 'ipod_format_converter.sh' -- "$@")

if [ $? != 0 ]; then
  echo "Terminating..." >&2
  exit 1
fi

# Note the quotes around '$TEMP': they are essential!
eval set -- "$TEMP"

type="m4a"  # default type ALAC (m4a)
while true; do
  case "$1" in
    -t | --type )
      type="$2"
      shift 2
      [[ "$type" == "m4a" || "$type" == "aiff" ]] || { echo "Invalid type: $type"; exit 1; }
      ;;
    -- )
      shift
      break
      ;;
    * )
      break
      ;;
  esac
done

if [ $# -ne 2 ]; then
  echo "Usage: $0 [-t|--type type] <source_dir> <output_dir>"
  echo "Options:"
  echo "  -t, --type  Specify output type for FLAC files (m4a or aiff). Default is m4a."
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

