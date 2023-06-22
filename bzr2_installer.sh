#!/bin/bash
#
# NAME
#     bzr2_installer.sh - experimental distribution-agnostic BZR Player 2 linux installer
#
# SYNOPSIS
#     ./bzr2_installer.sh
#
# DESCRIPTION
#     install and configure BZR Player 2 (bzr2) using wine
#
#     handle multiple bzr2 versions (useful for testing purposes) in separated
#     wine prefixes as ~/.bzr2-<player version>-<wine arch>
#
#     provides a symbolic link to ~/.bzr2 as a stable entry point
#     for accessing bzr2, in which the bzr2.sh player runner script is generated
#
#     also generates an XDG desktop entry for launching the player,
#     eventually associated to supported MIME types
#
# NOTES
#     bzr2 versions older than 2.0.19.Alpha have not been tested
#
# AUTHOR
#     Ciro Scognamiglio

set -e

main() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Root privileges are required"
    exit 1
  fi

  USER=${SUDO_USER}
  HOME=$(eval echo ~"$SUDO_USER")

  bzr2_version_default="2.0.53.Alpha"
  winearch_default="win64"
  force_reinstall_default="n"
  bzr2_zip_dir_default="."
  dpi_default="auto"
  mime_types_association_default="y"
  mime_types=(
    application/ogg audio/flac audio/midi audio/mp2 audio/mpeg audio/prs.sid audio/x-ahx audio/x-bp audio/x-cust
    audio/x-dmf audio/x-dw audio/x-fc audio/x-flac+ogg audio/x-fp audio/x-hip audio/x-it audio/x-lds audio/x-m2
    audio/x-mdx audio/x-mo3 audio/x-mod audio/x-mpegurl audio/x-mptm audio/x-okt audio/x-prun audio/x-psm audio/x-pt3
    audio/x-s3m audio/x-sc2 audio/x-sc68 audio/x-scl audio/x-sid2 audio/x-sndh audio/x-spc audio/x-spl audio/x-stk
    audio/x-stm audio/x-sun audio/x-sunvox audio/x-symmod audio/x-tfmx audio/x-umx audio/x-v2m audio/x-vgm
    audio/x-vorbis+ogg audio/x-wav audio/x-xm
  )

  bold=$'\e[1m'
  bold_reset=$'\e[0m'

  invalid_value_inserted_message="please insert a valid value"

  bzr2_wineprefix_dir_unversioned="$HOME/.bzr2"
  bzr2_exe_filename="BZRPlayer.exe"
  bzr2_launcher_filename="bzr2.sh"
  bzr2_desktop_filename="bzr2.desktop"
  bzr2_icon_unversioned="$bzr2_wineprefix_dir_unversioned"/bzr2.png

  check_requirements
  get_bzr2_version

  bzr2_version="${bzr2_version,,}"

  get_winearch

  bzr2_exe="$bzr2_dir/$bzr2_exe_filename"
  bzr2_desktop="$bzr2_wineprefix_dir"/"$bzr2_desktop_filename"
  bzr2_icon="$bzr2_wineprefix_dir"/bzr2.png

  if [ -f "$bzr2_exe" ]; then
    already_installed=1

    echo -e "\nbzr2 ${bold}$bzr2_version${bold_reset} ${bold}$winearch${bold_reset} installation has been detected in \
${bold}$bzr2_wineprefix_dir${bold_reset}"
    get_force_reinstall
  else
    already_installed=0
    force_reinstall="$force_reinstall_default"
  fi

  if [ "$already_installed" -eq 0 ] || [ "$force_reinstall" = y ]; then
    get_bzr2_zip_dir
  fi

  get_dpi
  get_mime_types_association

  echo

  if [ "$already_installed" -eq 0 ] || [ "$force_reinstall" = y ]; then
    if [ "$force_reinstall" = y ]; then
      rm -rf "$bzr2_wineprefix_dir"
    fi

    setup_bzr2
  fi

  sudo -u "$USER" ln -sfn "$bzr2_wineprefix_dir" "$bzr2_wineprefix_dir_unversioned"

  echo "symbolic link ${bold}$bzr2_wineprefix_dir_unversioned${bold_reset} -> \
${bold}$bzr2_wineprefix_dir${bold_reset} has been created"

  setup_dpi
  setup_launcher_script

  sudo -u "$USER" ln -sfn "$bzr2_dir/resources/icon.png" "$bzr2_icon"

  setup_desktop_entry
  setup_launcher_icon

  if [ "$mime_types_association" = y ]; then
    setup_mime_types
  fi

  echo -e "\nAll done, enjoy bzr2!"
}

check_requirements() {
  local requirements=(
    "eval" "realpath" "cat" "sed" "sudo" "unzip" "update-desktop-database" "update-mime-database" "wine" "winetricks"
    "xdg-desktop-menu" "xdg-icon-resource" "xdg-mime" "xrdb"
  )

  for requirement in "${requirements[@]}"; do
    if ! type "$requirement" &>/dev/null; then
      echo -e "\nplease install ${bold}$requirement${bold_reset}"
      exit 1
    fi
  done
}

show_message_and_read_input() {
  read -rp $'\n'"$1 (${bold}$2${bold_reset}): " input
  if [ -n "$input" ]; then
    echo "$input"
  else
    echo "$2"
  fi
}

get_bzr2_version() {
  local bzr2_version_pattern="^[2]{1}(\.){1}+[0-9]+(\.){1}+[0-9]+((\.){1}+(Alpha|alpha|Beta|beta))?$"

  while :; do
    local input
    input=$(show_message_and_read_input "select the bzr2 version to manage" ${bzr2_version_default})

    if ! [[ "$input" =~ $bzr2_version_pattern ]]; then
      echo -e "\n$invalid_value_inserted_message"
    else
      break
    fi
  done

  bzr2_version="$input"
}

get_winearch() {
  while :; do
    local input
    input=$(show_message_and_read_input "select the 32/64 bit ${bold}win32${bold_reset} or ${bold}win64${bold_reset} \
wine environment (multilib pkgs could be required)" ${winearch_default})

    case $input in
    "win32")
      bzr2_exe_win="c:\\Program Files\\BZR Player 2\\$bzr2_exe_filename"
      bzr2_wineprefix_dir="$bzr2_wineprefix_dir_unversioned-$bzr2_version-$input"
      bzr2_dir="$bzr2_wineprefix_dir/drive_c/Program Files/BZR Player 2"
      break
      ;;
    "win64")
      bzr2_exe_win="c:\\Program Files (x86)\\BZR Player 2\\$bzr2_exe_filename"
      bzr2_wineprefix_dir="$bzr2_wineprefix_dir_unversioned-$bzr2_version-$input"
      bzr2_dir="$bzr2_wineprefix_dir/drive_c/Program Files (x86)/BZR Player 2"
      break
      ;;
    *)
      echo -e "\n$invalid_value_inserted_message"
      ;;
    esac
  done

  winearch="$input"
}

get_force_reinstall() {
  while :; do
    local input
    input=$(show_message_and_read_input "force to reinstall bzr2 (fresh installation, does not keep settings) and the \
entire wine env, otherwise only the configuration will be performed" ${force_reinstall_default})

    case $input in
    y | n)
      break
      ;;
    *)
      echo -e "\n$invalid_value_inserted_message"
      ;;
    esac
  done

  force_reinstall="$input"
}

get_bzr2_zip_dir() {
  local bzr2_zip_filename

  #TODO handle alpha/beta/stable versions range (their first and last version number) in order to avoid overlapping
  bzr2_zip_filename=$(echo "$bzr2_version" | sed 's/.0.//;s/.Alpha//;s/.alpha//;s/.Beta//;s/.beta//;s/$/.zip/')

  while :; do
    local bzr2_zip_dir
    bzr2_zip_dir=$(show_message_and_read_input "specify the folder path with bzr2 release zip archive(s)" \
      "$(realpath -s "$bzr2_zip_dir_default")")

    bzr2_zip="$bzr2_zip_dir"/"$bzr2_zip_filename"

    if [ ! -f "$bzr2_zip" ]; then
      echo -e "\nfile ${bold}$bzr2_zip${bold_reset} not found... $invalid_value_inserted_message"
    else
      echo -e "\nrelease zip archive ${bold}$bzr2_zip${bold_reset} for version ${bold}$bzr2_version${bold_reset} \
has been found"
      break
    fi
  done
}

get_dpi() {
  local dpi_pattern="^[1-9][0-9]*$"

  while :; do
    local input
    input=$(show_message_and_read_input "select the DPI, ${bold}auto${bold_reset} for using the current from xorg \
screen 0 or ${bold}default${bold_reset} for using the default one" ${dpi_default})

    case $input in
    default | auto)
      break
      ;;
    *)
      if ! [[ "$input" =~ $dpi_pattern ]]; then
        echo -e "\n$invalid_value_inserted_message"
      else
        break
      fi
      ;;
    esac
  done

  dpi="$input"
}

get_mime_types_association() {
  while :; do
    local input
    input=$(show_message_and_read_input "associate bzr2 to all suppported MIME types (enter ${bold}list${bold_reset} \
for listing all)" ${mime_types_association_default})

    case $input in
    y | n)
      break
      ;;

    list)
      echo -e "\nbzr2 supports following MIME types:\n"
      for mime_type in "${mime_types[@]}"; do
        echo "$mime_type"
      done
      ;;
    *)
      echo -e "\n$invalid_value_inserted_message"
      ;;
    esac
  done

  mime_types_association="$input"
}

setup_bzr2() {
  sudo -u "$USER" mkdir -p "$bzr2_dir"
  sudo -u "$USER" unzip -oq "$bzr2_zip" -d "$bzr2_dir"
  sudo -u "$USER" WINEDEBUG=-all WINEPREFIX="$bzr2_wineprefix_dir" WINEARCH="$winearch" winetricks nocrashdialog \
    autostart_winedbg=disabled
}

setup_dpi() {
  local dpi_to_set

  case "$dpi" in
  "default") return ;;

  "auto")
    dpi_to_set=$(sudo -u "$USER" xrdb -query | grep dpi | sed 's/.*://;s/^[[:space:]]*//')
    if [ -z "$dpi_to_set" ]; then
      echo -e "\nunable to retrieve the screen ${bold}DPI${bold_reset}: the ${bold}default${bold_reset} will be used in wine"
      return
    fi
    ;;

  *)
    dpi_to_set=$dpi
    ;;
  esac

  echo -e "\nsetting wine ${bold}DPI${bold_reset} to ${bold}$dpi_to_set${bold_reset}\n"

  dpi_to_set='0x'$(printf '%x\n' "$dpi_to_set")

  sudo -u "$USER" WINEDEBUG=-all WINEPREFIX="$bzr2_wineprefix_dir" WINEARCH="$winearch" wine reg add \
    "HKEY_CURRENT_USER\Control Panel\Desktop" /v LogPixels /t REG_DWORD /d "$dpi_to_set" /f

  sudo -u "$USER" WINEDEBUG=-all WINEPREFIX="$bzr2_wineprefix_dir" WINEARCH="$winearch" wine reg add \
    "HKEY_CURRENT_USER\Software\Wine\Fonts" /v LogPixels /t REG_DWORD /d "$dpi_to_set" /f

  sudo -u "$USER" WINEDEBUG=-all WINEPREFIX="$bzr2_wineprefix_dir" WINEARCH="$winearch" wine reg add \
    "HKEY_CURRENT_CONFIG\Software\Fonts" /v LogPixels /t REG_DWORD /d "$dpi_to_set" /f
}

setup_launcher_script() {

  sudo -u "$USER" cat <<EOF >"$bzr2_wineprefix_dir/$bzr2_launcher_filename"
#!/bin/bash
#
# NAME
#     bzr2.sh - BZR Player 2 linux runner
#
# SYNOPSIS
#     ./bzr2.sh [track(s)]
#
# EXAMPLES
#     ./bzr2.sh
#         run bzr2
#
#     ./bzr2.sh track1 track2
#         run bzr2 with selected tracks as arguments
#
# AUTHOR
#     Ciro Scognamiglio

set -e
export WINEDEBUG=-all
WINEPREFIX="$bzr2_wineprefix_dir_unversioned" WINEARCH="$winearch" wine "$bzr2_exe_win"
EOF

  sudo -u "$USER" sed -i '$s/$/ "$@" \&/' "$bzr2_wineprefix_dir"/"$bzr2_launcher_filename"

  sudo -u "$USER" chmod +x "$bzr2_wineprefix_dir"/"$bzr2_launcher_filename"
}

setup_desktop_entry() {
  echo -e "\ninstalling bzr2 desktop menu entry"
  local desktop_entry_mime_types=""
  for mime_type in "${mime_types[@]}"; do
    desktop_entry_mime_types="$desktop_entry_mime_types$mime_type;"
  done

  sudo -u "$USER" cat <<EOF >"$bzr2_desktop"
[Desktop Entry]
Type=Application
Name=BZR Player 2
GenericName=Audio player
Comment=Audio player supporting a wide types of exotic file formats
Icon=$bzr2_icon_unversioned
Exec=$bzr2_wineprefix_dir_unversioned/$bzr2_launcher_filename %U
Categories=AudioVideo;Audio;Player;Music;
MimeType=inode/directory;$desktop_entry_mime_types
Terminal=false
NoDisplay=false
#Path=
#StartupNotify=
EOF

  sudo -u "$USER" xdg-desktop-menu install --novendor --mode user "$bzr2_desktop"
}

setup_launcher_icon() {
  echo
  echo "installing bzr2 icon for bzr2 launcher"

  for size in 16 22 24 32 48 64 128 256 512; do
    sudo -u "$USER" xdg-icon-resource install --noupdate --novendor --context apps --mode user --size ${size} "$bzr2_icon_unversioned"
  done

  sudo -u "$USER" xdg-icon-resource forceupdate

  if type gtk-update-icon-cache &>/dev/null; then
    echo
    sudo -u "$USER" gtk-update-icon-cache -t -f "$HOME/.local/share/icons/hicolor"
  fi
}

setup_mime_types() {
  local mime_dir_user=$HOME/.local/share/mime

  create_mime_type_xml_files

  echo -e "\nassociating bzr2 to all supported MIME types"

  sudo -u "$USER" xdg-mime default $bzr2_desktop_filename "${mime_types[@]}"

  #update-mime-database "$mime_dir_system"
  sudo -u "$USER" update-mime-database "$mime_dir_user"

  sudo -u "$USER" update-desktop-database "$HOME/.local/share/applications"
}

create_mime_type_xml_files() {
  local mime_packages_dir_user="$mime_dir_user/packages"
  local mime_type_xml_file

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-ahx">
    <comment>Abyss' Highest eXperience</comment>
    <generic-icon name="audio-x-generic"/>
    <icon name="audio-x-generic"/>
      <magic>
        <match type="big32" value="0x54485800" offset="0"/>
        <match type="big32" value="0x54485801" offset="0"/>
      </magic>
    <glob-deleteall/>
    <glob pattern="ahx.*"/>
    <glob pattern="*.ahx"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-ahx.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-bp">
    <comment>SoundMon</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="bp.*"/>
    <glob pattern="bp3.*"/>
    <glob pattern="*.bp"/>
    <glob pattern="*.bp3"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-bp.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-cust">
    <comment>Custom</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="cust.*"/>
    <glob pattern="*.cust"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-cust.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-dmf">
    <comment>X-Tracker</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="dmf.*"/>
    <glob pattern="*.dmf"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-dmf.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-dw">
    <comment>David Whittaker</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="dw.*"/>
    <glob pattern="*.dw"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-dw.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-fc">
    <comment>Future Composer</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="fc.*"/>
    <glob pattern="fc13.*"/>
    <glob pattern="fc14.*"/>
    <glob pattern="smc.*"/>
    <glob pattern="smod.*"/>
    <glob pattern="*.fc"/>
    <glob pattern="*.fc13"/>
    <glob pattern="*.fc14"/>
    <glob pattern="*.smc"/>
    <glob pattern="*.smod"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-fc.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-fp">
    <comment>Future Player</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="fp.*"/>
    <glob pattern="*.fp"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-fp.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-hip">
    <comment>Hippel</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="hip.*"/>
    <glob pattern="hipc.*"/>
    <glob pattern="*.hip"/>
    <glob pattern="*.hipc"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-hip.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-it">
    <comment>Impulse Tracker audio</comment>
    <icon name="audio-x-generic"/>
    <magic>
      <match type="string" value="IMPM" offset="0"/>
    </magic>
    <glob-deleteall/>
    <glob pattern="it.*"/>
    <glob pattern="*.it"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-it.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-lds">
    <comment>LOUDNESS Sound System</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="*.lds"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-lds.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-m2">
    <comment>Mark II Sound-System</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="m2.*"/>
    <glob pattern="mii.*"/>
    <glob pattern="mk2.*"/>
    <glob pattern="*.m2"/>
    <glob pattern="*.mii"/>
    <glob pattern="*.mk2"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-m2.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-mdx">
    <comment>Sharp X68000 MDX</comment>
    <icon name="audio-x-generic"/>
    <magic>
      <match value="0x0d" type="byte" offset="0:2047">
        <match value="0x0a" type="byte" offset="1:2048">
          <match value="0x1a" type="byte" offset="2:2049"/>
        </match>
      </match>
    </magic>
    <glob-deleteall/>
    <glob pattern="*.mdx"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-mdx.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-mod">
    <comment>Amiga SoundTracker audio</comment>
    <icon name="audio-x-generic"/>
    <magic priority="40">
      <match type="string" value="MTM" offset="0"/>
      <match type="string" value="MMD0" offset="0"/>
      <match type="string" value="MMD1" offset="0"/>
      <!-- 669 composer files: "if" and "JN" -->
      <match type="byte" value="0x0" mask="0x80" offset="112">
        <match type="string" value="if" offset="0">
          <!-- tempo list last byte: 0-31 (0 = known false positive) -->
          <match type="byte" value="0x0" mask="0xe0" offset="368">
            <!-- number of samples: 0-63 -->
            <match type="byte" value="0x0" mask="0xc0" offset="110">
              <!-- number of patterns: 0-128 -->
              <match type="byte" value="0x0" mask="0x80" offset="111"/>
              <match type="byte" value="0x80" offset="111"/>
            </match>
            <!-- number of samples: 64 -->
            <match type="byte" value="0x40" offset="110">
              <match type="byte" value="0x0" mask="0x80" offset="111"/>
              <match type="byte" value="0x80" offset="111"/>
            </match>
          </match>
          <!-- tempo list last byte: 32 -->
          <match type="byte" value="0x20" offset="368">
            <!-- number of samples: 0-63 -->
            <match type="byte" value="0x0" mask="0xc0" offset="110">
              <!-- number of patterns: 0-128 -->
              <match type="byte" value="0x0" mask="0x80" offset="111"/>
              <match type="byte" value="0x80" offset="111"/>
            </match>
            <!-- number of samples: 64 -->
            <match type="byte" value="0x40" offset="110">
              <match type="byte" value="0x0" mask="0x80" offset="111"/>
              <match type="byte" value="0x80" offset="111"/>
            </match>
          </match>
        </match>
        <match type="string" value="JN" offset="0">
          <match type="byte" value="0x0" mask="0xe0" offset="368">
            <match type="byte" value="0x0" mask="0xc0" offset="110">
              <match type="byte" value="0x0" mask="0x80" offset="111"/>
              <match type="byte" value="0x80" offset="111"/>
            </match>
          </match>
          <match type="byte" value="0x20" offset="368">
            <match type="byte" value="0x40" offset="110">
              <match type="byte" value="0x0" mask="0x80" offset="111"/>
              <match type="byte" value="0x80" offset="111"/>
            </match>
          </match>
        </match>
      </match>
      <match type="string" value="MAS_UTrack_V00" offset="0"/>
      <match type="string" value="M.K." offset="1080"/>
      <match type="string" value="M!K!" offset="1080"/>
    </magic>
    <glob-deleteall/>
    <glob pattern="669.*"/>
    <glob pattern="m15.*"/>
    <glob pattern="med.*"/>
    <glob pattern="mod.*"/>
    <glob pattern="mtm.*"/>
    <glob pattern="ult.*"/>
    <glob pattern="uni.*"/>
    <glob pattern="*.669"/>
    <glob pattern="*.m15"/>
    <glob pattern="*.med"/>
    <glob pattern="*.mod"/>
    <glob pattern="*.mtm"/>
    <glob pattern="*.ult"/>
    <glob pattern="*.uni"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-mod.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-mptm">
    <comment>OpenMPT Module</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="*.mptm"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-mptm.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-okt">
    <comment>Oktalyzer Module</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="okt.*"/>
    <glob pattern="*.okt"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-okt.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-prun">
    <comment>prun file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="prun.*"/>
    <glob pattern="pru2.*"/>
    <glob pattern="*.prun"/>
    <glob pattern="*.pru2"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-prun.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-psm">
    <comment>psm file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="*.psm"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-psm.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-pt3">
    <comment>pt3 file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="*.pt3"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-pt3.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-s3m">
    <comment>Scream Tracker 3 audio</comment>
    <icon name="audio-x-generic"/>
    <magic>
      <match value="SCRM" type="string" offset="44"/>
    </magic>
    <glob-deleteall/>
    <glob pattern="s3m.*"/>
    <glob pattern="*.s3m"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-s3m.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-sc2">
    <comment>sc2 file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="sc2.*"/>
    <glob pattern="*.sc2"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-sc2.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-sc68">
    <comment>sc68 file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="sc68.*"/>
    <glob pattern="*.sc68"/>
   </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-sc68.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-scl">
    <comment>scl file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="scl.*"/>
    <glob pattern="*.scl"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-scl.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-sid2">
    <comment>sid2 file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="sid2.*"/>
    <glob pattern="*.sid2"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-sid2.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-sndh">
    <comment>sndh file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="sndh.*"/>
    <glob pattern="*.sndh"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-sndh.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-spc">
    <comment>SNES SPC700</comment>
    <icon name="audio-x-generic"/>
    <magic>
      <match type="string" value="SNES-SPC700" offset="0"/>
    </magic>
    <glob-deleteall/>
    <glob pattern="*.spc"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-spc.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-spl">
    <comment>Sound Programming Language (SOPROL)</comment>
    <icon name="audio-x-generic"/>
    <magic>
      <match type="big32" value="0x000003f3" offset="0">
        <match type="big32" value="0x00000000" offset="4">
          <match type="big32" value="0x00000001" offset="8">
            <match type="big32" value="0x00000000" offset="12"/>
          </match>
        </match>
      </match>
    </magic>
    <glob-deleteall/>
    <glob pattern="spl.*"/>
    <glob pattern="*.spl"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-spl.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-stk">
    <comment>stk file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="stk.*"/>
    <glob pattern="*.stk"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-stk.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-stm">
    <comment>Scream Tracker audio</comment>
    <icon name="audio-x-generic"/>
    <magic>
      <match type="string" value="!Scream!\x1A" offset="20"/>
      <match type="string" value="!SCREAM!\x1A" offset="20"/>
      <match type="string" value="BMOD2STM\x1A" offset="20"/>
    </magic>
    <glob-deleteall/>
    <glob pattern="stm.*"/>
    <glob pattern="*.stm"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-stm.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-sun">
    <comment>sun file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="sun.*"/>
    <glob pattern="*.sun"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-sun.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-sunvox">
    <comment>sunvox file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="sunvox.*"/>
    <glob pattern="*.sunvox"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-sunvox.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-symmod">
    <comment>symmod file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="symmod.*"/>
    <glob pattern="*.symmod"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-symmod.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-tfmx">
    <comment>The Final Musicsystem eXtended</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="mdat.*"/>
    <glob pattern="mdst.*"/>
    <glob pattern="*.mdat"/>
    <glob pattern="*.mdst"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-tfmx.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-umx">
    <comment>umx file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="*.umx"/>
   </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-umx.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-v2m">
    <comment>v2m file</comment>
    <icon name="audio-x-generic"/>
    <glob-deleteall/>
    <glob pattern="v2m.*"/>
    <glob pattern="*.v2m"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-v2m.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-vgm">
    <comment>Video Game Music</comment>
    <icon name="audio-x-generic"/>
    <magic>
      <match type="string" value="Vgm " offset="0"/>
      <match type="big16" value="0x1f8b" offset="0"/>
    </magic>
    <glob-deleteall/>
    <glob pattern="vgm.*"/>
    <glob pattern="vgz.*"/>
    <glob pattern="*.vgm"/>
    <glob pattern="*.vgz"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-vgm.xml"

  mime_type_xml_file=$(
    cat <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="audio/x-xm">
    <comment>FastTracker II audio</comment>
    <icon name="audio-x-generic"/>
    <magic>
      <match value="Extended Module:" type="string" offset="0"/>
    </magic>
    <glob-deleteall/>
    <glob pattern="xm.*"/>
    <glob pattern="*.xm"/>
  </mime-type>
</mime-info>
EOF
  )
  sudo -u "$USER" cat <<<"$mime_type_xml_file" >"$mime_packages_dir_user/audio-x-xm.xml"
}

main "$@" exit

#TODO actually unsupported:
#audio/ogg audio/x-opus+ogg audio/rmid

#  cat <<'EOF' >"$mime_packages_dir_system/audio-rmid.xml"
#<?xml version="1.0" encoding="utf-8"?>
#<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
#  <mime-type type="audio/rmid">
#    <comment>RIFF MIDI (RMID)</comment>
#    <icon name="audio-x-generic"/>
#    <magic>
#      <match type="string" value="RIFF" offset="0">
#        <match type="string" value="RMIDdata" offset="8"/>
#      </match>
#    </magic>
#    <glob-deleteall/>
#    <glob pattern="*.mid"/>
#    <glob pattern="*.midi"/>
#  </mime-type>
#</mime-info>
#EOF
