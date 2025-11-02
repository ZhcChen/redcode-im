#!/bin/bash
# Desktop module development startup script with fixed temp directory

# Set custom temp directory for Rust compiler
export TMPDIR="${HOME}/.cargo-tmp"
export TMP="${HOME}/.cargo-tmp"
export TEMP="${HOME}/.cargo-tmp"

# Ensure the directory exists and has correct permissions
mkdir -p "${TMPDIR}"
chmod 700 "${TMPDIR}"

# Change to desktop directory
cd "$(dirname "$0")"

# Run tauri dev
exec pnpm run tauri dev

