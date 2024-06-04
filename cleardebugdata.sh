#!/bin/bash

echo ""

DEBUG_FOLDER_PATH="$HOME/Library/Application Support/io.wwdc.app.debug"

if [ ! -d "$DEBUG_FOLDER_PATH" ]; then
    echo "Debug data folder doesn't exist at $DEBUG_FOLDER_PATH"
    echo "Nothing to be done, all good!"
    echo ""
    exit 0
fi

echo "Removing DEBUG data folder at $DEBUG_FOLDER_PATH"

rm -R "$DEBUG_FOLDER_PATH" || { echo "Failed to remove :("; exit 1; }

echo "All good!"
echo ""