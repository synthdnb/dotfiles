#!/bin/bash
# macOS defaults that are overridden from factory values on this machine.
# ponytail: curated scan of commonly-tweaked keys, not an exhaustive diff —
# macOS exposes no factory baseline, so only known-default comparisons are captured.

# Keyboard
defaults write -g ApplePressAndHoldEnabled -bool false  # repeat key instead of accent popup
defaults write -g KeyRepeat -int 2                       # fast repeat (default 6)
defaults write -g InitialKeyRepeat -int 12               # short repeat delay (default 15)

# Caps Lock -> Control. Per-host, keyed by keyboard vendor-product ID; "0-0-0"
# is the generic entry that covers the built-in keyboard. Src 0x700000039 = Caps
# Lock, Dst 0x7000000e4 = Control. Takes effect on next login.
defaults -currentHost write -g com.apple.keyboard.modifiermapping.0-0-0 -array \
  '{ HIDKeyboardModifierMappingSrc = 30064771129; HIDKeyboardModifierMappingDst = 30064771300; }'

# Text input — disable the "smart" substitutions (default on)
defaults write -g NSAutomaticCapitalizationEnabled -bool false
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write -g NSAutomaticDashSubstitutionEnabled -bool false
defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false

# Finder
defaults write -g AppleShowAllExtensions -bool true      # always show file extensions
defaults write com.apple.finder ShowStatusBar -bool true

# Screenshots
defaults write com.apple.screencapture location "$HOME/Downloads"

# Apply what we can without a re-login (key-repeat/global keys still need logout).
killall Finder 2>/dev/null || true
