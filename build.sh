#!/usr/bin/env bash
set -euo pipefail

# Load .env — skip blank lines and comments
export $(grep -v '^\s*#' .env | grep -v '^\s*$' | xargs)

echo "Building Frigo web..."
flutter build web --release \
  --dart-define=GROQ_API_KEY="$GROQ_API_KEY" \
  --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY"

echo "Deploying to Firebase Hosting..."
firebase deploy --only hosting
