#!/bin/bash
# Run from inside the unzipped folder: moves the project to ~/workspace/SalatTasbih and launches it
set -e
mkdir -p ~/workspace && rm -rf ~/workspace/SalatTasbih
cp -R "$(cd "$(dirname "$0")" && pwd)" ~/workspace/SalatTasbih
cd ~/workspace/SalatTasbih && chmod +x run.sh && ./run.sh
