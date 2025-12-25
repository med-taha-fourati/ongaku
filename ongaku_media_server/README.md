# Ongaku Server

A simple file server for handling music and cover art uploads and downloads for the Ongaku music app.

## Features

- File upload for songs and cover art
- File serving with proper MIME types
- CORS support for cross-origin requests
- Local file system storage
- Simple authentication via user ID

## Prerequisites

- Dart SDK (>= 3.2.0)

## Setup

1. Install dependencies:
   ```bash
   cd ongaku_server
   dart pub get
   ```

2. Run the server:
   ```bash
   dart run bin/server.dart
   ```

3. The server will start on `http://localhost:8080`

## API Endpoints

### Upload a Song
- **URL**: `POST /upload/song`
- **Content-Type**: `multipart/form-data`
- **Parameters**:
  - `userId` (form field): The ID of the user uploading the file
  - `file` (file): The song file to upload
- **Response**:
  ```json
  {
    "url": "/files/songs/[userId]/[filename]"
  }
  ```

### Upload a Cover
- **URL**: `POST /upload/cover`
- **Content-Type**: `multipart/form-data`
- **Parameters**:
  - `userId` (form field): The ID of the user uploading the file
  - `file` (file): The cover image to upload
- **Response**:
  ```json
  {
    "url": "/files/covers/[userId]/[filename]"
  }
  ```

### Get a File
- **URL**: `GET /files/[type]/[userId]/[filename]`
- **Response**: The requested file with appropriate content type

### Health Check
- **URL**: `GET /health`
- **Response**: `Server is running`

## File Structure

Uploaded files are stored in the following structure:
```
ongaku_server/
  uploads/
    songs/
      [user-id]/
        [timestamp]_[filename].mp3
    covers/
      [user-id]/
        [timestamp]_[filename].jpg
```

## Configuration

You can configure the server by modifying the constants at the top of `bin/server.dart`:
- `_hostname`: The hostname to bind to (default: '0.0.0.0')
- `_port`: The port to listen on (default: 8080)
- `_uploadsDir`: The directory to store uploaded files (default: 'uploads')

## Deployment

For production use, consider:
1. Adding authentication/authorization
2. Setting up HTTPS
3. Using a reverse proxy like Nginx
4. Setting up proper file permissions
5. Implementing file cleanup for old/unused files
