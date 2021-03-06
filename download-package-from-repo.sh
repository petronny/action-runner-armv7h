#!/bin/sh
set -ex

package=$1
repo=$2
arch=$3
path=$4

repo=~/pacman/$repo
pacman_conf=$repo/pacman.conf
dbpath=$repo/db
gpgdir=$repo/gnupg

fakeroot pacman --arch $arch --config $pacman_conf --dbpath $dbpath --gpgdir $gpgdir --cachedir $path --noconfirm -Swdd $package
