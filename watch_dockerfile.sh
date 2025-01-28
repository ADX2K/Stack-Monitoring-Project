#!/bin/bash

# Ensure Hadolint is installed (you can use Docker or a local binary)
command -v hadolint >/dev/null 2>&1 || {
    echo "Hadolint not found! Install it or use the Docker version: docker run --rm -i hadolint/hadolint"
    exit 1
}

# Verify that dockerfile exists and is a file
if [[ ! -f "./dockerfile" ]]; then
    echo "Error: dockerfile not found in the current directory."
    exit 1
fi

# Monitor the dockerfile using entr
echo -e "\n\n\n"
echo "Monitoring dockerfile for changes..."
echo "./dockerfile" | entr -d -r bash -c 'echo -e "\n\n\nFile changed! Running Hadolint..."; hadolint ./dockerfile'
echo -e "\n\n\n"
