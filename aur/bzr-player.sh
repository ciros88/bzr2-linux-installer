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
bzr2_path_sys="/usr/share/$bzr2"
bzr2_path_home="$HOME/.$bzr2"

export WINEDEBUG=-all #TODO
export WINEPREFIX="$bzr2_path_home/wine"

if [ "$(uname -m)" == "x86_64" ]; then
  export WINEARCH="win64"
else
  export WINEARCH="win32"
fi

if [ ! -d "$bzr2_path_home" ]; then
  mkdir -p "$WINEPREFIX"

  # winetricks nocrashdialog
  wine reg add "HKEY_CURRENT_USER\Software\Wine\WineDbg" /v ShowCrashDialog /t REG_DWORD /d 0 /f

  # winetricks autostart_winedbg=disabled (never worked in winetricks)
  wine reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\AeDebug" /v Debugger /t REG_SZ /d "-" /f

  # --- app data setup ---
  ln -s "$bzr2_path_sys/BZRPlayer.exe" "$bzr2_path_home/$bzr2"
  ln -s "$bzr2_path_sys/BZRPlayerTest.exe" "$bzr2_path_home/$bzr2-test"

  readarray -d '' root_dlls < <(find "$bzr2_path_sys" -maxdepth 1 -type f -iname '*.dll' -print0)

  for root_dll in "${root_dlls[@]}"; do
    ln -s "$root_dll" "$bzr2_path_home"
  done

  ln -s "$bzr2_path_sys/gm.dls" "$bzr2_path_home"
  ln -s "$bzr2_path_sys/imageformats" "$bzr2_path_home"
  ln -s "$bzr2_path_sys/layouts" "$bzr2_path_home"
  ln -s "$bzr2_path_sys/platforms" "$bzr2_path_home"
  mkdir -p "$bzr2_path_home/plugin"
  ln -s "$bzr2_path_sys/plugin/orgsamples" "$bzr2_path_home/plugin"
  ln -s "$bzr2_path_sys/plugin/SC68" "$bzr2_path_home/plugin"
  ln -s "$bzr2_path_sys/plugin/sid" "$bzr2_path_home/plugin"
  ln -s "$bzr2_path_sys/plugin/uade" "$bzr2_path_home/plugin"

  readarray -d '' plugin_dlls < <(find "$bzr2_path_sys/plugin" -maxdepth 1 -type f -iname '*.dll' -print0)

  for plugin_dll in "${plugin_dlls[@]}"; do
    ln -s "$plugin_dll" "$bzr2_path_home/plugin"
  done

  ln -s "$bzr2_path_sys/resources" "$bzr2_path_home"
  # END --- app data setup ---

  # --- user data setup ---
  mkdir -p "$bzr2_path_home/playlists"
  mkdir -p "$bzr2_path_home/plugin/config"
  cp -a "$bzr2_path_sys/Songlengths.md5" "$bzr2_path_home"
  cp -a "$bzr2_path_sys/Songlengths.txt" "$bzr2_path_home"
  # END --- user data setup ---
fi

export WINEDEBUG=warn #TODO
wine "$bzr2_path_home/$bzr2" "$@" &
