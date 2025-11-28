#!/bin/bash

# A script to rename SRT/ASS files from a source directory (subdir) 
# to match MKV files in a destination directory (dstdir) 
# and add a language ISO code to the extension.
#
# Usage: ./subadd.sh [-c|--copy] [-r] <subdir_of_srtList> <dstdir_of_mkv> <langiso>

# --- Default Options ---
COPY_MODE=false
RENAME_ORIGINAL=false

# --- Parse Options ---
while [[ "$1" == -* ]]; do
    case "$1" in
        -c|--copy)
            COPY_MODE=true
            shift
            ;;
        -r)
            RENAME_ORIGINAL=true
            shift
            ;;
        -cr|-rc)
            COPY_MODE=true
            RENAME_ORIGINAL=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-c|--copy] [-r] <subdir_of_srtList> <dstdir_of_mkv> <langiso>"
            echo ""
            echo "Options:"
            echo "  -c, --copy    Copy subtitles to destination instead of moving"
            echo "  -r            Rename original subtitle in source folder to match destination naming"
            echo "  -h, --help    Show this help message"
            exit 0
            ;;
        *)
            echo "❌ Error: Unknown option '$1'"
            echo "Usage: $0 [-c|--copy] [-r] <subdir_of_srtList> <dstdir_of_mkv> <langiso>"
            exit 1
            ;;
    esac
done

# --- Input Validation ---
if [ "$#" -ne 3 ]; then
    echo "❌ Error: Illegal number of parameters."
    echo "Usage: $0 [-c|--copy] [-r] <subdir_of_srtList> <dstdir_of_mkv> <langiso>"
    exit 1
fi

SUBDIR="$1"   # Directory containing the original subtitle files
DSTDIR="$2"   # Directory containing the MKV files (naming template)
LANGISO="$3"  # Language code (e.g., 'jpn', 'eng')

echo "--- Subtitle Rename Utility ---"
echo "Subtitle Source: $SUBDIR"
echo "Video Destination: $DSTDIR"
echo "Language ISO Code: $LANGISO"
echo "Copy Mode: $COPY_MODE"
echo "Rename Original: $RENAME_ORIGINAL"
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
        
        # 3. Construct the four specific patterns for the original subtitle file
        
        # Pattern 1 (Loose Space/End of title): Matches titles like '... 01.ass' or '... 01 .ass'
        PATTERN_1="$SUBDIR/* ${EPISODE_NUMBER}*."@(srt|ass)
        
        # Pattern 2 (Bracketed): Matches titles like '...[02][Source].ass'
        PATTERN_2="$SUBDIR/*[[]${EPISODE_NUMBER}[]]*."@(srt|ass)

        # Pattern 3 (Curly Braces): Matches titles like '...{03}[Source].ass'
        PATTERN_3="$SUBDIR/*{${EPISODE_NUMBER}}*."@(srt|ass)

        # Pattern 4 (Episode format): Matches titles like '...S01E02...' or '...E02...'
        PATTERN_4="$SUBDIR/*E${EPISODE_NUMBER}*."@(srt|ass)
        
        # 5. Find the matching subtitle file path in the source directory
        # Use compgen -G with double-quotes to prevent errors.
        
        # Attempt to find the pattern 1 match
        SRT_FILE_MATCH_1=$(compgen -G "$PATTERN_1" | head -n 1)
        
        # Attempt to find the pattern 2 match
        SRT_FILE_MATCH_2=$(compgen -G "$PATTERN_2" | head -n 1)

        # Attempt to find the pattern 3 match
        SRT_FILE_MATCH_3=$(compgen -G "$PATTERN_3" | head -n 1)

        # Attempt to find the pattern 4 match
        SRT_FILE_MATCH_4=$(compgen -G "$PATTERN_4" | head -n 1)

        # Choose the first one that actually found a file
        srt_file_path=""
        if [[ -n "$SRT_FILE_MATCH_1" ]]; then
            srt_file_path="$SRT_FILE_MATCH_1"
        elif [[ -n "$SRT_FILE_MATCH_2" ]]; then
            srt_file_path="$SRT_FILE_MATCH_2"
        elif [[ -n "$SRT_FILE_MATCH_3" ]]; then
            srt_file_path="$SRT_FILE_MATCH_3"
        elif [[ -n "$SRT_FILE_MATCH_4" ]]; then
            srt_file_path="$SRT_FILE_MATCH_4"
        fi

        if [[ -n "$srt_file_path" ]]; then
            # 5. Determine the original extension of the found file
            ORIG_EXT="${srt_file_path##*.}"
            
            # 6. Determine the new file extension part and final name
            NEW_EXT=".${LANGISO}.${ORIG_EXT}"
            new_base_name="${mkv_file%.mkv}"
            new_name="${new_base_name}${NEW_EXT}"

            # 7. Perform the file operation based on flags
            if [[ "$COPY_MODE" == true ]] || [[ "$RENAME_ORIGINAL" == true ]]; then
                # Copy to destination (needed for both -c and -r modes)
                cp "$srt_file_path" "$DSTDIR/$new_name"
                
                if [[ "$RENAME_ORIGINAL" == true ]]; then
                    # Rename the original in place
                    mv "$srt_file_path" "$SUBDIR/$new_name"
                    echo "✅ Copied and Renamed Original Episode $EPISODE_NUMBER:"
                    echo "   Source: $SUBDIR/$new_name"
                    echo "   Destination: $DSTDIR/$new_name"
                else
                    echo "✅ Copied Episode $EPISODE_NUMBER: $new_name"
                fi
            else
                # Default behavior: move to destination
                mv "$srt_file_path" "$DSTDIR/$new_name"
                echo "✅ Renamed and Moved Episode $EPISODE_NUMBER: $new_name"
            fi
        else
            echo "⚠️ Warning: Could not find matching SRT/ASS file for episode $EPISODE_NUMBER in '$SUBDIR'. Tried patterns: * ${EPISODE_NUMBER}*, *[${EPISODE_NUMBER}]*, *{${EPISODE_NUMBER}}*, and *E${EPISODE_NUMBER}*."
        fi
    else
        echo "⚠️ Warning: Skipping '$mkv_file'. Could not extract episode number (looking for S01E##)."
    fi
done

# Disable extended globbing and nullglob
shopt -u extglob
shopt -u nullglob

echo "--- Done. ---"