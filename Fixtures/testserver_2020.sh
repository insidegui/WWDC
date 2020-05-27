#!/bin/bash

if ! type "npm" > /dev/null; then
	echo "NPM is not installed, installing...\n"
	curl -L https://www.npmjs.com/install.sh | sh
fi

if ! type "http-server" > /dev/null; then
	echo "http-server module is not installed, installing...\n"
	npm install http-server -g
fi

http-server -p 9042 ./json_2020