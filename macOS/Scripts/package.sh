#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Scripts/build_extensions.py
python3 Scripts/make_project.py
python3 Scripts/validate.py
python3 Scripts/package.py
