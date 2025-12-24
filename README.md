# Camcorder Importer for macOS

Drag an SD card or folder full of AVCHD footage into the app and it will find `.MTS` clips, convert them to MP4 using Apple frameworks, and save them to your Pictures folder.

## Features

- Drag-and-drop import (folders or mounted volumes)
- AVCHD `.MTS` discovery with size filtering
- MP4 export via AVFoundation
- Progress + completion notification
- Output in `~/Pictures/Camcorder Imports/YYYY-MM-DD/`
- Optional fallback output picker if Pictures is not writable

## Requirements

- macOS 13+
- Xcode 15+ recommended

## Usage

1. Build and run the app.
2. Drop an SD card or folder containing `PRIVATE/AVCHD/BDMV/STREAM/*.MTS`.
3. Wait for conversion to finish.
4. Click "Open Output Folder" to view the MP4s.

## Sample Clip (for testing)

You can use the included sample folder:

- `Sample_AVCHD/PRIVATE/AVCHD/BDMV/STREAM/00000.MTS`

Drop the `Sample_AVCHD` folder into the app to test the flow.

## Development Notes

- Conversion is serial to keep resource usage predictable.
- The app uses sandboxed file access; it writes to Pictures by default and will prompt for a custom output folder if needed.

## License

MIT (or choose your preferred license).
