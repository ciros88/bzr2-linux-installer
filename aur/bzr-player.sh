#!/bin/bash
#
# NAME
#     bzr-player.sh - BZR Player 2.x (BZR2) linux runner
#
# SYNOPSIS
#     ./bzr-player.sh [target(s)]
#
# EXAMPLES
#     ./bzr-player.sh
#         run BZR2
#
#     ./bzr-player.sh file1 file2 dir1 dir2
#         run BZR2 with selected files and/or directories as arguments
#
# AUTHOR
#     Ciro Scognamiglio

set -e
bzr2="bzr-player"
export WINEPREFIX="$HOME/.$bzr2"

if [ ! -d "$HOME/.$bzr2" ]; then
  mkdir -p "$HOME/.$bzr2"
  #TODO
fi

WINEDEBUG=-all WINEARCH="win32" wine "/usr/share/$bzr2/BZRPlayer.exe" "$@" &
