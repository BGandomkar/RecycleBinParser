# RecycleBinParser
PowerShell equivalent of Eric Zimmerman's RBCmd.exe. Parses $RECYCLE.BIN $I* files across all partitions to extract metadata from Windows Recycle Bin, including file details and user information. Supports flexible output to CSV file for analysis or console for quick review. Ideal for digital forensics and system auditing tasks.

PowerShell equivalent of Eric Zimmerman's RBCmd.exe, version 1.0.0. Parses $RECYCLE.BIN $I* files across all partitions to extract metadata from Windows Recycle Bin, including file details and user information from UTF-16LE encoded paths. Supports flexible output to a CSV file with -CsvPath for detailed forensic analysis or to the console for quick review. Ideal for digital forensics, system auditing, and incident response, this script processes $I files to retrieve critical data. Requires admin privileges to access Recycle Bin folders. Its modular design allows easy adaptation for evolving forensic needs, making it a valuable tool for investigators and administrators.

## Notes

- **Time Zone**: Script uses EDT (UTC-4) for LastModified and LocalTime. Current time (09:35 PM CEST, September 2, 2025) is UTC+2, but this doesn’t affect the description.
- **Flexibility**: Avoided column names to accommodate potential changes, as requested.
- **Running the Script**:

  - Console: `.\RecycleBinParser.ps1`
  - CSV: `.\RecycleBinParser.ps1 -CsvPath "C:\temp\output.csv"`
