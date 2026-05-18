#!/usr/bin/env bash
set -u
timeout 300s ./_build/default/cv_cec.exe "$@"
