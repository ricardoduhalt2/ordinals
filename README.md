# MP4 to Ordinal GIF/WEBP Converter

## Web Application

This project includes a web application that provides a user-friendly interface for converting MP4 videos to optimized GIFs.

### Features:
*   **MP4 to GIF Conversion:** Upload an MP4 video, and the application will convert it into an optimized GIF suitable for Bitcoin Ordinals.
*   **Client-side Feedback:** Provides messages during the upload and conversion process.
*   **Download Links:** Offers direct download links for the generated GIF.

### Usage:
1.  Ensure the server is running (see "Running the Web App" below).
2.  Open `http://localhost:3000` in your web browser.
3.  Choose an MP4 video file using the "Choose File" button.
4.  Click "Convert Video" to start the conversion.
5.  Once complete, download links for the generated GIF will appear.

**Note:** While the underlying `create_ordinal_gif.sh` script supports WEBP conversion from images, the current web application interface is primarily designed for MP4 to GIF conversion. WEBP conversion from video frames is not yet integrated into the web app's direct conversion flow.


## Description
This project provides a script to convert MP4 videos into animated GIFs optimized for inscription as Bitcoin Ordinals. The script focuses on minimizing file size while maintaining acceptable visual quality.

## Requirements
*   FFmpeg
*   ImageMagick
*   Gifsicle

## Usage
```bash
./create_ordinal_gif.sh -i <input_video> [-o <output_gif>] [-w <width>] [-f <frame_interval>] [-c <colors>]
```

### Options:
*   `-i <input_video>`: Path to the input video file (required).
*   `-o <output_gif>`: Name of the output GIF file (default: robe.gif).
*   `-w <width>`: Desired width of the GIF (maintains 9:16 aspect ratio, default: 150).
*   `-f <frame_interval>`: Interval for extracting frames (e.g., 5 for every 5th frame, default: 5).
*   `-c <colors>`: Number of colors for optimization (default: 64).
*   `-t <type>`: Type of conversion (gif or webp, default: gif).
*   `-p <input_image>`: Path to the input image file (JPEG, PNG, or SVG) for WEBP conversion (required if type is webp).

## Technical Details
The script performs the following steps:
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

To convert `Kimono-Preview.mp4` to a GIF with a width of 300 pixels, a frame interval of 10, and 32 colors, use the following command:
```bash
./create_ordinal_gif.sh -i upload/Kimono-Preview.mp4 -o kimono.gif -w 300 -f 10 -c 32 -t gif
```
This will create an optimized GIF named `kimono.gif` in the `ordinal/` directory.

## Executing the Script

To execute the `create_ordinal_gif.sh` script directly, use the following command:

```bash
./create_ordinal_gif.sh -i <input_video> [options]
```

Replace `<input_video>` with the path to your input video file and `[options]` with any desired options.

## Reverting to the Current State

To revert to the current state (without the web app), simply delete the `webapp` directory:

```bash
rm -rf webapp
```

### Running the Web App

1.  Ensure Node.js and npm are installed.
2.  Navigate to the `webapp` directory:
    ```bash
    cd webapp
    ```
3.  Install Node.js dependencies:
    ```bash
    npm install
    ```
4.  Run the server:
    ```bash
    node server.js
    ```
5.  Open your web browser and navigate to `http://localhost:3000`.
