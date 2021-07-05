# Dockerfile:kazu1192/archlinux
# Github:kazu1192/docker_archlinux_kazu1192
# 参考元:https://github.com/u1and0/docker_archlinux_env
# -----
# Usage:
# docker run -it --rm -v `pwd`:/work -w /work kazu1192/archlinux
#
# For building:
# docker build --build-arg branch="v1.15.1" -t kazu1192/archlinux .

FROM archlinux:base

# Put the latest mirrorlist for Arch Linux in place
COPY mirrorlist /etc/pacman.d/mirrorlist

# Language setting
ARG SETLANG="en_US"
ENV LANG="${SETLANG}.UTF-8"\
    LC_NUMERIC="${SETLANG}.UTF-8"\
    LC_TIME="${SETLANG}.UTF-8"\
    LC_MONETARY="${SETLANG}.UTF-8"\
    LC_PAPER="${SETLANG}.UTF-8"\
    LC_MEASUREMENT="${SETLANG}.UTF-8"

# Locale setting
ARG GLIBVER="2.33"
ARG LOCALETIME="Asia/Tokyo"
RUN : "Copy missing language pack '${SETLANG}'" &&\
    curl http://ftp.gnu.org/gnu/libc/glibc-${GLIBVER}.tar.bz2 | tar -xjC /tmp &&\
    cp /tmp/glibc-${GLIBVER}/localedata/locales/${SETLANG} /usr/share/i18n/locales/ &&\
    rm -rf /tmp/* &&\
    : "Overwrite locale-gen" &&\
    echo ${SETLANG}.UTF-8 UTF-8 > /etc/locale.gen &&\
    locale-gen &&\
    : "Set time locale, Do not use 'timedatectl set-timezone Asia/Tokyo'" &&\
    ln -fs /usr/share/zoneinfo/${LOCALETIME} /etc/localtime

RUN : "Fix pacman.conf" &&\
    sed -ie 's/#Color/Color/' /etc/pacman.conf &&\
    pacman -Syy --noconfirm archlinux-keyring &&\
    pacman -Su --noconfirm git openssh base-devel &&\
    : "Clear cache" &&\
    pacman -Qtdq | xargs -r pacman --noconfirm -Rcns

ARG USERNAME=kazu1192
# docker build --Build-arg USERNAME=${USERNAME} -t kazu1192/archlinux .
ARG UID=1000
ARG GID=1000
RUN echo "Build start with USERNAME: $USERNAME UID: $UID GID: $GID" &&\
    : "Add yay option" &&\
    echo '[multilib]' >> /etc/pacman.conf &&\
    echo 'Include = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf &&\
    pacman -Sy &&\
    : "Add user ${USERNAME} for yay install" &&\
    groupadd -g ${GID} ${USERNAME} &&\
    useradd -u ${UID} -g ${GID} -l -m -s /bin/bash ${USERNAME} &&\
    passwd -d ${USERNAME} &&\
    mkdir -p /etc/sudoers.d &&\
    touch /etc/sudoers.d/${USERNAME} &&\
    echo "${USERNAME} ALL=(ALL) ALL" > /etc/sudoers.d/${USERNAME} &&\
    mkdir -p /home/${USERNAME}/.gnupg &&\
    echo 'standard-resolver' > /home/${USERNAME}/.gnupg/dirmngr.conf &&\
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} &&\
    mkdir /build &&\
    chown -R ${USERNAME}:${USERNAME} /build

# User initialize
WORKDIR "/build"
RUN sudo -u ${USERNAME} git clone --depth 1 https://aur.archlinux.org/yay.git
WORKDIR "/build/yay"
RUN sudo -u ${USERNAME} makepkg --noconfirm -si &&\
    sudo -u ${USERNAME} yay --afterclean --removemake --save &&\
    pacman -Qtdq | xargs -r pacman --noconfirm -Rcns &&\
    : "Remove caches forcely" &&\
    : "[error] yes | pacman -Scc" &&\
    rm -rf /home/${USERNAME}/.cache &&\
    rm -rf /build

# Initialize install
USER ${USERNAME}
RUN yay -Syyu --noconfirm \
    vim neovim fd fzf ripgrep awk w3m tig zsh tmux global man man-pages-ja &&\
    : "Remove all packages cache " &&\
    yay -Scc --noconfirm

WORKDIR "/home/${USERNAME}"
ARG branch=master
RUN git clone --branch $branch\
    https://github.com/kazu1192/dotfiles.git .dotfiles &&\
    bash .dotfiles/install.sh

# Install zinit
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zinit/master/doc/install.sh)"

# Install vim-plugin
RUN curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

CMD ["/usr/bin/zsh"]

LABEL maintainer="kazu1192 <kazu1192@protonmail.com>"\
      description="My ArchLinux container."\
      version="1.0.0"
