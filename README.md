# MacCompressionDecompression Function Summary

## 1. File Compression
- Supports mainstream formats: ZIP, 7z (LZMA2), and RAR.
- Optional password protection and encryption for content and headers (ZIP/7z).
- Real-time progress updates during compression for UI feedback.
- Uses different libraries for each format: SSZipArchive for ZIP, PLzmaSDK for 7z, and UnrarKit (mainly for extraction, RAR compression is reserved).

## 2. File Extraction
- Supports extracting ZIP, 7z, and RAR files, including password-protected archives.
- Real-time progress updates during extraction; can auto-open the extracted folder in Finder.
- Prompts for password if needed for encrypted archives.
- ZIP extraction uses SSZipArchive, 7z uses PLzmaSDK, RAR uses UnrarKit.

## 3. Archive File/Folder Tree Structure
- Uses the `ArchiveItem` data structure to build a tree view of files and folders inside archives, facilitating file browsing features.

## 4. Finder Extension Support
- Includes a Finder Sync extension for macOS, enabling right-click context menus and batch operations directly in Finder.
- Shares settings and selection data between the main app and extension using App Group.

## 5. Progress and Status Feedback
- Both compression and extraction have detailed progress feedback and pop-up notifications for success or failure.
- Supports progress bar UI updates and automatic folder opening after operations.

## 6. Other Features
- Custom URL Scheme for communication between the extension and main app.
- User-configurable compression level, password toggle, and other preferences.

## Technical Details
- Implemented mainly in Swift, leveraging macOS native frameworks.
- Dependencies: SSZipArchive (ZIP), PLzmaSDK (7z), UnrarKit (RAR), FinderSync (extension).
- Utilizes async tasks and main-thread callbacks to ensure smooth UI and data safety.

## Summary
This project is a macOS tool supporting multi-format archive compression/decompression (ZIP, RAR, 7z), password protection, and Finder integration. It is feature-rich and suitable for both personal and office scenarios.
