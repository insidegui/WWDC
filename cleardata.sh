#!/bin/bash

echo ""
echo "WARNING: this will remove all local data for both release and debug configurations, and reset all preferences"
echo ""
echo "Press any key to continue, Ctrl+C to cancel..."
read

rm -Rfv ~/Library/Application\ Support/io.wwdc.app*
defaults delete io.wwdc.app 2>/dev/null
