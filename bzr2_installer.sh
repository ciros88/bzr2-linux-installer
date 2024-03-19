#!/bin/bash
#
# NAME
#     bzr2_installer.sh - experimental distribution-agnostic BZR Player 2 linux installer
#
# SYNOPSIS
#     ./bzr2_installer.sh
#
# DESCRIPTION
#     download, install and configure BZR Player 2 (bzr2) using wine
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
#     - an internet connection is required, at least, in order to properly run winetricks
#     - bzr2 versions older than 2.0.19.Alpha have not been tested
#
# AUTHOR
#     Ciro Scognamiglio

set -e

main() {
  bzr2_version_default="2.0.67"
  winearch_default="win64"
  force_reinstall_default="n"
  download_urls=(
    "http://bzrplayer.blazer.nu/getFile.php?id="
    "https://raw.githubusercontent.com/ciros88/bzr2-linux-installer/artifacts/artifacts/"
  )
  download_tries=2
  bzr2_zip_dir_default="."
  bzr2_xml_dir_default="."
  dpi_default="auto"
  mime_types_association_default="y"
  mime_types_supported=(
    application/ogg audio/flac audio/midi audio/mp2 audio/mpeg audio/prs.sid audio/vnd.wave audio/x-ahx audio/x-cust
    audio/x-ddmf audio/x-dw audio/x-dz audio/x-fc audio/x-fc-bsi audio/x-flac+ogg audio/x-fp audio/x-hip audio/x-hip-7v
    audio/x-hip-coso audio/x-hip-st audio/x-hip-st-coso audio/x-it audio/x-lds audio/x-m2 audio/x-mcmd audio/x-mdx
    audio/x-minipsf audio/x-mmdc audio/x-mo3 audio/x-mod audio/x-mpegurl audio/x-mptm audio/x-ntk audio/x-okt
    audio/x-prun audio/x-psf audio/x-psm audio/x-pt3 audio/x-ptk audio/x-s3m audio/x-sc2 audio/x-sc68 audio/x-scl
    audio/x-sid2 audio/x-sndh audio/x-soundmon audio/x-spc audio/x-spl audio/x-stk audio/x-stm audio/x-sun
    audio/x-sunvox audio/x-symmod audio/x-tfmx audio/x-tfmx-st audio/x-umx audio/x-v2m audio/x-vgm audio/x-vorbis+ogg
    audio/x-xm
  )

  bold=$'\e[1m'
  bold_reset=$'\e[0m'

  invalid_value_inserted_message="please insert a valid value"

  bzr2_wineprefix_dir_unversioned="$HOME/.bzr2"
  bzr2_exe_filename="BZRPlayer.exe"
  bzr2_launcher_filename="bzr2.sh"
  bzr2_xml_filename="x-bzr2.xml"
  bzr2_desktop_filename="bzr2.desktop"
  bzr2_icon_unversioned="$bzr2_wineprefix_dir_unversioned"/bzr2.png

  check_requirements
  check_installation_files

  has_matched_versioning_pattern_old=false

  get_bzr2_version

  bzr2_version="${bzr2_version,,}"

  get_winearch

  bzr2_exe="$bzr2_dir/$bzr2_exe_filename"
  bzr2_desktop="$bzr2_wineprefix_dir"/"$bzr2_desktop_filename"
  bzr2_icon="$bzr2_wineprefix_dir"/bzr2.png

  if [ -f "$bzr2_exe" ]; then
    is_already_installed=true

    echo -e "\nbzr2 ${bold}$bzr2_version${bold_reset} ${bold}$winearch${bold_reset} installation has been detected in \
${bold}$bzr2_wineprefix_dir${bold_reset}"
    get_force_reinstall
  else
    is_already_installed=false
    force_reinstall="$force_reinstall_default"
  fi

  if ! $is_already_installed || [ "$force_reinstall" = y ]; then
    get_bzr2_zip_filenames
    download_bzr2

    if [ "$is_zip_downloaded" == false ]; then
      get_bzr2_local_zip_dir
    fi
  fi

  get_dpi
  get_mime_types_association

  echo

  if ! $is_already_installed || [ "$force_reinstall" = y ]; then
    if [ "$force_reinstall" = y ]; then
      rm -rf "$bzr2_wineprefix_dir"
    fi

    setup_bzr2
  fi

  ln -sfn "$bzr2_wineprefix_dir" "$bzr2_wineprefix_dir_unversioned"

  echo "symbolic link ${bold}$bzr2_wineprefix_dir_unversioned${bold_reset} -> \
${bold}$bzr2_wineprefix_dir${bold_reset} has been created"

  setup_dpi
  setup_launcher_script

  ln -sfn "$bzr2_dir/resources/icon.png" "$bzr2_icon"

  setup_desktop_entry
  setup_launcher_icon

  if [ "$mime_types_association" = y ]; then
    setup_mime_types
  fi

  echo -e "\nAll done, enjoy bzr2!"
}

check_requirements() {
  local requirements=(
    realpath cat sed unzip update-desktop-database update-mime-database wine winetricks
    xdg-desktop-menu xdg-icon-resource xdg-mime xrdb install mktemp wget
  )

  for requirement in "${requirements[@]}"; do
    if ! type "$requirement" &>/dev/null; then
      echo -e "\nplease install ${bold}$requirement${bold_reset}"
      exit 1
    fi
  done
}

check_installation_files() {
  local bzr2_xml_dir
  bzr2_xml_dir=$(realpath -s "$bzr2_xml_dir_default")
  bzr2_xml="$bzr2_xml_dir"/"$bzr2_xml_filename"

  if [ ! -f "$bzr2_xml" ]; then
    echo -e "\nfile ${bold}$bzr2_xml${bold_reset} not found"
    exit 1
  fi
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
  #matches 2. >=0 AND <=9 . >=61 AND <=999
  local versioning_pattern="^[2]{1}(\.){1}+[0-9]+(\.){1}+(6[1-9]|[7-9][0-9]|[1-9][0-9]{2})$"

  #matches 2.0. >=19 AND <=60 . Alpha OR alpha
  local versioning_pattern_old="^[2]{1}(\.)[0]{1}+(\.){1}+(19|[2-5][0-9]|60){1}+(\.){1}+(Alpha|alpha)$"

  while :; do
    local input
    input=$(show_message_and_read_input "select the bzr2 version to manage" ${bzr2_version_default})

    if [[ "$input" =~ $versioning_pattern ]]; then
      break
    fi

    if [[ "$input" =~ $versioning_pattern_old ]]; then
      has_matched_versioning_pattern_old=true
      break
    fi

    echo -e "\n$invalid_value_inserted_message"
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

get_bzr2_zip_filenames() {
  if $has_matched_versioning_pattern_old; then
    bzr2_zip_filenames=("$(echo "$bzr2_version" | sed 's/.0.//;s/.Alpha//;s/.alpha//;s/$/.zip/')")
  else
    local bzr2_version_minor="${bzr2_version##*.}"

    if [ "$bzr2_version_minor" -lt 67 ]; then
      bzr2_zip_filenames=("$bzr2_version.zip")
    elif [ "$bzr2_version_minor" -eq 67 ]; then
      bzr2_zip_filenames=("$bzr2_version.zip" "BZR-Player-$bzr2_version.zip")
    else
      bzr2_zip_filenames=("BZR-Player-$bzr2_version.zip")
    fi
  fi
}

bzr2_zip_sanity_check() {
  echo -n "sanity check... "

  if unzip -tq "$1" >/dev/null 2>&1 && [ "$(unzip -l "$1" | grep -c "$bzr2_exe_filename")" -eq 1 ] >/dev/null 2>&1; then
    echo "OK"
    return 0
  else
    echo -n "FAIL"
    return 1
  fi
}

download_bzr2() {
  local download_dir
  for tmp_dir in "$XDG_RUNTIME_DIR" "$TMPDIR" "$(dirname "$(mktemp -u --tmpdir)")" "/tmp" "/var/tmp" "/var/cache"; do
    if [ -w "$tmp_dir" ]; then
      download_dir="$tmp_dir"
      break
    fi
  done

  local download_dir_msg
  if [ -z "$download_dir" ]; then
    download_dir_msg="unable to find a writable temp directory: "
    download_dir="$HOME"
  fi

  download_dir_msg+="bzr2 will be downloaded to ${bold}$download_dir${bold_reset}"
  echo -e "\n$download_dir_msg"

  local is_download_url_fallback=false

  for download_url in "${download_urls[@]}"; do
    for bzr2_zip_filename in "${bzr2_zip_filenames[@]}"; do
      if [ $is_download_url_fallback = true ]; then
        local query_string="$bzr2_zip_filename"
      else
        local query_string="$bzr2_version"
      fi

      echo -en "\ndownloading ${bold}$bzr2_zip_filename${bold_reset} from $download_url$query_string... "

      set +e
      wget -q --tries=$download_tries --backups=1 -P "$download_dir" -O "$download_dir/$bzr2_zip_filename" \
        "$download_url$query_string"

      local wget_result=$?
      set -e

      bzr2_zip="$download_dir/$bzr2_zip_filename"

      if [ $wget_result -eq 0 ] && unzip -tq "$bzr2_zip" >/dev/null 2>&1; then
        set +e
        bzr2_zip_sanity_check "$bzr2_zip"
        local is_zip_sane=$?
        set -e

        if [ $is_zip_sane -eq 0 ]; then
          is_zip_downloaded=true
          return
        fi
      else
        echo -n "FAIL"
      fi
    done

    is_download_url_fallback=true
  done

  echo -e "\n\nunable to download bzr2"
  is_zip_downloaded=false
  return
}

get_bzr2_local_zip_dir() {
  while :; do
    local bzr2_zip_dir
    bzr2_zip_dir=$(show_message_and_read_input "specify the folder path with bzr2 release zip archive(s)" \
      "$(realpath -s "$bzr2_zip_dir_default")")

    local bzr2_zips=()
    for bzr2_zip_filename in "${bzr2_zip_filenames[@]}"; do
      bzr2_zips+=("$bzr2_zip_dir"/"$bzr2_zip_filename")
    done

    for i in "${!bzr2_zips[@]}"; do
      if [ -f "${bzr2_zips[i]}" ]; then
        echo -en "\nrelease zip archive ${bold}${bzr2_zips[i]}${bold_reset} for version \
${bold}$bzr2_version${bold_reset} has been found... "

        set +e
        bzr2_zip_sanity_check "${bzr2_zips[i]}"
        local is_zip_sane=$?
        set -e

        if [ "$is_zip_sane" -eq 0 ]; then
          bzr2_zip="${bzr2_zips[i]}"
          break 2
        fi
      fi
    done

    if [ ${#bzr2_zips[@]} -gt 1 ]; then
      echo -e "\nnone of these files are found or valid:"

      for bzr2_zip in "${bzr2_zips[@]}"; do
        echo "${bold}${bzr2_zip}${bold_reset}"
      done

      echo -e "$invalid_value_inserted_message"
    else
      echo -e "\nvalid ${bold}${bzr2_zips[0]}${bold_reset} file not found... $invalid_value_inserted_message"
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

get_size_of_longer_array_entry() {
  local array=("$@")
  local longer_size=-1

  for entry in "${array[@]}"; do
    local length=${#entry}
    ((length > longer_size)) && longer_size=$length
  done

  echo "$longer_size"
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
      local mime_length_max
      mime_length_max=$(get_size_of_longer_array_entry "${mime_types_supported[@]}")
      local mime_comments=()
      local mime_patterns=()
      local bzr2_xml_content
      bzr2_xml_content=$(cat "$bzr2_xml_filename")

      for mime_type in "${mime_types_supported[@]}"; do
        local sed_pattern="\|<mime-type type=\"$mime_type\">| , \|</mime-type>|{p; \|</mime-type>|q}"
        local mime_single
        mime_single=$(echo "$bzr2_xml_content" | sed -n "$sed_pattern")

        if [ -z "$mime_single" ]; then
          mime_single=$(sed -n "$sed_pattern" "/usr/share/mime/packages/freedesktop.org.xml")
        fi

        mime_comments+=("$(echo "$mime_single" | grep "<comment>" | sed 's:<comment>::;s:</comment>::;s:    ::')")
        local mime_pattern
        mime_pattern=$(echo "$mime_single" | grep "<glob pattern=" | sed -e 's:<glob pattern="::g' -e 's:"/>::g')
        local mime_pattern_split=()

        while read -r line; do
          mime_pattern_split+=("$line")
        done <<<"$mime_pattern"

        local mime_comment_length_max
        mime_comment_length_max=$(get_size_of_longer_array_entry "${mime_comments[@]}")
        local delimiter="  "
        local padding_size=$((mime_length_max + mime_comment_length_max + ${#delimiter} + ${#delimiter}))
        local padding_string=""

        for ((i = 0; i < "$padding_size"; i++)); do
          padding_string+=" "
        done

        local max_patterns_per_chunk=4
        local mime_pattern_chunks=()

        for ((i = 0; i < ${#mime_pattern_split[@]}; i++)); do
          local div=$((i / max_patterns_per_chunk))
          if [ $div -gt 0 ] && [ $((i % max_patterns_per_chunk)) -eq 0 ]; then
            mime_pattern_chunks[div]=${mime_pattern_chunks[div]}$padding_string"["${mime_pattern_split[$i]}]
          else
            if [ "$i" -eq 0 ]; then
              mime_pattern_chunks[div]="${mime_pattern_chunks[div]}[${mime_pattern_split[$i]}]"
            else
              mime_pattern_chunks[div]="${mime_pattern_chunks[div]}[${mime_pattern_split[$i]}]"
            fi
          fi
        done

        mime_pattern=""

        for ((i = 0; i < ${#mime_pattern_chunks[@]}; i++)); do
          mime_pattern="$mime_pattern${mime_pattern_chunks[$i]}"$'\n'
        done

        mime_pattern=$(sed -z 's/.$//' <<<"$mime_pattern")
        mime_patterns+=("$mime_pattern")
      done

      echo -e "\nbzr2 supports following MIME types:\n"

      for i in "${!mime_types_supported[@]}"; do
        printf "%${mime_length_max}s$delimiter%${mime_comment_length_max}s$delimiter%s\n" "${mime_types_supported[$i]}" \
          "${mime_comments[$i]}" "${mime_patterns[$i]}"
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
  mkdir -p "$bzr2_dir"
  unzip -oq "$bzr2_zip" -d "$bzr2_dir"
  WINEDEBUG=-all WINEPREFIX="$bzr2_wineprefix_dir" WINEARCH="$winearch" winetricks nocrashdialog \
    autostart_winedbg=disabled
}

setup_dpi() {
  local dpi_to_set

  case "$dpi" in
  "default") return ;;

  "auto")
    dpi_to_set=$(xrdb -query | grep dpi | sed 's/.*://;s/^[[:space:]]*//')
    if [ -z "$dpi_to_set" ]; then
      echo -e "\nunable to retrieve the screen ${bold}DPI${bold_reset}: the ${bold}default${bold_reset} will be used \
in wine"
      return
    fi
    ;;

  *)
    dpi_to_set=$dpi
    ;;
  esac

  echo -e "\nsetting wine ${bold}DPI${bold_reset} to ${bold}$dpi_to_set${bold_reset}\n"

  dpi_to_set='0x'$(printf '%x\n' "$dpi_to_set")

  WINEDEBUG=-all WINEPREFIX="$bzr2_wineprefix_dir" WINEARCH="$winearch" wine reg add \
    "HKEY_CURRENT_USER\Control Panel\Desktop" /v LogPixels /t REG_DWORD /d "$dpi_to_set" /f

  WINEDEBUG=-all WINEPREFIX="$bzr2_wineprefix_dir" WINEARCH="$winearch" wine reg add \
    "HKEY_CURRENT_USER\Software\Wine\Fonts" /v LogPixels /t REG_DWORD /d "$dpi_to_set" /f

  WINEDEBUG=-all WINEPREFIX="$bzr2_wineprefix_dir" WINEARCH="$winearch" wine reg add \
    "HKEY_CURRENT_CONFIG\Software\Fonts" /v LogPixels /t REG_DWORD /d "$dpi_to_set" /f
}

setup_launcher_script() {

  cat <<EOF >"$bzr2_wineprefix_dir/$bzr2_launcher_filename"
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

  sed -i '$s/$/ "$@" \&/' "$bzr2_wineprefix_dir"/"$bzr2_launcher_filename"

  chmod +x "$bzr2_wineprefix_dir"/"$bzr2_launcher_filename"
}

setup_desktop_entry() {
  echo -e "\ninstalling bzr2 desktop menu entry"
  local desktop_entry_mime_types=""

  for mime_type in "${mime_types_supported[@]}"; do
    desktop_entry_mime_types="$desktop_entry_mime_types$mime_type;"
  done

  cat <<EOF >"$bzr2_desktop"
[Desktop Entry]
Type=Application
Name=BZR Player 2
GenericName=Audio player
Comment=Audio player supporting a wide types of exotic file formats
Icon=$bzr2_icon_unversioned
Exec=$bzr2_wineprefix_dir_unversioned/$bzr2_launcher_filename %U
Categories=AudioVideo;Audio;Player;Music;
MimeType=$desktop_entry_mime_types
Terminal=false
NoDisplay=false
#Path=
#StartupNotify=
EOF

  xdg-desktop-menu install --novendor --mode user "$bzr2_desktop"
}

setup_launcher_icon() {
  echo -e "\ninstalling bzr2 icon for bzr2 launcher"

  for size in 16 22 24 32 48 64 128 256 512; do
    xdg-icon-resource install --noupdate --novendor --context apps --mode user --size ${size} "$bzr2_icon_unversioned"
  done

  xdg-icon-resource forceupdate

  if type gtk-update-icon-cache &>/dev/null; then
    echo
    gtk-update-icon-cache -t -f "$HOME/.local/share/icons/hicolor"
  fi
}

setup_mime_types() {
  echo -e "\nassociating bzr2 to all supported MIME types"

  local mime_dir_user=$HOME/.local/share/mime
  local mime_packages_dir_user="$mime_dir_user/packages"
  install -D -m644 "$bzr2_xml" "$mime_packages_dir_user"
  xdg-mime default $bzr2_desktop_filename "${mime_types_supported[@]}"
  update-mime-database "$mime_dir_user"
  update-desktop-database "$HOME/.local/share/applications"
}

main "$@" exit
