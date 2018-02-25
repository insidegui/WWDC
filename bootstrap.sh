#!/bin/bash

SWIFTLINT_MIN="0.24"

lessThanOrEqual() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

lessThan() {
    [ "$1" = "$2" ] && return 1 || lessThanOrEqual $1 $2
}

brewInstalled() {
    command -v brew >/dev/null && return 0 || return 1
}

if command -v swiftlint >/dev/null; then
    if lessThan `swiftlint version` $SWIFTLINT_MIN; then
        if brewInstalled; then
            read -p "WWDC for macOS uses SwiftLint ${SWIFTLINT_MIN} or above to ensure a consistent codestyle. Upgrade SwiftLint version? [Y/n] " -n 1 -r
            echo

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                brew upgrade swiftlint
            else 
                echo "Please be aware that the installed version of SwiftLint may behave unexpectedly."
            fi
        else
            echo "WWDC for macOS uses SwiftLint ${SWIFTLINT_MIN} or above to ensure a consistent codestyle. Please be aware that the installed version of SwiftLint may behave unexpectedly."
        fi
    fi  
elif brewInstalled; then
    brew install swiftlint
else
    echo "WWDC for macOS uses SwiftLint to ensure a consistent codestyle. Please install SwiftLint or Homebrew & try again to continue."
fi

carthage bootstrap --platform macOS
