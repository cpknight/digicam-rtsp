#!/bin/bash

# Base temporary directory
BASE_TEMP_DIR="/tmp/digicam-rtsp"
# Generate a random subdirectory name
RANDOM_ID="instance_$RANDOM"
TEMP_DIR="$BASE_TEMP_DIR/$RANDOM_ID"
SNAPSHOT_FILE="$TEMP_DIR/snapshot.jpg"
CAPTURE_SCRIPT="$TEMP_DIR/capture_snapshots.sh"
CAPTURE_PID_FILE="$TEMP_DIR/capture.pid"
DEBUG_LOG="$TEMP_DIR/debug.log"
LAST_DEBUG_LOG="$BASE_TEMP_DIR/last_debug.log"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo) for gPhoto2 camera access." >&2
    exit 1
fi

# Function to log messages to debug log
log_message() {
    if [ -f "$DEBUG_LOG" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$DEBUG_LOG" 2>/dev/null || {
            echo "Warning: Failed to write to debug log at $DEBUG_LOG" >&2
        }
    fi
}

# Function to check directory permissions
check_dir_writable() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || {
            echo "Error: Cannot create directory $dir (check permissions or disk space)" >&2
            exit 1
        }
    fi
    if [ ! -w "$dir" ]; then
        echo "Error: Directory $dir is not writable" >&2
        exit 1
    fi
}

# Function to write the capture script
write_capture_script() {
    echo "Main script: Writing capture script to $CAPTURE_SCRIPT..."
    cat > "$CAPTURE_SCRIPT" << 'EOF'
#!/bin/bash

TEMP_DIR="$1"
SNAPSHOT_FILE="$TEMP_DIR/snapshot.jpg"
DEBUG_LOG="$TEMP_DIR/debug.log"
COUNTER=0

# Log function for capture script
log_message() {
    if [ -f "$DEBUG_LOG" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$DEBUG_LOG" 2>/dev/null
    fi
}

log_message "Capture script started"
# Check if gphoto2 is installed
if ! command -v gphoto2 >/dev/null 2>&1; then
    log_message "Error: gphoto2 not installed"
    exit 1
fi
while true; do
    CURRENT_SNAPSHOT="$TEMP_DIR/snapshot_$COUNTER.jpg"
    log_message "Capturing snapshot to $CURRENT_SNAPSHOT"
    gphoto2 --capture-image-and-download --filename "$CURRENT_SNAPSHOT" >>"$DEBUG_LOG" 2>&1
    if [ $? -eq 0 ] && [ -f "$CURRENT_SNAPSHOT" ]; then
        mv "$CURRENT_SNAPSHOT" "$SNAPSHOT_FILE" 2>>"$DEBUG_LOG"
        log_message "Updated snapshot to $SNAPSHOT_FILE"
    else
        log_message "Warning: Snapshot capture failed"
    fi
    ((COUNTER++))
    find "$TEMP_DIR" -name "snapshot_*.jpg" -delete 2>>"$DEBUG_LOG"
    log_message "Cleaned up old snapshots"
    sleep 12
done
EOF
    if [ $? -eq 0 ] && [ -f "$CAPTURE_SCRIPT" ]; then
        log_message "Capture script written successfully"
        chmod +x "$CAPTURE_SCRIPT" 2>>"$DEBUG_LOG" || {
            log_message "Error: Failed to make $CAPTURE_SCRIPT executable"
            echo "Error: Cannot make capture script executable at $CAPTURE_SCRIPT" >&2
            cleanup
            exit 1
        }
    else
        log_message "Error: Failed to write capture script to $CAPTURE_SCRIPT"
        echo "Error: Cannot write capture script to $CAPTURE_SCRIPT" >&2
        cleanup
        exit 1
    fi
}

# Cleanup function for shutdown
cleanup() {
    # Prevent multiple cleanup calls
    trap '' EXIT INT TERM
    echo "Main script: Initiating cleanup..." >&2
    log_message "Initiating cleanup"
    # Stop capture process if running
    if [ -f "$CAPTURE_PID_FILE" ]; then
        CAPTURE_PID=$(cat "$CAPTURE_PID_FILE" 2>/dev/null)
        if [ -n "$CAPTURE_PID" ] && ps -p "$CAPTURE_PID" > /dev/null; then
            log_message "Stopping capture process (PID: $CAPTURE_PID)"
            echo "Main script: Stopping capture process (PID: $CAPTURE_PID)..." >&2
            kill "$CAPTURE_PID" 2>>"$DEBUG_LOG"
            wait "$CAPTURE_PID" 2>>"$DEBUG_LOG"
        fi
        rm -f "$CAPTURE_PID_FILE" 2>>"$DEBUG_LOG"
    fi
    # Stop ffmpeg if running
    if [ -n "$FFMPEG_PID" ]; then
        log_message "Stopping ffmpeg (PID: $FFMPEG_PID)"
        echo "Main script: Stopping ffmpeg (PID: $FFMPEG_PID)..." >&2
        kill "$FFMPEG_PID" 2>>"$DEBUG_LOG"
        wait "$FFMPEG_PID" 2>>"$DEBUG_LOG"
    fi
    # Copy debug log for post-mortem analysis
    if [ -f "$DEBUG_LOG" ]; then
        cp "$DEBUG_LOG" "$LAST_DEBUG_LOG" 2>/dev/null
        log_message "Copied debug log to $LAST_DEBUG_LOG"
    fi
    # Remove temp files for this instance
    log_message "Removing temporary files in $TEMP_DIR"
    echo "Main script: Removing temporary files..." >&2
    rm -rf "$TEMP_DIR" 2>/dev/null
    log_message "Cleanup complete"
    echo "Main script: Cleanup complete." >&2
    # Exit to prevent further execution
    exit 0
}

# Trap signals for graceful shutdown
trap cleanup EXIT INT TERM

# Startup: Check and create directories
echo "Main script: Checking base temp directory $BASE_TEMP_DIR..." >&2
check_dir_writable "$BASE_TEMP_DIR"
check_dir_writable "$TEMP_DIR"
# Create debug log file
touch "$DEBUG_LOG" 2>/dev/null || {
    echo "Error: Cannot create debug log at $DEBUG_LOG" >&2
    rm -rf "$TEMP_DIR"
    exit 1
}
log_message "Debug log initialized"

# Startup cleanup: Remove all existing subdirectories and processes
echo "Main script: Performing startup cleanup..." >&2
log_message "Performing startup cleanup"
find "$BASE_TEMP_DIR" -maxdepth 1 -type d -not -path "$BASE_TEMP_DIR" -not -path "$TEMP_DIR" | while read -r subdir; do
    pid_file="$subdir/capture.pid"
    if [ -f "$pid_file" ]; then
        OLD_PID=$(cat "$pid_file" 2>/dev/null)
        if [ -n "$OLD_PID" ] && ps -p "$OLD_PID" > /dev/null; then
            log_message "Found old capture process (PID: $OLD_PID) in $subdir, terminating"
            echo "Main script: Found old capture process (PID: $OLD_PID) in $subdir, terminating..." >&2
            kill "$OLD_PID" 2>/dev/null
            wait "$OLD_PID" 2>/dev/null
        fi
    fi
    log_message "Removing old subdirectory $subdir"
    echo "Main script: Removing old subdirectory $subdir..." >&2
    rm -rf "$subdir" 2>/dev/null
done

# Check gphoto2 and ffmpeg availability
echo "Main script: Checking dependencies..." >&2
if ! command -v gphoto2 >/dev/null 2>&1; then
    log_message "Error: gphoto2 not installed"
    echo "Error: gphoto2 is not installed. Please install it (e.g., sudo apt-get install gphoto2)" >&2
    cleanup
    exit 1
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
    log_message "Error: ffmpeg not installed"
    echo "Error: ffmpeg is not installed. Please install it (e.g., sudo apt-get install ffmpeg)" >&2
    cleanup
    exit 1
fi
log_message "Dependencies checked: gphoto2 and ffmpeg found"

# Check for camera
echo "Main script: Checking for camera..." >&2
log_message "Checking for camera with gphoto2 --auto-detect"
CAMERA_OUTPUT=$(gphoto2 --auto-detect 2>&1)
if echo "$CAMERA_OUTPUT" | grep -q "No camera detected"; then
    log_message "Error: No camera detected by gphoto2"
    echo "Error: No camera detected. Please connect a camera and try again." >&2
    cleanup
    exit 1
elif [ -z "$CAMERA_OUTPUT" ] || ! echo "$CAMERA_OUTPUT" | grep -q "usb:"; then
    log_message "Warning: Camera detection unclear, proceeding but may fail"
    echo "Warning: No clear camera detection. Proceeding, but capture may fail." >&2
fi
log_message "Camera check output: $CAMERA_OUTPUT"

# Write and start the capture script
write_capture_script
echo "Main script: Starting capture script..." >&2
log_message "Starting capture script"
if [ -f "$CAPTURE_SCRIPT" ]; then
    "$CAPTURE_SCRIPT" "$TEMP_DIR" &
    CAPTURE_PID=$!
    echo $CAPTURE_PID > "$CAPTURE_PID_FILE" 2>>"$DEBUG_LOG" || {
        log_message "Error: Failed to write PID to $CAPTURE_PID_FILE"
        echo "Error: Cannot write PID to $CAPTURE_PID_FILE" >&2
        cleanup
        exit 1
    }
    log_message "Capture script started (PID: $CAPTURE_PID)"
    echo "Main script: Capture script started (PID: $CAPTURE_PID)" >&2
else
    log_message "Error: Capture script $CAPTURE_SCRIPT does not exist"
    echo "Error: Capture script $CAPTURE_SCRIPT does not exist" >&2
    cleanup
    exit 1
fi

# Wait for the first snapshot with timeout (30 seconds)
echo "Main script: Waiting for first snapshot at $SNAPSHOT_FILE..." >&2
log_message "Waiting for first snapshot at $SNAPSHOT_FILE"
TIMEOUT=30
START_TIME=$(date +%s)
while [ ! -f "$SNAPSHOT_FILE" ]; do
    sleep 1
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    if [ $ELAPSED -ge $TIMEOUT ]; then
        log_message "Error: Timeout waiting for first snapshot after ${TIMEOUT} seconds"
        echo "Main script: Error: Timeout waiting for first snapshot after ${TIMEOUT} seconds." >&2
        echo "Debug log contents:" >&2
        if [ -f "$DEBUG_LOG" ]; then
            cat "$DEBUG_LOG" >&2
        else
            echo "No debug log found at $DEBUG_LOG" >&2
        fi
        echo "Last debug log available at: $LAST_DEBUG_LOG" >&2
        cleanup
        exit 1
    fi
    if ! ps -p "$CAPTURE_PID" > /dev/null; then
        log_message "Error: Capture process (PID: $CAPTURE_PID) died unexpectedly"
        echo "Main script: Error: Capture process (PID: $CAPTURE_PID) died unexpectedly." >&2
        echo "Debug log contents:" >&2
        if [ -f "$DEBUG_LOG" ]; then
            cat "$DEBUG_LOG" >&2
        else
            echo "No debug log found at $DEBUG_LOG" >&2
        fi
        echo "Last debug log available at: $LAST_DEBUG_LOG" >&2
        cleanup
        exit 1
    fi
done
log_message "First snapshot detected at $SNAPSHOT_FILE"

# Start ffmpeg streaming
echo "Main script: Starting ffmpeg RTSP stream..." >&2
log_message "Starting ffmpeg RTSP stream"
ffmpeg -re -loop 1 -i "$SNAPSHOT_FILE" -c:v libx264 -g 5 -f rtsp rtsp://localhost:8554/stream 2>>"$DEBUG_LOG" &
FFMPEG_PID=$!
log_message "ffmpeg started (PID: $FFMPEG_PID)"
echo "Main script: ffmpeg started (PID: $FFMPEG_PID)" >&2

# Keep the script running, checking that processes are alive
INTERRUPTED=0
while [ $INTERRUPTED -eq 0 ]; do
    if ! ps -p "$CAPTURE_PID" > /dev/null; then
        log_message "Error: Capture process (PID: $CAPTURE_PID) died"
        echo "Main script: Error: Capture process (PID: $CAPTURE_PID) died." >&2
        echo "Debug log contents:" >&2
        if [ -f "$DEBUG_LOG" ]; then
            cat "$DEBUG_LOG" >&2
        else
            echo "No debug log found at $DEBUG_LOG" >&2
        fi
        echo "Last debug log available at: $LAST_DEBUG_LOG" >&2
        cleanup
        exit 1
    fi
    if ! ps -p "$FFMPEG_PID" > /dev/null; then
        log_message "Error: ffmpeg process (PID: $FFMPEG_PID) died"
        echo "Main script: Error: ffmpeg process (PID: $FFMPEG_PID) died." >&2
        echo "Debug log contents:" >&2
        if [ -f "$DEBUG_LOG" ]; then
            cat "$DEBUG_LOG" >&2
        else
            echo "No debug log found at $DEBUG_LOG" >&2
        fi
        echo "Last debug log available at: $LAST_DEBUG_LOG" >&2
        cleanup
        exit 1
    fi
    sleep 10
done
