# Maintainer: Ciro Scognamiglio <ciro.scognamiglio88 (at) gmail.com>
# Contributor: Ciro Scognamiglio <ciro.scognamiglio88 (at) gmail.com>

pkgname='BZR Player 2'
_pkgname='bzr2'
pkgver='2.0.68'
pkgrel='1'
pkgdesc='Audio player supporting a wide types of exotic file formats'
arch=('i686' 'x86_64')
url='http://bzrplayer.blazer.nu/'
license=('GPL')                                                                              #TODO
depends=('wine' 'winetricks')
makedepends=('gendesk' 'unzip')
optdepends=("xorg-xrdb")                                                                     #TODO
options=(!strip)
source=("http://bzrplayer.blazer.nu/getFile.php?id=${pkgver}"
        "https://raw.githubusercontent.com/ciros88/bzr2-linux-installer/master/x-bzr2.xml")

#sha256sums=('22485490a3be032d5671e64d7a4208e9a1cb3a681c8067f1d211a8e657451396')             #TODO
#sha256sums=('22485490a3be032d5671e64d7a4208e9a1cb3a681c8067f1d211a8e657451396')

# https://wiki.archlinux.org/title/Creating_packages
# https://wiki.archlinux.org/title/PKGBUILD
# https://wiki.archlinux.org/title/Wine_package_guidelines
# https://wiki.archlinux.org/title/desktop_entries#gendesk

prepare()
{
gendesk -n -f --pkgname "$_pkgname" --pkgdesc "$pkgdesc" \
    --name=$pkgname \
    --genericname='Audio player' \
    --exec '' \
    --icon '' \
    --categories 'AudioVideo;Audio;Player;Music' \
    --mimetype='' \
}

package()
{
install -Dm644 "$_pkgname.desktop" "$pkgdir/usr/share/applications/$_pkgname.desktop"
}