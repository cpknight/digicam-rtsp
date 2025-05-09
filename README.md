# :camera_flash: digicam-rtsp

Stream snapshots from a digital camera as an RTSP feed using **gPhoto2** and **FFmpeg** on **Linux**.

This project provides a Bash script (`digicam-rtsp.sh`) that captures periodic snapshots from a USB-connected digital camera using `gphoto2`, converts them into an RTSP stream with `ffmpeg`, and runs as a systemd service. 

It includes an installer script (`install_digicam_rtsp.sh`) to set up the service on Linux systems. The script is designed for older digital cameras supported by gphoto2, making it ideal for repurposing legacy hardware into a simple surveillance or monitoring feed.

## Features

- Captures snapshots every 12 seconds (5 per minute) from a gPhoto2-supported camera.
- Streams snapshots as an RTSP feed at `rtsp://localhost:8554/stream`.
- Runs as a `systemd` service with automatic restart on failure.
- Includes debug logging to `/tmp/digicam-rtsp/instance_<random>/debug.log`, preserved at `/tmp/digicam-rtsp/last_debug.log` on exit.
- Graceful handling of no camera, timeouts, and CTRL+C interrupts.

## Prerequisites

- `Linux`: Tested on Ubuntu/Debian-like systems; requires `sudo` privileges.
- `gphoto2`: For camera control (`sudo apt-get install gphoto2`).
- `ffmpeg`: For RTSP streaming (`sudo apt-get install ffmpeg`).
- `rtsp-simple-server`: For serving the RTSP stream (download from [github.com/aler9/rtsp-simple-server/releases](https://github.com/aler9/rtsp-simple-server/releases)).
- A USB-connected digital camera supported by `gphoto2` (check with `gphoto2 --list-cameras`).

## Installation

- **Clone the Repository**: `git clone https://github.com/cpknight/digicam-rtsp.git; cd digicam-rtsp`
- **Install `rtsp-simple-server`**:
```bash
wget https://github.com/aler9/rtsp-simple-server/releases/download/v0.21.2/rtsp-simple-server_v0.21.2_linux_amd64.tar.gz
tar -xzvf rtsp-simple-server_v0.21.2_linux_amd64.tar.gz
sudo mv rtsp-simple-server /usr/local/bin/
```
- **Make Scripts Executable**: `chmod +x digicam-rtsp.sh install_digicam_rtsp.sh`
- **Test Manually**: `sudo ./digicam-rtsp.sh`
  - Without a camera, it’ll exit with “Error: No camera detected.”
  - With a camera, test the stream: `vlc rtsp://localhost:8554/stream`.
- **Install as a Service**: `sudo ./install_digicam_rtsp.sh`
  - Installs to `/usr/local/bin/digicam-rtsp.sh` and sets up `/etc/systemd/system/digicam-rtsp.service`.
- **Manage the Service**: 
```bash
sudo systemctl start digicam-rtsp 
sudo systemctl stop digicam-rtsp 
sudo systemctl status digicam-rtsp 
sudo systemctl disable digicam-rtsp # To prevent auto-start
```

## Usage

- **Check Camera Detection**: `sudo gphoto2 --auto-detect`
  - If no camera is listed, ensure it’s connected, powered on, and supported.
- **View Stream**: eg. `vlc rtsp://localhost:8554/stream`
- **Debug Logs**:
  - _During runtime_: `cat /tmp/digicam-rtsp/instance_*/debug.log`
  - _After exit_: `cat /tmp/digicam-rtsp/last_debug.log`

## Customization

### macOS or Windows:

This project is tailored for Linux with specific paths and tools. Here’s how to adapt it (e.g., macOS, Windows):

- **Paths**: Replace `/tmp/digicam-rtsp` in `digicam-rtsp.sh` (line ~5) with a suitable temp directory:
  - `macOS`: `/tmp/digicam-rtsp` works, but `/var/tmp/digicam-rtsp` is more persistent.
  - `Windows` (WSL): Use `/mnt/c/temp/digicam-rtsp` or similar.
- **Installer**: Update `INSTALL_PATH` in `install_digicam_rtsp.sh` (line ~5) to a `bin` directory (e.g., `/usr/local/bin` on macOS, or a custom path on Windows).
- **`Systemd` Service**:
  - `digicam-rtsp.service` is Linux-specific. For macOS, use launchd (create a `.plist` file); for Windows, use Task Scheduler or a service wrapper. Replace `install_digicam_rtsp.sh` with a custom setup script.
- **Tools**: `gphoto2` and `ffmpeg` are available on macOS via Homebrew (`brew install gphoto2 ffmpeg`). On Windows, install via WSL or native binaries, adjusting command paths in `digicam-rtsp.sh`.

### Camera-Specific Tweaks:

- **Unsupported Cameras**:
  - **Check compatibility**: `gphoto2 --list-cameras` and modify the gphoto2 command in digicam-rtsp.sh (line ~50, within `write_capture_script`) with camera-specific flags (e.g., `--port usb:001,002`).
  - **Capture Frequency**: Adjust sleep 12 in `digicam-rtsp.sh` (line ~70) to change snapshot frequency (e.g., `sleep 6` for 10/minute).

### Stream Settings

- **RTSP URL**: Change `rtsp://localhost:8554/stream` in `digicam-rtsp.sh` (line ~300) to a different port or hostname (e.g., `rtsp://0.0.0.0:8555/mystream`).
- **Video Quality**: Modify the `ffmpeg` command in `digicam-rtsp.sh` (line ~300) with options like `-b:v 1M (bitrate)` or `-s 640x480` (resolution).

### Persistent Storage

Change `BASE_TEMP_DIR` in `digicam-rtsp.sh` (line ~5) to `/var/tmp/digicam-rtsp` or a custom path for logs/snapshots to survive reboots.

## Troubleshooting

- **No Camera Detected**: Run `sudo gphoto2 --auto-detect`. If empty, check USB connection or udev rules (e.g., for Canon: `echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", MODE="0666", GROUP="plugdev"' | sudo tee /etc/udev/rules.d/99-canon.rules`).
- **No Stream**: Ensure ffmpeg is installed and test manually: `ffmpeg -re -loop 1 -i test.jpg -f rtsp rtsp://localhost:8554/stream`.
- **Logs Missing**: Verify `/tmp` permissions: `ls -ld /tmp` (should be drwxrwxrwt). Fix with `sudo chmod 1777 /tmp`.

## Credits

- **Generated By**: [**Grok**](https://grok.com), an AI assistant created by [**xAI**](https://x.ai), in collaboration with [**cpknight**](https://github.com/cpknight).
- **License**: [MIT](LICENSE).
