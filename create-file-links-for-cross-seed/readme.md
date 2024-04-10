# create-file-links-for-cross-seed

The purpose of this script is to create hard- or symlinks to recreate a folder and filename structure that enables cross-seed to match these files to torrents correctly as currently risky-matching without the original filename only supports torrents with a single file.

The script will use the Radarr API to find all your current movies/files and create a link for them with the original, "imported" filename.
Example

```
[2024-04-10 01:59:10] Processing record for Kung.Fu.Panda.4.2024.1080p.AMZN.WEB-DL.DDP5.1.Atmos.H.264-FLUX
[2024-04-10 01:59:10] [Dry Run] Would create destination folder: /home/jones/test/Kung.Fu.Panda.4.2024.1080p.AMZN.WEB-DL.DDP5.1.Atmos.H.264-FLUX
[2024-04-10 01:59:10] Searching directory: /mnt/storage/data2/Movies/Kung Fu Panda 4 (2024) for files matching base name: Kung\ Fu\ Panda\ 4\ \(2024\)\ \[imdbid-tt21692408\]\ -\ \[AMZN\]\[WEBDL-1080p\]\[EAC3\ Atmos\ 5.1\]\[h264\]-FLUX.*
[2024-04-10 01:59:10] Processing file: /mnt/storage/data2/Movies/Kung Fu Panda 4 (2024)/Kung Fu Panda 4 (2024) [imdbid-tt21692408] - [AMZN][WEBDL-1080p][EAC3 Atmos 5.1][h264]-FLUX.en.srt. Target file name: Kung.Fu.Panda.4.2024.1080p.AMZN.WEB-DL.DDP5.1.Atmos.H.264-FLUX.srt
[2024-04-10 01:59:10] [Dry Run] Would create symbolic link for /mnt/storage/data2/Movies/Kung Fu Panda 4 (2024)/Kung Fu Panda 4 (2024) [imdbid-tt21692408] - [AMZN][WEBDL-1080p][EAC3 Atmos 5.1][h264]-FLUX.en.srt at /home/jones/test/Kung.Fu.Panda.4.2024.1080p.AMZN.WEB-DL.DDP5.1.Atmos.H.264-FLUX/Kung.Fu.Panda.4.2024.1080p.AMZN.WEB-DL.DDP5.1.Atmos.H.264-FLUX.srt
[2024-04-10 01:59:10] Processing file: /mnt/storage/data2/Movies/Kung Fu Panda 4 (2024)/Kung Fu Panda 4 (2024) [imdbid-tt21692408] - [AMZN][WEBDL-1080p][EAC3 Atmos 5.1][h264]-FLUX.mkv. Target file name: Kung.Fu.Panda.4.2024.1080p.AMZN.WEB-DL.DDP5.1.Atmos.H.264-FLUX.mkv
[2024-04-10 01:59:10] [Dry Run] Would create symbolic link for /mnt/storage/data2/Movies/Kung Fu Panda 4 (2024)/Kung Fu Panda 4 (2024) [imdbid-tt21692408] - [AMZN][WEBDL-1080p][EAC3 Atmos 5.1][h264]-FLUX.mkv at /home/jones/test/Kung.Fu.Panda.4.2024.1080p.AMZN.WEB-DL.DDP5.1.Atmos.H.264-FLUX/Kung.Fu.Panda.4.2024.1080p.AMZN.WEB-DL.DDP5.1.Atmos.H.264-FLUX.mkv
[2024-04-10 01:59:10] Skipping already processed movieId: 102 for Kung.Fu.Panda.4.2024.1080p.WEB.h264-ETHEL-xsp
```

## Usage:

`./create-file-links-from-radarr-api.sh [-c config_file] [-u radarr_url] [-k api_key] [-d destination_folder] [-s use_symbolic_links] [-r dry_run] [-m path_mapping]`

or

`./create-file-links-from-radarr-api.sh`

and use the provided config file

## Reverse docker path mappings:
For every path mapping provide this as argument or in the config file:

`path_mapping=/data,/mnt/storage` (left side will be replaced by the right side)
