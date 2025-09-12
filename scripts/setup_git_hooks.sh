#!/bin/bash
# sets up pre commit hooks

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")

[ -e $SCRIPT_DIR/../.git/hooks/pre-commit ] && rm $SCRIPT_DIR/../.git/hooks/pre-commit
mkdir -p $SCRIPT_DIR/../.git/hooks

touch $SCRIPT_DIR/../.git/hooks/pre-commit

chmod +x $SCRIPT_DIR/../.git/hooks/pre-commit

cat $SCRIPT_DIR/git_hooks/xcodeproj_developer_team_check >> $SCRIPT_DIR/../.git/hooks/pre-commit
