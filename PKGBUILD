# Maintainer: Ciro Scognamiglio <ciro.scognamiglio88 (at) gmail.com>
# Contributor: Ciro Scognamiglio <ciro.scognamiglio88 (at) gmail.com>

pkgname='bzr-player'
_pkgname='BZR Player'
_pkgname_zip='BZR-Player'
pkgver='2.0.68'
pkgrel='1'
pkgdesc='Audio player supporting a wide types of multi-platform exotic file formats'
arch=('i686' 'x86_64')
url='http://bzrplayer.blazer.nu/'
license=('GPL')                                                                              #TODO
depends=('wine' 'winetricks')
makedepends=('gendesk' 'unzip')
optdepends=("xorg-xrdb")                                                                     #TODO
options=(!strip)
source=("http://bzrplayer.blazer.nu/getFile.php?id=${pkgver}"
        "https://raw.githubusercontent.com/ciros88/bzr2-linux-installer/master/x-bzr-player.xml")

#sha256sums=('22485490a3be032d5671e64d7a4208e9a1cb3a681c8067f1d211a8e657451396')

# https://wiki.archlinux.org/title/Creating_packages
# https://wiki.archlinux.org/title/PKGBUILD
# https://wiki.archlinux.org/title/Wine_package_guidelines
# https://wiki.archlinux.org/title/desktop_entries#gendesk

prepare()
{

cd "$srcdir"
  unzip -od "$srcdir/$pkgname-$pkgver" "$_pkgname_zip-$pkgver.zip"

gendesk -n -f --pkgname "$pkgname" --pkgdesc "$pkgdesc" \
    --name=$_pkgname \
    --genericname='Audio player' \
    --exec '' \
    --icon '' \
    --categories 'AudioVideo;Audio;Player;Music' \
    --mimetype='' \
}

package()
{
install -Dm644 "$pkgname.desktop" "$pkgdir/usr/share/applications/$pkgname.desktop"
}