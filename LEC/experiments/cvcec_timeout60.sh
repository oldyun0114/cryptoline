#!/usr/bin/env bash
set -u
timeout 60s ./_build/default/cv_cec.exe "$@"
