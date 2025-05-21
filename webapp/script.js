document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('uploadForm');
    const videoFileInput = document.getElementById('videoFile');
    const messageDiv = document.getElementById('message');
    const downloadLinksDiv = document.getElementById('downloadLinks');
    const submitButton = form.querySelector('button[type="submit"]');


    form.addEventListener('submit', async (event) => {
        event.preventDefault();

        if (!videoFileInput.files || videoFileInput.files.length === 0) {
            messageDiv.textContent = 'Please select a video file.';
            return;
        }

        messageDiv.textContent = 'Uploading and converting, please wait...';
        downloadLinksDiv.innerHTML = ''; // Clear previous links
        if(submitButton) submitButton.disabled = true;


        const formData = new FormData();
        formData.append('videoFile', videoFileInput.files[0]);

        try {
            const response = await fetch('/upload', {
                method: 'POST',
                body: formData
            });

            const result = await response.json(); // Server should always respond with JSON

            if (response.ok) {
                messageDiv.textContent = result.message || 'Conversion successful!';
                
                let htmlLinks = '';
                if (result.gifUrl) {
                    htmlLinks += `<p><a href="${result.gifUrl}" download target="_blank">Download GIF: ${result.gifUrl.split('/').pop()}</a></p>`;
                }
                if (result.webpUrl) {
                    htmlLinks += `<p><a href="${result.webpUrl}" download target="_blank">Download WEBP: ${result.webpUrl.split('/').pop()}</a></p>`;
                }
                downloadLinksDiv.innerHTML = htmlLinks;

                if (result.script_stdout) {
                    console.log("Script output:", result.script_stdout);
                     // Optionally display script_stdout somewhere, e.g. messageDiv
                    // messageDiv.innerHTML += `<br><pre>Script log:\n${result.script_stdout}</pre>`;
                }

            } else {
                // Server returned an error (e.g., 400, 500)
                console.error('Server error response:', result);
                let errorMessage = `Error: ${result.message || 'Conversion failed.'}`;
                if (result.error) { // This would contain stderr from the script or error.message
                    errorMessage += `<br>Details: <pre>${result.error}</pre>`;
                }
                if (result.stdout && result.stdout.trim() !== "") { // If stdout has content, it might be useful debug info
                    errorMessage += `<br>Script STDOUT: <pre>${result.stdout}</pre>`;
                }
                messageDiv.innerHTML = errorMessage; // Use innerHTML to render <br> and <pre>
            }
        } catch (error) {
            // Network error, server not reachable, or non-JSON response
            console.error('Client-side fetch error:', error);
            messageDiv.textContent = 'Upload failed. A network error occurred, or the server is unavailable.';
        } finally {
            if(submitButton) submitButton.disabled = false;
            videoFileInput.value = ''; // Clear the file input
        }
    });
});
