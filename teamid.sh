#!/bin/bash

TEAM_ID_FILE=WWDC/Config/TeamID.xcconfig

function print_team_ids() {
  echo ""
  echo "FYI, here are the team IDs found in your Xcode preferences:"
  echo ""
  
  XCODEPREFS="$HOME/Library/Preferences/com.apple.dt.Xcode.plist"

  # Get all team infos from IDEProvisioningTeamByIdentifier, for Xcode versions after 16.0
  local all_keys=($(/usr/libexec/PlistBuddy -c "Print :IDEProvisioningTeamByIdentifier" "$XCODEPREFS" | grep ' = Array' | awk '{print $1}'))
  local result=""
  for key in "${all_keys[@]}"; do
      local teamID=$(/usr/libexec/PlistBuddy -c "Print :IDEProvisioningTeamByIdentifier:$key:0:teamID" "$XCODEPREFS" 2>/dev/null)
      local teamName=$(/usr/libexec/PlistBuddy -c "Print :IDEProvisioningTeamByIdentifier:$key:0:teamName" "$XCODEPREFS" 2>/dev/null)
      if [ -n "$teamID" ]; then
          result+="$teamID - $teamName\n"
      fi
  done
  if [ -n "$result" ]; then
      printf "%b" "$result"
      return 0
  fi
  
  # Get all team infos from IDEProvisioningTeams, for Xcode versions prior to 16.0
  # More info: https://support.apple.com/en-us/121239#:~:text=CVE%2D2024%2D40862:%20Guilherme%20Rambo%20of%20Best%20Buddy%20Apps%20(rambo.codes)
  TEAM_KEYS=(`/usr/libexec/PlistBuddy -c "Print :IDEProvisioningTeams" "$XCODEPREFS" | perl -lne 'print $1 if /^    (\S*) =/'`)
  
  for KEY in $TEAM_KEYS 
  do
      i=0
      while true ; do
          NAME=$(/usr/libexec/PlistBuddy -c "Print :IDEProvisioningTeams:$KEY:$i:teamName" "$XCODEPREFS" 2>/dev/null)
          TEAMID=$(/usr/libexec/PlistBuddy -c "Print :IDEProvisioningTeams:$KEY:$i:teamID" "$XCODEPREFS" 2>/dev/null)
          
          if [ $? -ne 0 ]; then
              break
          fi
          
          echo "$TEAMID - $NAME"
          
          i=$(($i + 1))
      done
  done
}

if [ -z "$1" ]; then
  print_team_ids
  echo ""
  echo "> What is your Apple Developer Team ID? (looks like 1A23BDCD)"
  read TEAM_ID
else
  TEAM_ID=$1
fi

if [ -z "$TEAM_ID" ]; then
  echo "You must enter a team id"
  print_team_ids
  exit 1
fi

echo "Setting team ID to $TEAM_ID"

echo "// This file was automatically generated, do not edit directly." > $TEAM_ID_FILE
echo "" >> $TEAM_ID_FILE
echo "DEVELOPMENT_TEAM=$TEAM_ID" >> $TEAM_ID_FILE

echo ""
echo "Successfully generated configuration at $TEAM_ID_FILE, you may now build the app using the \"WWDC\" target"
echo "You may need to close and re-open the project in Xcode if it's already open"
echo ""
