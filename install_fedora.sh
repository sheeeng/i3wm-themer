#!/usr/bin/env bash

set -o errexit
# set -o xtrace

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
WORKING_DIR="$(pwd)"
echo "\${SCRIPT_DIR}: ${SCRIPT_DIR}"
echo "\${WORKING_DIR}: ${WORKING_DIR}"

if [[ $EUID -ne 0 ]]; then
    printf "Error: This script has to be run under the root user."
    exit 1
fi

function preparation() {
  # Look for env command and link if not found to help make scripts uniform
  if [ -e /bin/env ]; then
    echo "... /bin/env found."
  else
    ln --symbolic /usr/bin/env /bin/env
  fi

  echo "\${SUDO_USER}: ${SUDO_USER}"
}

function install_required_packages() {
    # dnf autoremove --assumeyes;
    # dnf upgrade --assumeyes;
    dnf update --assumeyes;
    dnf install \
      @development-tools \
      autoconf \
      automake \
      git \
      make \
      nitrogen \
      pavucontrol \
      polybar \
      rofi \
      rxvt-unicode \
      libxcb-devel \
      xcb-util-keysyms-devel \
      xcb-util-devel \
      xcb-util-wm-devel \
      xcb-util-cursor-devel \
      xorg-x11-server-devel \
      dh-autoreconf \
      unzip \
      wireless-tools \
      --assumeyes
}

# su "${SUDO_USER}" -c "curl \
#     --fail \
#     --show-error \
#     --silent \
#     --location \
#     http://www.srware.net/downloads/iron-linux-64.tar.gz \
#     --output "${WORK_DIR}/iron-linux-64.tar.gz"
# "

function install_xcb() {
  echo "!!!! INSTALL XCB !!!!"
  rm --force --recursive xcb-util-xrm

  git clone --recursive https://github.com/Airblader/xcb-util-xrm.git
  # shellcheck disable=SC2164
  cd xcb-util-xrm/
  ./autogen.sh
  make
  make install
  # shellcheck disable=SC2103
  cd ..
  rm --force --recursive xcb-util-xrm
}


function refresh_shared_libraries() {
  echo "!!!! REFRESH SHARED LIBRARIES !!!!"

    #cat > /etc/ld.so.conf.d/i3.conf
    #/usr/local/lib/

    ldconfig
    ldconfig --print-cache --verbose
}

function install_i3_gaps() {

  echo "!!!! INSTALL I3 GAPS !!!!"

    rm --force --recursive i3-gaps

    git clone https://www.github.com/Airblader/i3.git i3-gaps
    # shellcheck disable=SC2164
    cd i3-gaps

    dnf install \
      meson \
      ninja-build \
      --assumeyes

    meson build
    ninja -C build/ install

    # autoreconf --force --install
    # rm -Rf build/
    # mkdir build
    # # shellcheck disable=SC2164
    # cd build/
    # ../configure --prefix=/usr --sysconfdir=/etc --disable-sanitizers
    # make
    # sudo make install
    # which i3
    # ls -l /usr/bin/i3
    cd ../..
    rm --force --recursive i3-gaps

}

function install_fonts_awesome() {

  echo "!!!! INSTALL FONTS AWESOME !!!!"

    # Added PYTHONDONTWRITEBYTECODE to prevent __pycache__
    export PYTHONDONTWRITEBYTECODE=1
    sudo -H pip3 install -r requirements.txt

    [ -d /usr/share/fonts/opentype ] || sudo mkdir /usr/share/fonts/opentype
    sudo git clone https://github.com/adobe-fonts/source-code-pro.git /usr/share/fonts/opentype/scp
    mkdir fonts
    # shellcheck disable=SC2164
    cd fonts
    wget https://use.fontawesome.com/releases/v5.15.1/fontawesome-free-5.15.1.zip
    unzip fontawesome-free-5.0.13.zip
    # shellcheck disable=SC2164
    cd fontawesome-free-5.0.13
    sudo cp use-on-desktop/* /usr/share/fonts
    sudo fc-cache -f -v
    cd ../..
    rm --force --recursive fonts
}

function install_polybar() {

  echo "!!!! INSTALL POLYBAR !!!!"

    git clone https://github.com/jaagr/polybar.git
    # shellcheck disable=SC2164
    cd polybar
    # shellcheck disable=SC2164
    env USE_GCC=ON ENABLE_I3=ON ENABLE_ALSA=ON ENABLE_PULSEAUDIO=ON ENABLE_NETWORK=ON ENABLE_MPD=ON ENABLE_CURL=ON ENABLE_IPC_MSG=ON INSTALL=OFF INSTALL_CONF=OFF ./build.sh -f
    # shellcheck disable=SC2164
    cd build
    sudo make install
    make userconfig
    cd ../..
    rm --force --recursive polybar
}

function create_config_files() {
  echo "!!!! CREATE CONFIG FILES !!!!"

    # File didn't exist for me, so test and touch
    if [ -e "$HOME"/.Xresources ]; then
      echo "... .Xresources found."
    else
      touch "$HOME"/.Xresources
    fi

    # File didn't exist for me, so test and touch
    if [ -e "$HOME"/.config/nitrogen/bg-saved.cfg ]; then
      echo "... .bg-saved.cfg found."
    else
      mkdir "$HOME"/.config/nitrogen
      touch "$HOME"/.config/nitrogen/bg-saved.cfg
    fi

    # File didn't excist for me, so test and touch
    if [ -e "$HOME"/.config/polybar/config ]; then
      echo "... polybar/config found."
    else
      mkdir "$HOME"/.config/polybar
      touch "$HOME"/.config/polybar/config
    fi

    # File didn't excist for me, so test and touch
    if [ -e "$HOME"/.config/i3/config ]; then
      echo "... i3/config found."
    else
      mkdir "$HOME"/.config/i3
      touch "$HOME"/.config/i3/config
    fi

    # Compton config file doesn't come by default
    if [ -e "$HOME"/.config/compton.conf ]; then
        echo "... compton.conf found"
    else
        cp "/usr/share/doc/compton/examples/compton.sample.conf" "$HOME/.config/compton.conf"
    fi

}

function apply_default_theme() {
  echo "!!!! APPLY DEFAULT THEME !!!!"

  # Rework of user in config.yaml
  rm -f config.yaml
  cp defaults/config.yaml .
  sed -i -e "s/USER/$USER/g" config.yaml

  # Backup
  mkdir "$HOME"/Backup
  python3 i3wm-themer.py --config config.yaml --backup "$HOME"/Backup

  # Configure and set theme to default
  cp -r scripts/* /home/"$USER"/.config/polybar/
  python3 i3wm-themer.py --config config.yaml --install defaults/

  echo ""
  echo "Read the README.md"
}

preparation
install_required_packages
install_xcb
refresh_shared_libraries
install_i3_gaps
install_fonts_awesome
install_polybar
create_config_files
apply_default_theme
