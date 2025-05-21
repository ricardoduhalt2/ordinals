# MP4 to Ordinal GIF/WEBP Converter

## Web Application

This project includes a web application that provides a user-friendly interface for converting MP4 videos to optimized GIFs.

### Features:
*   **MP4 to Ordinal GIF/WEBP Conversion:** Upload an MP4 video, and the application will convert it into an optimized GIF and/or WEBP suitable for Bitcoin Ordinals.
*   **Image to WEBP Conversion:** Upload an image (JPEG, PNG, GIF), and the application will convert it into an optimized WEBP image.
*   **Client-side Feedback:** Provides messages during the upload and conversion process.
*   **Download Links:** Offers direct download links for the generated files.

### Usage:
1.  Ensure the server is running (see "Running the Web App" below).
2.  Open `http://localhost:3000` in your web browser.
3.  **For MP4 to Ordinal GIF/WEBP Conversion:**
    *   Choose an MP4 video file using the "Choose MP4 video" button.
    *   Click "Convert Video" to start the conversion.
    *   Once complete, download links for the generated GIF and/or WEBP will appear.
4.  **For Image to WEBP Conversion:**
    *   Choose an image file (JPEG, PNG, GIF) using the "Choose image" button.
    *   Click "Convert Image to WEBP" to start the conversion.
    *   Once complete, a download link for the generated WEBP image will appear.


## Description
This project provides a script to convert MP4 videos into animated GIFs optimized for inscription as Bitcoin Ordinals. The script focuses on minimizing file size while maintaining acceptable visual quality.

## Requirements
The `create_ordinal_gif.sh` script and the backend server rely on the following command-line tools:
*   **FFmpeg:** For video processing (frame extraction, video-to-WEBP conversion).
*   **ImageMagick:** Specifically the `convert` tool, for image manipulation (creating GIFs, image-to-WEBP conversion).
*   **Gifsicle:** For GIF optimization.
*   **img2webp:** Part of the `webp` or `libwebp-tools` package, for creating animated WEBP from frames (used in video-to-WEBP). The script attempts to install this if missing, but manual installation might be required on some systems.

Ensure these are installed and accessible in your system's PATH.

## Script Usage (`create_ordinal_gif.sh`)
```bash
./create_ordinal_gif.sh [options]
```

### Options:
*   `-i <input_video>`: Path to the input video file (required for GIF or video-to-WEBP conversion).
*   `-o <output_basename>`: Base name for the output file(s) (e.g., `my_animation` will result in `my_animation.gif` and/or `my_animation.webp`). Default depends on the operation.
*   `-w <width>`: Desired width of the GIF (maintains 9:16 aspect ratio, default: 150).
*   `-f <frame_interval>`: Interval for extracting frames (e.g., 5 for every 5th frame, default: 5).
*   `-c <colors>`: Number of colors for optimization (default: 64).
*   `-t <type>`: Type of conversion (gif or webp, default: gif).
*   `-p <input_image>`: Path to the input image file (JPEG, PNG, GIF, or SVG) for image-to-WEBP conversion (required if type is `webp` and not a server call).
*   `-Q <quality>`: Quality for video-to-WEBP conversion (1-100, default: 75).
*   `-Y <quality>`: Initial quality for image-to-WEBP conversion (1-100, default: 80).

### Server Call Mode (Positional Arguments)
The script can also be called with positional arguments, typically by the web server:
`./create_ordinal_gif.sh <input_video_path> <output_gif_basename> <output_webp_basename>`
This mode is used by the backend to generate both GIF and WEBP video from an MP4.

`./create_ordinal_gif.sh -p <input_image_path> -o <output_webp_basename> -t webp`
This mode is used by the backend to convert an uploaded image to WEBP. (Note: `-o` specifies the output basename, `-t webp` specifies the conversion type).


## Technical Details
The script performs the following steps depending on the input and options:
1.  **Frame Extraction:** Extracts frames from the input video using FFmpeg, applying scaling and cropping to maintain a 9:16 aspect ratio.
2.  **GIF Creation:** Creates a basic GIF from the extracted frames using ImageMagick's `convert` command.
3.  **GIF Optimization:** Optimizes the GIF using Gifsicle to reduce the number of colors and overall file size.

The script maintains a 9:16 aspect ratio by calculating the height based on the specified width. Gifsicle is used to optimize the GIF by reducing the number of colors and applying various optimization levels.

## Optimization for Ordinals
This script is designed to create GIFs with the smallest possible file size while preserving reasonable quality, making them suitable for inscription as Bitcoin Ordinals. The `-c` (colors) option is particularly important for reducing file size.

## Example
To convert `Kimono-Preview.mp4` to a GIF with a width of 300 pixels, a frame interval of 10, and 32 colors, use the following command:
```bash
./create_ordinal_gif.sh -i upload/Kimono-Preview.mp4 -o kimono.gif -w 300 -f 10 -c 32
```
This will create an optimized GIF named `kimono.gif` in the `ordinal/` directory.

To convert `upload/img/Kimono.png` to a WEBP image, use the following command:
```bash
./create_ordinal_gif.sh -t webp -p upload/img/Kimono.png
```
This will create an optimized WEBP image named `Kimono.webp` in the `/home/rich/ordinals/` directory. The script will attempt to reduce the file size to below 60KB by adjusting the image quality. Note that it might not always be possible to achieve this size depending on the input image.

To convert `Kimono-Preview.mp4` to a WEBP video with a width of 300 pixels, a frame interval of 10, and a quality of 70, use the following command:
```bash
./create_ordinal_gif.sh -i upload/Kimono-Preview.mp4 -o kimono_video -w 300 -f 10 -Q 70 -t webp
```
This will create an optimized WEBP video named `kimono_video.webp` in the `ordinal/` directory.

## Executing the Script

To execute the `create_ordinal_gif.sh` script directly, ensure it has execute permissions:
```bash
chmod +x create_ordinal_gif.sh
```
Then, run it with the desired options:
```bash
./create_ordinal_gif.sh -i <input_video> [options]
```
Replace `<input_video>` with the path to your input video file and `[options]` with any desired options. Refer to the "Options" section above for details.

## Reverting to the Current State

To revert to the current state (without the web app), simply delete the `webapp` directory:

```bash
rm -rf webapp
```

### Running the Web App

**Prerequisites:**
*   **Core Script Dependencies:** Ensure FFmpeg, ImageMagick (`convert`), Gifsicle, and `img2webp` (from `webp` or `libwebp-tools`) are installed on the system where the Node.js server will run. The `create_ordinal_gif.sh` script relies on these for its conversion tasks.
*   **Node.js and npm:** Ensure Node.js (which includes npm) is installed.

**Steps:**
1.  Navigate to the `webapp` directory:
    ```bash
    cd webapp
    ```
2.  Install Node.js dependencies for the server:
    ```bash
    npm install
    ```
3.  Run the server:
    ```bash
    node server.js
    ```
4.  Open your web browser and navigate to `http://localhost:3000`.
