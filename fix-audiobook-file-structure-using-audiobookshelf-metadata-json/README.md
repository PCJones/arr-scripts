## Note: README.MD was AI generated, I just glimpsed over it - make sure to double check!

This Bash script organizes audiobook folders based on metadata and ensures their structure and naming are consistent. It checks for errors, cleans metadata, and can perform moves either *for real* or in *dry-run* mode.  

***

### Overview of What It Does
- **Prompts for a base directory** containing audiobooks and asks whether to run in *dry mode* (simulates actions).
- **Finds all `metadata.json` files** recursively under the base directory.
- For each `metadata.json`:  
  - Reads key metadata: `authors`, `title`, `series`, and `publishedYear`.
  - Checks for problems like:  
    - Empty directories  
    - Extra subdirectories (e.g., nested folders that shouldn’t be there)  
    - Missing audio files (`.mp3`, `.m4b`, `.m4a`) or eBooks (`.epub`)  
  - Detects **double whitespaces** in metadata (e.g., `"John  Doe"` → `"John Doe"`) and offers to fix them with `jq`.
  - Builds the *correct target path* based on metadata:
    ```
    <base>/<authors>/<series>/<title> (Year)
    ```
    or, if no series:
    ```
    <base>/<authors>/<title> (Year)
    ```
  - Moves the directory to this proper location if needed.
  - Removes any empty parent folders left behind.

***

### Example 1 – Normal Move
Suppose the base folder is `/audiobooks`, and inside it you have:
```
/audiobooks/Temp/Book1/
└─ metadata.json (contains authors="John Doe", title="The Lost Ship", publishedYear="2022")
└─ The Lost Ship.m4b
```

If the script runs, the log will show:
```
INFO  Target directory: /audiobooks/John Doe/The Lost Ship (2022)
INFO  Moving "/audiobooks/Temp/Book1" to "/audiobooks/John Doe/The Lost Ship (2022)"
```
The folder will be moved to:
```
/audiobooks/John Doe/The Lost Ship (2022)/
```

***

### Example 2 – Series Book
If the metadata says:
```
authors="Jane Smith"
series="Chronicles of Wind #1"
title="The Beginning"
publishedYear="2021"
```
The script cleans “#1” from the series name and moves it to:
```
/audiobooks/Jane Smith/Chronicles of Wind/The Beginning (2021)/
```

***

### Example 3 – Dry Run Mode
When dry mode is enabled (the default), the script only logs actions:
```
INFO  Dry Run: Would move "/audiobooks/Temp/Book1" to "/audiobooks/John Doe/The Lost Ship (2022)"
```
No files are actually moved or modified.

***

### Key Features
- **Safety checks:** Prevents actions on empty or invalid directories.  
- **Interactive conflict handling:** Pauses when issues are found (e.g., duplicates or missing files).  
- **Metadata sanitation:** Detects and optionally corrects extra whitespaces.  
- **Automatic cleanup:** Removes empty parent directories after successful moves.
