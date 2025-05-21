#!/bin/bash

# Script to create optimized GIFs for Bitcoin Ordinals with customizable profiles

# Default values
INPUT_VIDEO=""
OUTPUT_GIF="robe.gif"
WIDTH=150
FRAME_INTERVAL=5
COLORS=64
OUTPUT_DIR="/home/rich/ordinals/ordinal"

# Function to display usage
usage() {
  echo "Usage: $0 -i <input_video> [-o <output_gif>] [-w <width>] [-f <frame_interval>] [-c <colors>] [-t <type>] [-p <input_image>]"
  echo "  -i <input_video>    : Path to the input video file (required for gif)"
  echo "  -o <output_gif>     : Name of the output GIF file (default: robe.gif)"
  echo "  -w <width>          : Desired width of the GIF (maintains 9:16 aspect ratio, default: 150)"
  echo "  -f <frame_interval> : Interval for extracting frames (e.g., 5 for every 5th frame, default: 5)"
  echo "  -c <colors>         : Number of colors for optimization (default: 64)"
  echo "  -t <type>           : Type of conversion (gif or webp, default: gif)"
  echo "  -p <input_image>    : Path to the input image file (JPEG, PNG, or SVG) for WEBP conversion (required if type is webp)"
  exit 1
}

# Default value for conversion type
CONVERSION_TYPE="gif"

# Function to convert image to WEBP
convert_to_webp() {
  local INPUT_IMAGE="$1"
  local OUTPUT_WEBP="/home/rich/ordinals/${INPUT_IMAGE##*/}"
  OUTPUT_WEBP="${OUTPUT_WEBP%.*}.webp" # Change extension to webp
  local MAX_SIZE=60000 # 60KB in bytes
  local QUALITY=80
  local CURRENT_SIZE=$(stat -c "%s" "$INPUT_IMAGE")

  echo "Converting ${INPUT_IMAGE} to WEBP..."

  # Initial conversion
  convert "$INPUT_IMAGE" -quality "$QUALITY" "$OUTPUT_WEBP"

  if [ $? -ne 0 ]; then
    echo "Error: ImageMagick convert failed."
    return 1
  fi

  # Check file size and adjust quality if needed
  CURRENT_SIZE=$(stat -c "%s" "$OUTPUT_WEBP")
  while [ "$CURRENT_SIZE" -gt "$MAX_SIZE" ] && [ "$QUALITY" -gt 10 ]; do
    QUALITY=$((QUALITY - 5))
    echo "Reducing quality to ${QUALITY} to meet size requirement..."
    convert "$INPUT_IMAGE" -quality "$QUALITY" "$OUTPUT_WEBP"
    CURRENT_SIZE=$(stat -c "%s" "$OUTPUT_WEBP")
  done

  if [ "$CURRENT_SIZE" -gt "$MAX_SIZE" ]; then
    echo "Warning: Could not reduce file size below 60KB. Current size: ${CURRENT_SIZE} bytes."
  else
    echo "Successfully converted ${INPUT_IMAGE} to ${OUTPUT_WEBP} with size ${CURRENT_SIZE} bytes."
  fi
}

# Parse command line options
while getopts "i:o:w:f:c:t:p:" opt; do
  case "${opt}" in
    i)
      INPUT_VIDEO=${OPTARG}
      ;;
    o)
      OUTPUT_GIF=${OPTARG}
      ;;
    w)
      WIDTH=${OPTARG}
      ;;
    f)
      FRAME_INTERVAL=${OPTARG}
      ;;
    c)
      COLORS=${OPTARG}
      ;;
    t)
      CONVERSION_TYPE=${OPTARG}
      ;;
    p)
      INPUT_IMAGE=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

# Perform actions based on conversion type
case "${CONVERSION_TYPE}" in
  gif)
    # Check if input video is provided
    if [ -z "${INPUT_VIDEO}" ]; then
      echo "Error: Input video not specified for gif conversion."
      usage
    fi

    # Calculate height for 9:16 aspect ratio
    HEIGHT=$((WIDTH * 16 / 9))

    # Ensure output directory exists
    mkdir -p "${OUTPUT_DIR}"

    # Step 1: Extract Frames
    echo "Extracting frames from ${INPUT_VIDEO}..."
    ffmpeg -i "${INPUT_VIDEO}" \
      -vf "select='not(mod(n,${FRAME_INTERVAL}))',scale=-1:${HEIGHT},crop=${WIDTH}:${HEIGHT}" \
      -vsync vfr \
      frame_%03d.png

    if [ $? -ne 0 ]; then
      echo "Error: FFmpeg failed to extract frames."
      exit 1
    fi

    # Step 2: Create Basic GIF
    echo "Creating basic GIF..."
    convert -delay 8 -loop 0 frame_*.png \
      -background transparent \
      "${OUTPUT_GIF}"

    if [ $? -ne 0 ]; then
      echo "Error: ImageMagick convert failed."
      exit 1
    fi

    # Step 3: Optimize Colors and Size with Gifsicle
    echo "Optimizing GIF with Gifsicle..."
    gifsicle --colors "${COLORS}" --optimize=3 -O3 -b "${OUTPUT_GIF}"

    if [ $? -ne 0 ]; then
      echo "Error: Gifsicle optimization failed."
      exit 1
    fi

    # Step 4: Move final GIF to output directory
    echo "Moving ${OUTPUT_GIF} to ${OUTPUT_DIR}..."
    mv "${OUTPUT_GIF}" "${OUTPUT_DIR}/"

    if [ $? -ne 0 ]; then
      echo "Error: Failed to move the final GIF."
      exit 1
    fi

    echo "GIF creation and optimization complete: ${OUTPUT_DIR}/${OUTPUT_GIF}"
    echo "Final size:"
    ls -lh "${OUTPUT_DIR}/${OUTPUT_GIF}"

    # Clean up extracted frames
    echo "Cleaning up temporary frame files..."
    rm frame_*.png

    echo "Done."
    ;;
  webp)
    # Check if input image is provided
    if [ -z "${INPUT_IMAGE}" ]; then
      echo "Error: Input image not specified for webp conversion."
      usage
    fi
    convert_to_webp "${INPUT_IMAGE}"
    ;;
  *)
    echo "Error: Invalid conversion type. Must be gif or webp."
    usage
    ;;
esac
