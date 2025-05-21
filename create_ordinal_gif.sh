#!/bin/bash

# Script to create optimized GIFs for Bitcoin Ordinals with customizable profiles

# Default values
INPUT_VIDEO=""
OUTPUT_GIF_BASENAME="default_output" # Default base name for GIF
OUTPUT_WEBP_BASENAME="default_output" # Default base name for WEBP
WIDTH=150
FRAME_INTERVAL=5
COLORS=64
WEBP_QUALITY=75 # Default quality for video-to-WEBP conversion
IMAGE_WEBP_INITIAL_QUALITY=80 # Default initial quality for image-to-WEBP conversion
OUTPUT_DIR="./ordinal" # Output directory relative to script CWD

# Variables to store values from positional arguments and CLI options
POS_INPUT_VIDEO=""
POS_OUTPUT_GIF_BASENAME=""
POS_OUTPUT_WEBP_BASENAME=""
SERVER_CALL=false
CMD_VIDEO_WEBP_QUALITY="" # For -Q option
CMD_IMAGE_WEBP_QUALITY="" # For -Y option


# Check for positional arguments (server call)
if [[ -n "$1" && "$1" != -* ]] && [ -n "$2" ] && [ -n "$3" ]; then
  POS_INPUT_VIDEO="$1"
  POS_OUTPUT_GIF_BASENAME="$2"
  POS_OUTPUT_WEBP_BASENAME="$3"
  SERVER_CALL=true
  echo "Running in server mode with positional arguments:"
  echo "  Input Video: ${POS_INPUT_VIDEO}"
  echo "  Output GIF Basename: ${POS_OUTPUT_GIF_BASENAME}"
  echo "  Output WEBP Basename: ${POS_OUTPUT_WEBP_BASENAME}"
  # In server mode, we might always want to try both GIF and (eventually) WEBP from video.
  # For now, CONVERSION_TYPE will be handled by getopts or default to 'gif'.
  # Later, we will ensure both are processed if POS_OUTPUT_WEBP_BASENAME is set.
fi

# Function to display usage
usage() {
  echo "Usage: $0 [-i <input_video>] [-o <output_gif_basename>] [-w <width>] [-f <frame_interval>] [-c <colors>] [-t <type>] [-p <input_image>]"
  echo "       $0 <input_video_path> <output_gif_basename> <output_webp_basename>"
  echo ""
  echo "Options for command-line usage:"
  echo "  -i <input_video>    : Path to the input video file (required for gif type)"
  echo "  -o <output_gif_basename> : Base name of the output GIF file (default: ${OUTPUT_GIF_BASENAME})"
  echo "  -w <width>          : Desired width of the GIF (maintains 9:16 aspect ratio, default: 150)"
  echo "  -f <frame_interval> : Interval for extracting frames (e.g., 5 for every 5th frame, default: 5)"
  echo "  -c <colors>         : Number of colors for optimization (default: 64)"
  echo "  -t <type>           : Type of conversion (gif, webp, or all if using positional args; default: gif)"
  echo "  -p <input_image>    : Path to the input image file (JPEG, PNG, or SVG) for WEBP conversion (used if type is webp and not a server call)"
  echo "  -Q <quality>        : Quality for video-to-WEBP conversion (1-100, default: ${WEBP_QUALITY})"
  echo "  -Y <quality>        : Initial quality for image-to-WEBP conversion (1-100, default: ${IMAGE_WEBP_INITIAL_QUALITY})"
  echo ""
  echo "Positional arguments for server/automated calls (takes precedence):"
  echo "  <input_video_path>      : Path to the input video file."
  echo "  <output_gif_basename>   : Base name for the output GIF file."
  echo "  <output_webp_basename>  : Base name for the output WEBP file (video to WEBP)."
  exit 1
}

# Default value for conversion type
CONVERSION_TYPE="gif"

# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"
if [ $? -ne 0 ]; then
  echo "Error: Could not create output directory '${OUTPUT_DIR}'." >&2
  exit 1 # Critical failure if output directory cannot be created
fi

# Function to convert video to WEBP
convert_video_to_webp() {
  local input_video_path="$1"
  local output_webp_basename="$2"
  local width_param="$3"
  local frame_interval_param="$4"
  local quality_param="$5"

  echo "Starting video to WEBP conversion for '${input_video_path}'..." # Info to stdout

  # Check for img2webp and attempt installation if missing
  if ! command -v img2webp &> /dev/null; then
    echo "Info: img2webp command not found. Attempting to install webp package..." >&2
    if command -v apt-get &> /dev/null; then
      sudo apt-get update && sudo apt-get install -y webp
      if [ $? -ne 0 ]; then
        echo "Error: 'apt-get install webp' failed. Please install webp (for img2webp) manually." >&2
        return 1
      fi
    elif command -v yum &> /dev/null; then
      sudo yum install -y libwebp-tools
      if [ $? -ne 0 ]; then
        echo "Error: 'yum install libwebp-tools' failed. Please install webp (for img2webp) manually." >&2
        return 1
      fi
    else
      echo "Error: Cannot determine package manager (apt-get/yum). Please install webp (for img2webp) manually." >&2
      return 1
    fi

    if ! command -v img2webp &> /dev/null; then
      echo "Error: img2webp still not found after attempted installation. Please install it manually and ensure it's in PATH." >&2
      return 1
    fi
    echo "Info: img2webp installed successfully via package manager." # Info to stdout
  fi

  local height_param=$((width_param * 16 / 9))
  local temp_frame_dir="./webp_frames_tmp" # Unique temporary directory for WEBP frames
  local final_webp_path="${OUTPUT_DIR}/${output_webp_basename}.webp"

  mkdir -p "${temp_frame_dir}"
  if [ $? -ne 0 ]; then
    echo "Error: Could not create temporary directory ${temp_frame_dir} for WEBP frames." >&2
    return 1
  fi

  echo "Extracting frames for WEBP from ${input_video_path} to ${temp_frame_dir}..."
  # For server-side, it might be better to capture its stderr if it's useful for debugging.
  # For now, let's keep its stderr visible for debugging, but our script's errors are explicit.
  ffmpeg -i "${input_video_path}" \
    -vf "select='not(mod(n,${frame_interval_param}))',scale=-1:${height_param},crop=${width_param}:${height_param}" \
    -vsync vfr -qscale:v 2 \
    "${temp_frame_dir}/frame_%03d.png"

  if [ $? -ne 0 ]; then
    echo "Error: FFmpeg failed to extract frames for WEBP from '${input_video_path}'." >&2
    rm -rf "${temp_frame_dir}" # Clean up
    return 1
  fi

  # Check if frames were extracted
  if ! ls "${temp_frame_dir}/frame_"*.png 1> /dev/null 2>&1; then
    echo "Error: No frames were extracted by FFmpeg for WEBP conversion from '${input_video_path}'. Expected frames in ${temp_frame_dir}." >&2
    rm -rf "${temp_frame_dir}" # Clean up
    return 1
  fi
  
  echo "Creating animated WEBP '${final_webp_path}' with quality ${quality_param}..." # Info to stdout
  img2webp -loop 0 -d 80 -q "${quality_param}" "${temp_frame_dir}/frame_"*.png -o "${final_webp_path}"

  if [ $? -ne 0 ]; then
    echo "Error: img2webp failed to create animated WEBP for '${output_webp_basename}.webp'." >&2
    rm -rf "${temp_frame_dir}" # Clean up
    # Also remove potentially incomplete output file
    rm -f "${final_webp_path}" 2>/dev/null
    return 1
  fi

  echo "Successfully created animated WEBP: ${final_webp_path}" # Info to stdout
  ls -lh "${final_webp_path}" # Info to stdout

  echo "Cleaning up temporary WEBP frame files from ${temp_frame_dir}..." # Info to stdout
  rm -rf "${temp_frame_dir}"
  if [ $? -ne 0 ]; then
    echo "Warning: Failed to remove temporary WEBP frame directory '${temp_frame_dir}'." >&2 # Warning, not fatal
  fi

  return 0
}

# Function to convert image to WEBP
# Arg1: input_image_path
# Arg2: output_basename (without .webp extension)
convert_to_webp() {
  local INPUT_IMAGE="$1"
  local output_basename_arg="$2" # New argument for the desired output basename
  local initial_quality_param="$3" # New argument for initial quality

  if [ -z "${output_basename_arg}" ]; then
    echo "Error: Output basename not provided to convert_to_webp function." >&2
    return 1
  fi

  local OUTPUT_WEBP_PATH="${OUTPUT_DIR}/${output_basename_arg}.webp"
  local MAX_SIZE=60000 # 60KB in bytes
  local QUALITY=${initial_quality_param} # Use passed initial quality

  if [ ! -f "$INPUT_IMAGE" ]; then
    echo "Error: Input image '${INPUT_IMAGE}' not found for image-to-WEBP conversion." >&2
    return 1
  fi
  local CURRENT_SIZE # Will be set after first conversion

  echo "Converting '${INPUT_IMAGE}' to WEBP at '${OUTPUT_WEBP_PATH}'..." # Info to stdout

  convert "$INPUT_IMAGE" -quality "$QUALITY" "$OUTPUT_WEBP_PATH"
  if [ $? -ne 0 ]; then
    echo "Error: ImageMagick 'convert' failed for '${INPUT_IMAGE}' during initial conversion." >&2
    return 1
  fi

  CURRENT_SIZE=$(stat -c "%s" "$OUTPUT_WEBP_PATH")
  if [ $? -ne 0 ]; then
    # This implies the file might not exist or is inaccessible.
    echo "Error: 'stat' command failed for '${OUTPUT_WEBP_PATH}' after initial conversion. File might not have been created." >&2
    rm -f "$OUTPUT_WEBP_PATH" 2>/dev/null # Attempt to clean up
    return 1
  fi

  while [ "$CURRENT_SIZE" -gt "$MAX_SIZE" ] && [ "$QUALITY" -gt 10 ]; do
    QUALITY=$((QUALITY - 5))
    echo "Reducing quality to ${QUALITY} for '${OUTPUT_WEBP_PATH}' to meet size requirement..." # Info to stdout
    convert "$INPUT_IMAGE" -quality "$QUALITY" "$OUTPUT_WEBP_PATH"
    if [ $? -ne 0 ]; then
      echo "Error: ImageMagick 'convert' (reducing quality) failed for '${INPUT_IMAGE}'." >&2
      return 1
    fi
    CURRENT_SIZE=$(stat -c "%s" "$OUTPUT_WEBP_PATH")
    if [ $? -ne 0 ]; then
      echo "Error: 'stat' command (in loop) failed for '${OUTPUT_WEBP_PATH}'. File might be missing or inaccessible." >&2
      return 1
    fi
  done

  if [ "$CURRENT_SIZE" -gt "$MAX_SIZE" ]; then
    # This is a warning, not an error that stops the script; the file was still created.
    echo "Warning: Could not reduce file size for '${OUTPUT_WEBP_PATH}' below ${MAX_SIZE} bytes. Current size: ${CURRENT_SIZE} bytes." >&2
  else
    echo "Successfully converted '${INPUT_IMAGE}' to '${OUTPUT_WEBP_PATH}' with size ${CURRENT_SIZE} bytes." # Info to stdout
  fi
  # Function returns 0 (success) even if the size warning was issued, as a WEBP file was generated.
  return 0
}

# Parse command line options
# If server call, positional arguments already set some values.
# Getopts can override or supplement these for CLI usage.
while getopts "i:o:w:f:c:t:p:Q:Y:" opt; do
  case "${opt}" in
    i)
      INPUT_VIDEO=${OPTARG} # CLI can override positional $1
      ;;
    o)
      OUTPUT_GIF_BASENAME=${OPTARG} # CLI can override positional $2
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
      INPUT_IMAGE_ARG=${OPTARG} # Store -p argument separately
      ;;
    Q)
      CMD_VIDEO_WEBP_QUALITY=${OPTARG}
      if ! [[ "$CMD_VIDEO_WEBP_QUALITY" =~ ^[0-9]+$ ]] || [ "$CMD_VIDEO_WEBP_QUALITY" -lt 1 ] || [ "$CMD_VIDEO_WEBP_QUALITY" -gt 100 ]; then
        echo "Error: Invalid value for -Q. Must be a number between 1 and 100." >&2
        usage
      fi
      ;;
    Y)
      CMD_IMAGE_WEBP_QUALITY=${OPTARG}
      if ! [[ "$CMD_IMAGE_WEBP_QUALITY" =~ ^[0-9]+$ ]] || [ "$CMD_IMAGE_WEBP_QUALITY" -lt 1 ] || [ "$CMD_IMAGE_WEBP_QUALITY" -gt 100 ]; then
        echo "Error: Invalid value for -Y. Must be a number between 1 and 100." >&2
        usage
      fi
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

# Determine effective quality settings
EFFECTIVE_VIDEO_WEBP_QUALITY=${CMD_VIDEO_WEBP_QUALITY:-$WEBP_QUALITY}
EFFECTIVE_IMAGE_WEBP_INITIAL_QUALITY=${CMD_IMAGE_WEBP_QUALITY:-$IMAGE_WEBP_INITIAL_QUALITY}


# If server call, POS_INPUT_VIDEO and POS_OUTPUT_GIF_BASENAME take precedence
if [ "$SERVER_CALL" = true ]; then
  INPUT_VIDEO="${POS_INPUT_VIDEO}"
  OUTPUT_GIF_BASENAME="${POS_OUTPUT_GIF_BASENAME}"
  OUTPUT_WEBP_BASENAME="${POS_OUTPUT_WEBP_BASENAME}" # Used for video-to-webp later
  # If called with 3 args, implies we want both GIF and WEBP from the video
  # We'll handle this by attempting GIF, then later WEBP.
  # CONVERSION_TYPE from -t might be ignored or adapted if server call.
  # For now, if server call, let's ensure GIF processing happens.
  # If -t was explicitly set, it will be honored for CLI, otherwise 'gif' is default.
  # If server call, we might imply "all" or "gif_and_video_webp"
fi

# Determine final GIF output path
FINAL_GIF_PATH="${OUTPUT_DIR}/${OUTPUT_GIF_BASENAME}.gif"
# Determine final WEBP output path (for video to WEBP, if applicable)
FINAL_WEBP_PATH_FROM_VIDEO="${OUTPUT_DIR}/${OUTPUT_WEBP_BASENAME}.webp"


# Perform actions based on conversion type or server call
# For server call, we will attempt GIF creation. Video-to-WEBP will be a separate logic block later.

# GIF Creation Logic
if [ "${CONVERSION_TYPE}" = "gif" ] || [ "$SERVER_CALL" = true ]; then
  if [ -z "${INPUT_VIDEO}" ]; then
    echo "Error: Input video not specified for GIF conversion. Use -i option or provide as first positional argument." >&2
    usage # usage also exits
  fi
  if [ ! -f "${INPUT_VIDEO}" ]; then
    echo "Error: Input video file '${INPUT_VIDEO}' not found for GIF conversion." >&2
    exit 1 # Fatal for this path
  fi

  # Calculate height for 9:16 aspect ratio
  HEIGHT=$((WIDTH * 16 / 9))\n
  # Temporary GIF name in CWD
  TEMP_GIF_CWD="temp_${OUTPUT_GIF_BASENAME}.gif"

  # Step 1: Extract Frames
  echo "Extracting frames for GIF from '${INPUT_VIDEO}' to CWD..." # Info to stdout
  ffmpeg -i "${INPUT_VIDEO}" \
    -vf "select='not(mod(n,${FRAME_INTERVAL}))',scale=-1:${HEIGHT},crop=${WIDTH}:${HEIGHT}" \
    -vsync vfr \
    frame_%03d.png"

  if [ $? -ne 0 ]; then
    echo "Error: FFmpeg failed to extract frames for GIF from '${INPUT_VIDEO}'." >&2
    exit 1 # Fatal for GIF creation
  fi
  
  if ! ls frame_*.png 1> /dev/null 2>&1; then
    echo "Error: No frames were extracted by FFmpeg for GIF conversion from '${INPUT_VIDEO}'. Expected frame_*.png in CWD." >&2
    exit 1 # Fatal for GIF creation
  fi

  # Step 2: Create Basic GIF in CWD
  echo "Creating basic GIF ('${TEMP_GIF_CWD}')..." # Info to stdout
  convert -delay 8 -loop 0 frame_*.png \
    -background transparent \
    "${TEMP_GIF_CWD}"

  if [ $? -ne 0 ]; then
    echo "Error: ImageMagick 'convert' failed to create basic GIF '${TEMP_GIF_CWD}'." >&2
    rm frame_*.png 2>/dev/null # Clean up frames
    exit 1 # Fatal for GIF creation
  fi

  # Step 3: Optimize Colors and Size with Gifsicle in CWD
  echo "Optimizing GIF ('${TEMP_GIF_CWD}') with Gifsicle..." # Info to stdout
  gifsicle --colors "${COLORS}" --optimize=3 -O3 -b "${TEMP_GIF_CWD}"

  if [ $? -ne 0 ]; then
    echo "Error: Gifsicle optimization failed for '${TEMP_GIF_CWD}'." >&2
    rm frame_*.png 2>/dev/null # Clean up frames
    rm "${TEMP_GIF_CWD}" 2>/dev/null # Clean up temp GIF
    exit 1 # Fatal for GIF creation
  fi

  # Step 4: Move final GIF to output directory
  echo "Moving '${TEMP_GIF_CWD}' to '${FINAL_GIF_PATH}'..." # Info to stdout
  mv "${TEMP_GIF_CWD}" "${FINAL_GIF_PATH}"

  if [ $? -ne 0 ]; then
    echo "Error: Failed to move the final GIF from '${TEMP_GIF_CWD}' to '${FINAL_GIF_PATH}'." >&2
    rm frame_*.png 2>/dev/null # Clean up frames
    # Temp GIF might still be in CWD if mv failed
    if [ -f "${TEMP_GIF_CWD}" ]; then # Check if temp file still exists
        echo "Warning: Temporary GIF '${TEMP_GIF_CWD}' may still exist in CWD after move failure." >&2
    fi
    exit 1 # Fatal for GIF creation
  fi

  echo "GIF creation and optimization complete: ${FINAL_GIF_PATH}" # Info to stdout
  echo "Final size:" # Info to stdout
  ls -lh "${FINAL_GIF_PATH}" # Info to stdout

  # Clean up extracted frames
  echo "Cleaning up temporary GIF frame files (frame_*.png)..." # Info to stdout
  rm frame_*.png 2>/dev/null
  if [ $? -ne 0 ]; then
      echo "Warning: Failed to remove temporary GIF frame files (frame_*.png) from CWD." >&2
  fi
  echo "GIF processing done." # Info to stdout
fi


# WEBP Conversion Logic (from image, using -t webp -p <image_path> -o <output_basename>)
if [ "${CONVERSION_TYPE}" = "webp" ] && [ "$SERVER_CALL" = false ]; then
  if [ -z "${INPUT_IMAGE_ARG}" ]; then
    echo "Error: Input image (-p) not specified for image-to-WEBP conversion." >&2
    usage # usage also exits
  fi
  # For image-to-WEBP CLI conversion, -o (which sets OUTPUT_GIF_BASENAME) is now mandatory for the output file name.
  if [ -z "${OUTPUT_GIF_BASENAME}" ] || [ "${OUTPUT_GIF_BASENAME}" = "default_output" ]; then
    echo "Error: Output basename (-o) not specified for image-to-WEBP conversion." >&2
    usage # usage also exits
  fi
  
  convert_to_webp "${INPUT_IMAGE_ARG}" "${OUTPUT_GIF_BASENAME}" "${EFFECTIVE_IMAGE_WEBP_INITIAL_QUALITY}"
  if [ $? -ne 0 ]; then
    # Specific error message already printed by convert_to_webp function to stderr
    echo "Error: Image-to-WEBP conversion process failed for '${INPUT_IMAGE_ARG}' to output '${OUTPUT_GIF_BASENAME}.webp' with initial quality ${EFFECTIVE_IMAGE_WEBP_INITIAL_QUALITY}. See previous errors for details." >&2
    # Depending on desired script behavior, this could exit 1.
    # For now, it doesn't exit, similar to video-to-webp server call.
  fi
fi

# Video-to-WEBP logic if called from server (using positional arguments)
if [ "$SERVER_CALL" = true ] && [ -n "${OUTPUT_WEBP_BASENAME}" ]; then
  if [ -z "${INPUT_VIDEO}" ]; then
    # This condition should ideally be caught by the GIF section if it's also supposed to run.
    # However, if CONVERSION_TYPE was somehow not 'gif' and it's a server call, INPUT_VIDEO might be empty.
    echo "Error: Input video not specified for video-to-WEBP conversion (was it set by positional arg \$1?)." >&2
  elif [ ! -f "${INPUT_VIDEO}" ]; then
    echo "Error: Input video file '${INPUT_VIDEO}' not found for video-to-WEBP conversion." >&2
  else
    echo "Attempting video to WEBP conversion for '${FINAL_WEBP_PATH_FROM_VIDEO}' using quality ${EFFECTIVE_VIDEO_WEBP_QUALITY}..." # Info to stdout
    convert_video_to_webp "${INPUT_VIDEO}" "${OUTPUT_WEBP_BASENAME}" "${WIDTH}" "${FRAME_INTERVAL}" "${EFFECTIVE_VIDEO_WEBP_QUALITY}"
    if [ $? -ne 0 ]; then
        # Specific error message already printed by convert_video_to_webp function to stderr
        echo "Error: Video-to-WEBP conversion process failed for '${OUTPUT_WEBP_BASENAME}.webp'. See previous errors for details." >&2
        # Script continues; server.js can check for file existence
    else
        echo "Video-to-WEBP conversion process successful: ${FINAL_WEBP_PATH_FROM_VIDEO}" # Info to stdout
    fi
  fi
fi


# Final check for invalid CONVERSION_TYPE if not a server call and not 'gif' or 'webp'
if [ "$SERVER_CALL" = false ] && [ "${CONVERSION_TYPE}" != "gif" ] && [ "${CONVERSION_TYPE}" != "webp" ]; then
  echo "Error: Invalid conversion type '${CONVERSION_TYPE}'. Must be 'gif' or 'webp' for CLI usage." >&2
  usage # usage also exits
fi

echo "Script finished." # Info to stdout
