#!/bin/bash

# A script to rename SRT/ASS files from a source directory (subdir) 
# to match MKV files in a destination directory (dstdir) 
# and add a language ISO code to the extension.
#
# Usage: ./subadd.sh <subdir_of_srtList> <dstdir_of_mkv> <langiso>

# --- Input Validation ---
if [ "$#" -ne 3 ]; then
    echo "❌ Error: Illegal number of parameters."
    echo "Usage: $0 <subdir_of_srtList> <dstdir_of_mkv> <langiso>"
    exit 1
fi

SUBDIR="$1"   # Directory containing the original subtitle files
DSTDIR="$2"   # Directory containing the MKV files (naming template)
LANGISO="$3"  # Language code (e.g., 'jpn', 'eng')

echo "--- Subtitle Rename Utility ---"
echo "Subtitle Source: $SUBDIR"
echo "Video Destination: $DSTDIR"
echo "Language ISO Code: $LANGISO"
echo "-------------------------------"

# Ensure directories exist
if [ ! -d "$SUBDIR" ]; then
    echo "❌ Error: Subtitle source directory '$SUBDIR' not found."
    exit 1
fi
if [ ! -d "$DSTDIR" ]; then
    echo "❌ Error: Video destination directory '$DSTDIR' not found."
    exit 1
fi

# Enable Bash Extended Globbing to use the @(...) pattern
shopt -s extglob
shopt -s nullglob

# --- Main Logic ---

# 1. Loop through all MKV files in the destination directory (the template files)
for mkv_path in "$DSTDIR"/*.mkv; do
    mkv_file=$(basename "$mkv_path")
    
    # 2. Extract the episode number (e.g., '01', '02') from the MKV filename
    # Looks for '- S01E## -' where ## is two digits
    if [[ "$mkv_file" =~ -[[:space:]]S01E([0-9]{2})[[:space:]]- ]]; then
        EPISODE_NUMBER="${BASH_REMATCH[1]}"
        
        # 3. Construct the three specific patterns for the original subtitle file
        
        # Pattern 1 (Loose Space/End of title): Matches titles like '... 01.ass' or '... 01 .ass'
        PATTERN_1="$SUBDIR/* ${EPISODE_NUMBER}*."@(srt|ass)
        
        # Pattern 2 (Bracketed): Matches titles like '...[02][Source].ass'
        PATTERN_2="$SUBDIR/*[${EPISODE_NUMBER}]*."@(srt|ass)

        # Pattern 3 (Curly Braces): Matches titles like '...{03}[Source].ass'
        PATTERN_3="$SUBDIR/*{${EPISODE_NUMBER}}*."@(srt|ass)
        
        # 4. Find the matching subtitle file path in the source directory
        # Use compgen -G with double-quotes to prevent errors.
        
        # Attempt to find the pattern 1 match
        SRT_FILE_MATCH_1=$(compgen -G "$PATTERN_1" | head -n 1)
        
        # Attempt to find the pattern 2 match
        SRT_FILE_MATCH_2=$(compgen -G "$PATTERN_2" | head -n 1)

        # Attempt to find the pattern 3 match
        SRT_FILE_MATCH_3=$(compgen -G "$PATTERN_3" | head -n 1)

        # Choose the first one that actually found a file
        srt_file_path=""
        if [[ -n "$SRT_FILE_MATCH_1" ]]; then
            srt_file_path="$SRT_FILE_MATCH_1"
        elif [[ -n "$SRT_FILE_MATCH_2" ]]; then
            srt_file_path="$SRT_FILE_MATCH_2"
        elif [[ -n "$SRT_FILE_MATCH_3" ]]; then
            srt_file_path="$SRT_FILE_MATCH_3"
        fi

        if [[ -n "$srt_file_path" ]]; then
            # 5. Determine the original extension of the found file
            ORIG_EXT="${srt_file_path##*.}"
            
            # 6. Determine the new file extension part and final name
            NEW_EXT=".${LANGISO}.${ORIG_EXT}"
            new_base_name="${mkv_file%.mkv}"
            new_name="${new_base_name}${NEW_EXT}"

            # 7. Perform the rename and move operation
            mv "$srt_file_path" "$DSTDIR/$new_name"
            
            echo "✅ Renamed and Moved Episode $EPISODE_NUMBER: $new_name"
        else
            echo "⚠️ Warning: Could not find matching SRT/ASS file for episode $EPISODE_NUMBER in '$SUBDIR'. Tried patterns: * ${EPISODE_NUMBER}*, *[${EPISODE_NUMBER}]*, and *{${EPISODE_NUMBER}}*."
        fi
    else
        echo "⚠️ Warning: Skipping '$mkv_file'. Could not extract episode number (looking for S01E##)."
    fi
done

# Disable extended globbing and nullglob
shopt -u extglob
shopt -u nullglob

echo "--- Done. ---"