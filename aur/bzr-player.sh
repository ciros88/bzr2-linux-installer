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
bzr2_path="/usr/share/$bzr2"
bzr2_exe="BZRPlayer.exe"

export WINEDEBUG=-all
export WINEPREFIX="$HOME/.$bzr2/wine"

if [ "$(uname -m)" == "x86_64" ]; then
  export WINEARCH="win64"
else
  export WINEARCH="win32"
fi

if [ ! -d "$HOME/.$bzr2" ]; then
  mkdir -p "$WINEPREFIX"

  #winetricks nocrashdialog
  wine reg add "HKEY_CURRENT_USER\Software\Wine\WineDbg" /v ShowCrashDialog /t REG_DWORD /d 0 /f

  #winetricks autostart_winedbg=disabled (never worked in winetricks)
  wine reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\AeDebug" /v Debugger /t REG_SZ /d "-" /f

  #ln -s "$bzr2_path/$bzr2_exe" "$HOME/.$bzr2/$bzr2"
  #mkdir -p "$HOME/.$bzr2/plugin"
  #ln -s -T "$bzr2_path/plugin/config" "$HOME/.$bzr2/plugin/config"
  #ln -s "$bzr2_path/settings.ini" "$HOME/.$bzr2"
  #TODO link songlengths
fi

#wine "$HOME/.$bzr2/$bzr2" "$@" &
wine "$bzr2_path/$bzr2_exe" "$@" &
