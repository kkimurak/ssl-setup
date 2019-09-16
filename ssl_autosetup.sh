#! /bin/bash

# Automatic setup script for RoboCup Small Size League
# K_Kimura / KIKS 2016-2018
# Released under the Unlicense
# http://unlicense.org/

set -Ceu

script_dir=$(cd $(dirname $0); pwd)

function error_end {
    echo "[ERROR] Installation imcomplete."
    exit 1
}

function check_root {
    if [ "$(whoami)" != "root" ]; then
        echo "[ERROR] Please run as root!  (e.g. $ sudo bash ssl_autosetup.sh"
        error_end
    fi
}

function get_os_distribution() {
    # Copyright (c) 2016 Kohei Arao
    # https://github.com/koara-local/dotfiles
    # Released under the Unlicense
    # http://unlicense.org/
    local distri_name

    if   [ -e /etc/debian_version ] ||
         [ -e /etc/debian_release ]; then
        # Check Ubuntu or Debian
        if [ -e /etc/lsb-release ]; then
            # Ubuntu
            distri_name="ubuntu"
        else
            # Debian
            distri_name="debian"
        fi
    elif [ -e /etc/fedora-release ]; then
        # Fedra
        distri_name="fedora"
    elif [ -e /etc/redhat-release ]; then
        if [ -e /etc/oracle-release ]; then
            # Oracle Linux
            distri_name="oracle"
        else
            # Red Hat Enterprise Linux
            distri_name="redhat"
        fi
    elif [ -e /etc/arch-release ]; then
        # Arch Linux
        distri_name="arch"
    elif [ -e /etc/turbolinux-release ]; then
        # Turbolinux
        distri_name="turbol"
    elif [ -e /etc/SuSE-release ]; then
        # SuSE Linux
        distri_name="suse"
    elif [ -e /etc/mandriva-release ]; then
        # Mandriva Linux
        distri_name="mandriva"
    elif [ -e /etc/vine-release ]; then
        # Vine Linux
        distri_name="vine"
    elif [ -e /etc/gentoo-release ]; then
        # Gentoo Linux
        distri_name="gentoo"
    else
        # Other
        echo "unkown distribution"
        distri_name="unkown"
    fi

    echo "$distri_name"
}

function install_ode_013() {
    wget https://jaist.dl.sourceforge.net/project/opende/ODE/0.13/ode-0.13.tar.bz2 || echo "Failed to download ode-0.13.tar.bz2. Check your internet connection."
    tar xf ode-0.13.tar.bz2 && rm ode-0.13.tar.bz2
    cd ode-0.13
    ./configure --disable-demos --enable-double-precision
    make -s >/dev/null
    make install
    cd ../
}

function install_vartype() {
    # install "vartypes" that required by grSim
    git clone https://github.com/jpfeltracco/vartypes.git || echo "Failed to clone vartypes"
    cd vartypes
    mkdir build && cd "$_"
    cmake .. && make -s >/dev/null || echo "Failed to build vartypes"
    make install || echo "Failed to install vartypes"
    cd ../
}

function install_libraries() {
    # temporary folder to build ODE, vartypes
    local path_tmp=/home/$(logname)/Documents/sslinst_tmp/

    # packages required to run this script
    local dnf_pkg_script="curl git cmake make gcc gcc-c++ jq"
    local dnf_pkg_grsim="mesa-libGL-devel mesa-libGLU-devel qt-devel protobuf-compiler protobuf-devel boost-devel"
    local dnf_pkg_ssl_vision="qt-devel eigen3 libjpeg libpng v4l-utils libdc1394 libdc1394-devel protobuf-compiler protobuf-devel opencv-devel freeglut-devel zlib"
    local dnf_pkg_ssl_logtools="protobuf-compiler zlib-devel boost-program-options"
    local dnf_pkg_ssl_autoref="patch"

    local pacman_pkg_script="curl git cmake make gcc jq wget"
    local pacman_pkg_grsim="mesa glu ode qt5-base protobuf boost"
    local pacman_pkg_ssl_vision="qt5-base eigen protobuf libdc1394 jsoncpp v4l-utils"
    local pacman_pkg_ssl_logtools="protobuf zlib boost"
    local pacman_pkg_ssl_autoref="patch"

    if [ ! -e "$path_tmp" ]
    then
        mkdir -p "$path_tmp"
    fi
    cd "$path_tmp"

    DISTRIBU=$(get_os_distribution)
    echo "You're using $DISTRIBU"
    case "$DISTRIBU" in
        "fedora" )
            # update system
            dnf -y update || echo "Failed to Update system. Check internet connection and Disk Space."

            # install most of required packages for Robocup-SSL official tools (without Autoref)
            dnf -y install ${dnf_pkg_script} ${dnf_pkg_grsim} ${dnf_pkg_ssl_vision} ${dnf_pkg_ssl_logtools} ${dnf_pkg_ssl_autoref} || echo "Failed to instlal some packages."

            # in fedora, you have to build ODE-0.13 from source. new version of ODE will cause freeze of grSim
            install_ode_013
            ;;
        "ubuntu" )
            apt update -qq || echo "Failed to update" 
            
            # install most of required packages for Robocup-SSL official tools (without Autoref)
            apt-get -qq -y install curl git build-essential cmake libyaml-dev libqt4-dev libgl1-mesa-dev libglu1-mesa-dev libprotobuf-dev protobuf-compiler libode-dev libboost-all-dev g++ libeigen3-dev libdc1394-22 libdc1394-22-dev libv4l-0 zlib1g-dev libgtkmm-2.4-dev libopencv-dev freeglut3-dev jq || echo "Failed to install some packages"

            # if you're using ubuntu, you don't need to build ODE from source. Lucky you!
            ;;
        "arch" )
            # update
            yes | pacman -Syyu

            pacman -S --noconfirm --needed base-devel

            # install most of required packages for Robocup-SSL official tools (without Autoref)
            yes | pacman -S ${pacman_pkg_script} ${pacman_pkg_grsim} ${pacman_pkg_ssl_vision} ${pacman_pkg_ssl_logtools} ${pacman_pkg_ssl_autoref} --needed || echo "Failed to install some packages"
            ;;
        * )
            echo "Not supported.";
            exit
            ;;
    esac

    # install libraries for ssl-autorefs
    curl https://raw.githubusercontent.com/RoboCup-SSL/ssl-autorefs/master/installDeps.sh | bash

    if ! ls /usr/local/lib/*vartypes* > /dev/null; then
        install_vartype
    fi
    cd ${script_dir}
    rm -r ${path_tmp}
}

function build_ssl_tools() {
    echo "Download and build RoboCup-SSL Tools"
    echo "grSim , ssl-vision , ssl-logtools , ssl-game-controller , ssl-vision-client"
    echo ""
    echo "Where do you want to place these application?"
    echo "(if you're a beginner, just press Enter)"
    echo -n "[default:/home/$(logname)/Documents/robocup/tools] >"
    while :
    do
    read -r -t 60 SSL_DIR || if [ "$?" == "142" ] ; then echo " set to default..."; fi
    case $SSL_DIR in
        # if typed so it seems to be not problem, but can't do "git clone"
        "home/" | "home" | "/home" | "/home/" )
            echo "You Don't have permission to access. Please use /home/<username>/ or just type Enter.";;
        # other case
        * )
            # nothing typed
            if test -z "$SSL_DIR"
            then
                mkdir -p /home/$(logname)/Documents/robocup/tools && cd "$_" && break
            else
                echo "install for $SSL_DIR."
                mkdir -p "$SSL_DIR" && cd "$_" && break
            fi
        ;;
    esac
    done

    # build grSim , ssl-vision , ssl-refbox , ssl-logtools
    git clone https://github.com/RoboCup-SSL/grSim.git || echo "Failed to clone grSim"
    git clone https://github.com/RoboCup-SSL/ssl-vision.git || echo "Failed to clone ssl-vision"
    git clone https://github.com/RoboCup-SSL/ssl-logtools.git || echo "Failed to clone ssl-logtools"
    git clone https://github.com/RoboCup-SSL/ssl-autorefs.git --recursive|| echo "Failed to clone ssl-autorefs"

    # grsim
    cd grSim && mkdir build && cd "$_"
    cmake .. && make || echo "Failed to build grSim"

    # ssl-vision/graphicalClient
    cd ../../ssl-vision
    make || echo "Failed to build ssl-vision"

    # ssl-logtools
    cd ../ssl-logtools && mkdir build && cd "$_"
    cmake .. && make || echo "Failed to build ssl-logtools"

    cd ../../ssl-autorefs
    bash buildAll.sh

    # new ssl client (ssl-game-controller and so on)
    cd ../
    mkdir games && cd $_
    wget `curl -s https://api.github.com/repos/robocup-ssl/ssl-game-controller/releases | jq -r '.[0].assets[] | select(.name | test("linux_amd64")) | .browser_download_url'`
    wget `curl -s https://api.github.com/repos/robocup-ssl/ssl-vision-client/releases | jq -r '.[0].assets[] | select(.name | test("linux_amd64")) | .browser_download_url'`
    chmod +x ssl*
}

function install_dev_tools() {
    local ins_tools
    echo ""
    echo "Do you want to install these usefull tools :"
    echo "vim - Text/Code Editor"
    echo "wireshark - network protocol analyzer"
    echo "htop - performance analyzer"
    echo "strace & ltrace - debug tools"
    echo -n "[Y/n]:"

    read -r -t 60 ins_tools || if [ "$?" == "142" ] ; then echo " set to default..."; fi
    case "$ins_tools" in
        "" | "y" | "Y" | "yes" | "Yes" | "YES" )
            case "$DISTRIBU" in
                "fedora" )
                    dnf -y install htop wireshark strace ltrace vim
                    ;;
                "ubuntu" )
                    apt-get -qq -y install htop wireshark strace ltrace vim
                    ;;
                "arch" )
                    yes | pacman -S htop wireshark-cli strace ltrace vim
                    ;;
                * )
                    echo "Not supported.";
                    exit
                ;;
            esac
            xdg-open https://qiita.com/mfujimori/items/9fd41bcd8d1ce9170301
            ;;
        * )
            echo "Didn't install these tools."
            ;;
    esac
}


# Script start from here
flag_build="--rec_to_build"

if [ $# -lt 1 ]; then
    echo "This installer will setup the tools for RoboCup-SSL in your computer."

    check_root
    install_libraries || exit
    su $(logname) -c "cd ${script_dir}; bash ssl_autosetup.sh ${flag_build}" || exit
    install_dev_tools

    echo ""
    echo "Done."
elif [ $1 == ${flag_build} ]; then
    if [ ${USER} == "root" ]; then
        echo "[ERROR] invalid usage detected. please try again with no argment"
    else
        build_ssl_tools
    fi
else
    echo "[ERROR] invalid argment"
fi
