#!/bin/bash
if [[ ${CI} ]]; then
    echo -en '\033[33;1mBootstrap\033[0m travis_fold:start:bootstrap\\r'
fi

lessThanOrEqual() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

lessThan() {
    [ "$1" = "$2" ] && return 1 || lessThanOrEqual $1 $2
}

SWIFTLINT_MIN="0.27"
SWIFTLINT_INSTALLED=$([ `command -v swiftlint` ] && echo true || echo false )
BREW_INSTALLED=$([ `command -v brew` ] && echo true || echo false )

SWIFTLINT_UPDATED=false
if $SWIFTLINT_INSTALLED; then
    if ! lessThan `swiftlint version` $SWIFTLINT_MIN; then
        SWIFTLINT_UPDATED=true
    fi
fi

if ! $SWIFTLINT_INSTALLED || ! $SWIFTLINT_UPDATED; then
    echo "WWDC for macOS uses SwiftLint ${SWIFTLINT_MIN} or above to ensure a consistent codestyle. SwiftLint is either not installed or does not meet this minimum version."

    if $BREW_INSTALLED; then
        read -p "Use Homebrew to globally install the latest version of SwiftLint? [Y/n] " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if $SWIFTLINT_INSTALLED; then
                brew upgrade swiftlint
            else
                brew install swiftlint
            fi
        else
            echo 'Please install SwiftLint & try again to continue.'
            exit 1
        fi
    else
        echo 'Please install SwiftLint & try again to continue.'
        exit 1
    fi
fi

if [[ ${CI} ]]; then
    echo "Bootstrapping in CI mode"
    set -o pipefail && env "NSUnbufferedIO=YES" carthage bootstrap --verbose --platform macOS | xcpretty -f `xcpretty-travis-formatter`
    exit_code=$?
    echo 'travis_fold:end:bootstrap\n'
    exit $exit_code
else
    carthage bootstrap --platform macOS
fi
