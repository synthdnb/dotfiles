#!/bin/bash
# One-command bootstrap for a fresh Mac — no git or Homebrew needed first.
# Run:  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/synthdnb/dotfiles/main/bootstrap.sh)"
# (Requires the repo to be public so the raw URL and clone work without auth.)
set -e

# Homebrew installs the Xcode Command Line Tools (which provide git) and is a
# prerequisite anyway. Interactive on purpose — it needs the sudo password once.
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"   # ponytail: Apple Silicon path; add /usr/local for Intel if ever needed

REPO="$HOME/ws/dotfiles"
if [ -d "$REPO/.git" ]; then
  git -C "$REPO" pull --ff-only
else
  git clone https://github.com/synthdnb/dotfiles.git "$REPO"
fi
cd "$REPO"
exec ./install.sh
