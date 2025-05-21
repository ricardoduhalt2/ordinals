const express = require('express');
console.log(`[SERVER_INFO] __dirname is: ${__dirname}`);
const multer = require('multer');
const { execFile } = require('child_process');
const path = require('path');
const fs = require('fs'); // Added fs for directory creation

const app = express();
const port = 3000;

// --- Middleware ---

// 1. Serve static files (HTML, CSS, JS) from the 'webapp' directory (__dirname)
//    This means index.html, style.css, script.js can be accessed directly.
app.use(express.static(__dirname));

// 2. Serve converted files from the 'webapp/ordinal' directory
//    The create_ordinal_gif.sh script outputs to './ordinal' relative to its CWD.
//    We'll run the script with CWD as 'webapp/', so files go into 'webapp/ordinal/'.
//    These will be accessible via '/ordinal/filename.gif' URL.
const convertedFilesPath = path.join(__dirname, 'ordinal');
app.use('/ordinal', express.static(convertedFilesPath));

// Ensure the output directory for converted files exists
if (!fs.existsSync(convertedFilesPath)) {
    fs.mkdirSync(convertedFilesPath, { recursive: true });
}

// 3. Multer setup for file uploads
//    Store uploaded files in 'webapp/uploads/'
const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        // Sanitize filename and make it unique to avoid collisions
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const originalNameNoExt = path.parse(file.originalname).name.replace(/[^a-zA-Z0-9._-]/g, ''); // Basic sanitization
        const extension = path.extname(file.originalname);
        cb(null, `${originalNameNoExt}-${uniqueSuffix}${extension}`);
    }
});
const upload = multer({ storage: storage });

// --- Routes ---

// Root route (handled by express.static if index.html is in __dirname)

// Handle video upload and conversion
app.post('/upload', upload.single('videoFile'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ message: 'No file uploaded.' });
    }

    // Path of the uploaded file relative to __dirname (webapp/)
    // e.g., 'uploads/myvideo-12345.mp4'
    const inputFileRelativePath = path.relative(__dirname, req.file.path);

    // Generate unique basenames for output files (without extension)
    // Based on the original filename to keep it recognizable
    const originalNameBase = path.basename(req.file.originalname, path.extname(req.file.originalname)).replace(/\s+/g, '_');
    const uniqueTimestamp = Date.now();
    const outputGifBasename = `${originalNameBase}-${uniqueTimestamp}-ordinal`;
    const outputWebpBasename = `${originalNameBase}-${uniqueTimestamp}-ordinal`; // Can be same or different

    // Path to the conversion script (it's one directory up from webapp/)
    const scriptPath = path.join(__dirname, '..', 'create_ordinal_gif.sh');

    // Arguments for create_ordinal_gif.sh: <input_mp4_file> [output_gif_name] [output_webp_name]
    const args = [
        inputFileRelativePath,
        outputGifBasename,
        outputWebpBasename
    ];

    // Options for execFile:
    // Set Current Working Directory (CWD) for the script to be __dirname (i.e., 'webapp/')
    // The script's hardcoded 'mkdir -p ./ordinal' will then create 'webapp/ordinal/'
    const options = {
        cwd: __dirname
    };

    console.log(`Executing: ${scriptPath} ${args.join(' ')} (CWD: ${options.cwd})`);

    execFile(scriptPath, args, options, (error, stdout, stderr) => {
        if (error) {
            console.error(`execFile error: ${error.message}`);
            console.error(`Script stderr: ${stderr}`);
            
            // Optionally, delete the uploaded file on error
            // fs.unlink(req.file.path, (unlinkErr) => {
            //    if (unlinkErr) console.error('Error deleting uploaded file after failed conversion:', unlinkErr);
            // });

            return res.status(500).json({
                message: 'Error during conversion process.',
                error: stderr || error.message, // Prioritize stderr from script for error details
                stdout: stdout // Include stdout for more context if available
            });
        }

        console.log(`Script stdout: ${stdout}`);
        if (stderr) { // Some tools might output warnings to stderr even on success
            console.warn(`Script stderr (possibly warnings): ${stderr}`);
        }

        // Construct URLs for the client to access/download the converted files
        // These paths are relative to the '/ordinal' static route configured earlier
        const gifUrl = `/ordinal/${outputGifBasename}.gif`;
        const webpUrl = `/ordinal/${outputWebpBasename}.webp`;

        res.json({
            message: 'Conversion successful!',
            gifUrl: gifUrl,
            webpUrl: webpUrl,
            script_stdout: stdout
        });
    });
});

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
    console.log(`Serving static files from: ${__dirname}`);
    console.log(`Uploads directory: ${uploadDir}`);
    console.log(`Converted files output to: ${convertedFilesPath}`);
    console.log(`Converted files served from /ordinal path.`);
    console.log(`Ensure 'create_ordinal_gif.sh' is executable (chmod +x create_ordinal_gif.sh in the parent directory).`);
});
