# System Description

This system is a web application that converts MP4 videos to animated GIFs optimized for inscription as Bitcoin Ordinals. The application uses Node.js, Express, and Multer for the backend, and HTML, CSS, and JavaScript for the frontend. The application uses the `create_ordinal_gif.sh` script to perform the actual conversion.

# Problems Encountered

I have encountered several problems while trying to improve the web application:

1.  **File Serving:** I am having trouble serving the static files (CSS and JavaScript) correctly. The browser is showing 404 errors for these files, and the MIME types are not being set correctly.
2.  **Hardcoded Output File Paths:** The output file paths for both GIF and WEBP conversions are hardcoded. This could lead to issues if the script's default output paths change or if the user wants to specify a different output file name.
3.  **Insecure File Path Handling:** The script uses `req.file.path` directly in the command execution. This could be a security risk if the uploaded file path contains malicious characters.
4.  **Lack of Error Handling:** The script only logs errors to the console but doesn't provide detailed error messages to the client.

# Prompt in Markdown Format

```markdown
<task>
lee el readme, las funciones ya funcionan, pero queriamos hacer una web app, intentalo
</task>
<environment_details>
# VSCode Visible Files
webapp/server.js

# VSCode Open Tabs
create_ordinal_gif.sh
webapp/style.css
webapp/script.js
README.md
webapp/index.html
webapp/server.js

# Current Time
16/5/2025, 6:26:15 p.m. (America/Cancun, UTC-5:00)

# Current Working Directory (/home/rich/ordinals) Files
create_ordinal_gif.sh
index.html
Kimono.webp
README.md
script.js
style.css
ordinal/
ordinal/kimono.gif
ordinal/robe.gif
upload/
upload/Kimono-Preview.mp4
upload/img/
upload/img/Kimono.png
upload/img/Maniqui.png
webapp/
webapp/package-lock.json
webapp/package.json
webapp/server.js
webapp/uploads/

# Context Window Usage
0 / 1048,576K tokens used (0%)

# Current Mode
ACT MODE
</environment_details>
