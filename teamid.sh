#!/bin/bash

TEAM_ID_FILE=WWDC/TeamID.xcconfig

echo "What is your Apple Developer Team ID? (looks like 1A23BDCD)"
read TEAM_ID

if [ -z "$TEAM_ID" ]; then
  echo "You must enter a team id"
  exit 1
fi

echo "// This file was automatically generated, do not edit directly." > $TEAM_ID_FILE
echo "" >> $TEAM_ID_FILE
echo "DEVELOPMENT_TEAM=$TEAM_ID" >> $TEAM_ID_FILE

echo ""
echo "Successfully generated configuration at $TEAM_ID_FILE, you may now build the app using the \"WWDC\" target"
echo "You may need to close and re-open the project in Xcode if it's already open"
echo ""