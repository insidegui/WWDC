#!/bin/bash

echo ""

# Check if TeamID.xcconfig exists and extract team ID
TEAM_ID_CONFIG=$(dirname "${BASH_SOURCE[0]}")/../WWDC/Config/TeamID.xcconfig

if [ -f "$TEAM_ID_CONFIG" ]; then
    # Extract team ID from the config file
    TEAM_ID=$(grep "DEVELOPMENT_TEAM=" "$TEAM_ID_CONFIG" | cut -d'=' -f2)
    DEBUG_FOLDER_PATH="$HOME/Library/Application Support/io.wwdc.app${TEAM_ID}.debug"
else
    # Fallback to original path without team ID
    DEBUG_FOLDER_PATH="$HOME/Library/Application Support/io.wwdc.app.debug"
fi

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
