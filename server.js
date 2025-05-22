// --- Utility Functions ---

// Enhanced logging with error stack traces
const logger = (msg, type = 'INFO', error = null) => {
    const timestamp = new Date().toISOString();
    console.log(`[${type}][${timestamp}] ${msg}`);
    if (error && error.stack) {
        console.log(`Stack trace:\n${error.stack}`);
    }
};

// Promisified execFile
const execFileAsync = (cmd, args, options) => {
    return new Promise((resolve, reject) => {
        execFile(cmd, args, options, (error, stdout, stderr) => {
            if (error) {
                logger(`Shell command failed: ${cmd}`, 'ERROR', error);
                logger(`Command output: ${stdout}\nError output: ${stderr}`, 'ERROR');
                reject(error);
                return;
            }
            resolve({ stdout, stderr });
        });
    });
};

// Enhanced shell command validation
const validateShellCommand = async (cmd, args, cwd) => {
    logger(`Validating command: ${cmd} with args: ${JSON.stringify(args)}`, 'DEBUG');
    
    if (!path.isAbsolute(cmd)) {
        cmd = path.join(__dirname, cmd);
    }
    
    if (!fs.existsSync(cmd)) {
        throw new Error(`Command not found: ${cmd}`);
    }
    
    try {
        await fs.promises.access(cmd, fs.constants.X_OK);
    } catch (err) {
        throw new Error(`Command not executable: ${cmd}. Error: ${err.message}`);
    }
    
    if (!fs.existsSync(cwd)) {
        throw new Error(`Working directory does not exist: ${cwd}`);
    }
    
    return true;
};

// Enhanced file cleanup with proper error handling
const cleanupFiles = async (files) => {
    for (const file of files) {
        try {
            if (fs.existsSync(file)) {
                await fs.promises.unlink(file);
                logger(`Cleaned up file: ${file}`, 'INFO');
            }
        } catch (err) {
            logger(`Error cleaning up file ${file}: ${err.message}`, 'ERROR', err);
        }
    }
};

// --- Express Setup ---

const express = require('express');
const multer = require('multer');
const { execFile } = require('child_process');
const path = require('path');
const fs = require('fs'); // Added fs for directory creation

logger(`__dirname is: ${__dirname}`);

const app = express();
const port = 3000;

// --- Routes ---

// Explicitly serve index.html for the root path
app.get('/', (req, res) => {
    const indexPath = path.join(__dirname, 'index.html');
    console.log(`Attempting to serve index.html from: ${indexPath}`);
    res.sendFile(indexPath);
});

// Explicitly serve style.css
app.get('/style.css', (req, res) => {
    res.sendFile(path.join(__dirname, 'style.css'));
});

// Explicitly serve script.js
app.get('/script.js', (req, res) => {
    res.sendFile(path.join(__dirname, 'script.js'));
});


// --- Middleware ---

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

// Enhanced multer configuration
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const originalNameNoExt = path.parse(file.originalname).name.replace(/[^a-zA-Z0-9._-]/g, '');
        const extension = path.extname(file.originalname).toLowerCase();
        cb(null, `${originalNameNoExt}-${uniqueSuffix}${extension}`);
    }
});

const fileFilter = (req, file, cb) => {
    const allowedTypes = {
        'video/mp4': ['.mp4'],
        'image/jpeg': ['.jpg', '.jpeg'],
        'image/png': ['.png'],
        'image/gif': ['.gif']
    };

    const ext = path.extname(file.originalname).toLowerCase();
    const mimeType = file.mimetype;

    if (allowedTypes[mimeType] && allowedTypes[mimeType].includes(ext)) {
        cb(null, true);
    } else {
        cb(new Error('Invalid file type. Only MP4 videos and JPEG/PNG/GIF images are allowed.'), false);
    }
};

const upload = multer({
    storage: storage,
    fileFilter: fileFilter,
    limits: {
        fileSize: 50 * 1024 * 1024, // 50MB limit
    }
});

// Error handling middleware for multer errors
app.use((err, req, res, next) => {
    if (err instanceof multer.MulterError) {
        if (err.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({
                message: 'File too large. Maximum size is 50MB.',
                error: err.message
            });
        }
        return res.status(400).json({
            message: 'File upload error',
            error: err.message
        });
    }
    next(err);
});

// --- Routes ---

// Root route (handled by express.static if index.html is in __dirname)

// Handle video upload and conversion
app.post('/upload', upload.single('videoFile'), async (req, res) => {
    const filesToCleanup = [];
    try {
        if (!req.file) {
            logger('No file uploaded', 'ERROR');
            return res.status(400).json({ message: 'No file uploaded.' });
        }
        
        filesToCleanup.push(req.file.path);
        logger(`File uploaded: ${req.file.originalname} (${req.file.size} bytes)`, 'INFO');

        // Validate file mime type
        if (req.file.mimetype !== 'video/mp4') {
            logger(`Invalid file type: ${req.file.mimetype}`, 'ERROR');
            return res.status(400).json({ 
                message: 'Invalid file type. Only MP4 videos are allowed.',
                error: `Got ${req.file.mimetype}, expected video/mp4`
            });
        }

        // Path of the uploaded file relative to __dirname (webapp/)
        // e.g., 'uploads/myvideo-12345.mp4'
        const inputFileRelativePath = path.relative(__dirname, req.file.path);

        // Generate unique basenames for output files (without extension)
        // Based on the original filename to keep it recognizable
        const originalNameBase = path.basename(req.file.originalname, path.extname(req.file.originalname)).replace(/\s+/g, '_');
        const uniqueTimestamp = Date.now();
        const outputGifBasename = `${originalNameBase}-${uniqueTimestamp}-ordinal-gif`; // Made distinct for clarity
        const outputWebpBasename = `${originalNameBase}-${uniqueTimestamp}-ordinal-webp`; // Made distinct for clarity

        // Path to the conversion script (it's one directory up from webapp/)
        const scriptPath = path.join(__dirname, '..', 'create_ordinal_gif.sh');

        // Arguments for create_ordinal_gif.sh server call mode: 
        // <input_mp4_file> <output_gif_basename> <output_webp_basename>
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

        executeConversionScript(scriptPath, args, options)
            .then(({ stdout, stderr }) => {
                logger(`Script stdout: ${stdout}`, 'INFO');
                if (stderr) {
                    logger(`Script stderr (warnings): ${stderr}`, 'WARN');
                }

                // Construct URL for the client to access/download the converted GIF file
                const gifUrl = `/ordinal/${outputGifBasename}.gif`;
                const responseJson = {
                    message: 'Conversion successful!',
                    gifUrl: gifUrl,
                    script_stdout: stdout
                };

                // Check if WEBP (video) was created and add its URL
                const webpFilePath = path.join(convertedFilesPath, `${outputWebpBasename}.webp`);
                if (fs.existsSync(webpFilePath)) {
                    const webpUrl = `/ordinal/${outputWebpBasename}.webp`;
                    responseJson.webpUrl = webpUrl;
                    console.log(`WEBP (video) file created: ${webpFilePath}`);
                } else {
                    console.log(`WEBP (video) file NOT found: ${webpFilePath}`);
                    // Optionally, you could add a note to the message if WEBP failed but GIF succeeded
                    // responseJson.message = 'GIF Conversion successful! WEBP video conversion failed or was not attempted.';
                }

                res.json(responseJson);
            })
            .catch(({ error, stdout, stderr }) => {
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
            });
    } catch (error) {
        logger(`Error in upload handler: ${error.message}`, 'ERROR');
        await cleanupFiles(filesToCleanup);
        return res.status(500).json({ message: 'Internal server error', error: error.message });
    }
});

// Handle image upload and conversion to WEBP
app.post('/upload-image', upload.single('imageFile'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ message: 'No image file uploaded.' });
    }

    const inputFileRelativePath = path.relative(__dirname, req.file.path);
    const originalNameBase = path.basename(req.file.originalname, path.extname(req.file.originalname)).replace(/\s+/g, '_');
    const uniqueTimestamp = Date.now();
    const outputWebpBasename = `${originalNameBase}-${uniqueTimestamp}-ordinal`;

    const scriptPath = path.join(__dirname, '..', 'create_ordinal_gif.sh');
    const args = [
        '-p', inputFileRelativePath,
        '-o', outputWebpBasename, // Output basename, .webp will be added by script
        '-t', 'webp'
    ];

    const options = {
        cwd: __dirname
    };

    console.log(`Executing for image: ${scriptPath} ${args.join(' ')} (CWD: ${options.cwd})`);

    executeConversionScript(scriptPath, args, options)
        .then(({ stdout, stderr }) => {
            console.log(`Script stdout (image conversion): ${stdout}`);
            if (stderr) {
                console.warn(`Script stderr (image conversion - possibly warnings): ${stderr}`);
            }

            const webpUrl = `/ordinal/${outputWebpBasename}.webp`;

            res.json({
                message: 'Image converted to WEBP successfully!',
                webpUrl: webpUrl,
                script_stdout: stdout
            });
        })
        .catch(({ error, stdout, stderr }) => {
            console.error(`execFile error (image conversion): ${error.message}`);
            console.error(`Script stderr (image conversion): ${stderr}`);
            // Optionally, delete the uploaded file on error
            // fs.unlink(req.file.path, (unlinkErr) => {
            //    if (unlinkErr) console.error('Error deleting uploaded image after failed conversion:', unlinkErr);
            // });
            return res.status(500).json({
                message: 'Error during image conversion process.',
                error: stderr || error.message,
                stdout: stdout
            });
        });
});

const executeConversionScript = (scriptPath, args, options) => {
    return new Promise((resolve, reject) => {
        logger(`Executing script with args: ${JSON.stringify(args)}`, 'DEBUG');
        logger(`Script working directory: ${options.cwd}`, 'DEBUG');

        // Check if script exists
        if (!fs.existsSync(scriptPath)) {
            const error = new Error(`Conversion script not found at: ${scriptPath}`);
            logger(error.message, 'ERROR');
            reject({ error, stdout: '', stderr: error.message });
            return;
        }

        // Check input file
        const inputFile = args[0];
        const inputPath = path.join(options.cwd, inputFile);
        if (!fs.existsSync(inputPath)) {
            const error = new Error(`Input file not found at: ${inputPath}`);
            logger(error.message, 'ERROR');
            reject({ error, stdout, stderr });
            return;
        }

        execFile(scriptPath, args, options, (error, stdout, stderr) => {
            logger(`Script execution output:`, 'DEBUG');
            logger(`STDOUT: ${stdout}`, 'DEBUG');
            if (stderr) logger(`STDERR: ${stderr}`, 'WARN');
            
            if (error) {
                logger(`Script execution error: ${error.message}`, 'ERROR');
                reject({ error, stdout, stderr });
                return;
            }

            // Check if output files exist
            const outputFiles = args.slice(1).map(basename => 
                path.join(options.cwd, 'ordinal', `${basename}.${basename.includes('-webp') ? 'webp' : 'gif'}`));
            
            const missingFiles = outputFiles.filter(file => !fs.existsSync(file));
            if (missingFiles.length > 0) {
                logger(`Expected output files missing: ${missingFiles.join(', ')}`, 'ERROR');
                reject({
                    error: new Error('Output files not created'),
                    stdout,
                    stderr: `Expected files not found: ${missingFiles.join(', ')}`
                });
                return;
            }

            resolve({ stdout, stderr });
        });
    });
};

const cleanupUploadedFile = (filePath) => {
    if (fs.existsSync(filePath)) {
        fs.unlink(filePath, (err) => {
            if (err) {
                logger(`Error deleting temporary file ${filePath}: ${err.message}`, 'ERROR');
            } else {
                logger(`Cleaned up temporary file: ${filePath}`, 'INFO');
            }
        });
    }
};

// Cleanup old files periodically (run every hour)
const CLEANUP_INTERVAL = 60 * 60 * 1000; // 1 hour
const MAX_FILE_AGE = 24 * 60 * 60 * 1000; // 24 hours

const cleanupOldFiles = () => {
    const now = Date.now();
    [uploadDir, path.join(__dirname, 'ordinal')].forEach(dir => {
        fs.readdir(dir, (err, files) => {
            if (err) {
                logger(`Error reading directory ${dir}: ${err.message}`, 'ERROR');
                return;
            }
            
            files.forEach(file => {
                const filePath = path.join(dir, file);
                fs.stat(filePath, (err, stats) => {
                    if (err) {
                        logger(`Error getting file stats for ${filePath}: ${err.message}`, 'ERROR');
                        return;
                    }
                    
                    if (now - stats.mtimeMs > MAX_FILE_AGE) {
                        cleanupUploadedFile(filePath);
                    }
                });
            });
        });
    });
};

setInterval(cleanupOldFiles, CLEANUP_INTERVAL);

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
    console.log(`Serving static files from: ${__dirname}`);
    console.log(`Uploads directory: ${uploadDir}`);
    console.log(`Converted files output to: ${convertedFilesPath}`);
    console.log(`Converted files served from /ordinal path.`);
    console.log(`Ensure 'create_ordinal_gif.sh' is executable (chmod +x create_ordinal_gif.sh in the parent directory).`);
});

// 1. Serve static files (HTML, CSS, JS) from the 'webapp' directory (__dirname)
//    This means index.html, style.css, script.js can be accessed directly.
app.use(express.static(__dirname));
