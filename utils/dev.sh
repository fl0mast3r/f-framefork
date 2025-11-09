#!/bin/sh

set -e

rojo serve dev.project.json \
    & rojo sourcemap default.project.json -o sourcemap.json --watch \
    & darklua process --config .darklua.json --watch src/ dist/src \
    & darklua process --config .darklua.json --watch Net/ dist/net