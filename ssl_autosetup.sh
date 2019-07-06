#! /bin/bash

# Automatic setup script for RoboCup Small Size League
# K_Kimura / KIKS 2016-2018
# Released under the Unlicense
# http://unlicense.org/

set -Ceu

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

function install_libraries() {
    # temporary folder to build ODE, vartypes
    local path_tmp=/home/"$USER"/Documents/sslinst_tmp/

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
            sudo dnf -y update || echo "Failed to Update system. Check internet connection and Disk Space."

            # install most of required packages for Robocup-SSL official tools (without Autoref)
            sudo dnf -y install git boost-devel clang cmake eigen3 libtool libyaml-devel make ninja-build protobuf-devel automake gcc gcc-c++ kernel-devel qt-devel mesa-libGL-devel mesa-libGLU-devel protobuf-compiler ode ode-devel gtkmm24-devel libjpeg libpng v4l-utils libdc1394 libdc1394-devel opencv-devel freeglut-devel zlib jq || echo "Failed to instlal some packages."

            # in fedora, you have to build ODE-0.13 from source. new version of ODE will cause freeze of grSim
            wget https://jaist.dl.sourceforge.net/project/opende/ODE/0.13/ode-0.13.tar.bz2 || echo "Failed to download ode-0.13.tar.bz2. Check your internet connection."
            tar xf ode-0.13.tar.bz2 && rm ode-0.13.tar.bz2
            cd ode-0.13
            ./configure --disable-demos --enable-double-precision
            make
            sudo make install
            cd ../
            ;;
        "ubuntu" )
            # add install repository for boost
            sudo add-apt-repository ppa:boost-latest/ppa -y || echo "Failed to add repository for boost"
            sudo apt-get update || echo "Failed to update" 
            sudo apt-get purge boost* -y || echo "Failed to purge boost"

            # install most of required packages for Robocup-SSL official tools (without Autoref)
            sudo apt-get -y install git build-essential cmake libyaml-dev libqt4-dev libgl1-mesa-dev libglu1-mesa-dev libprotobuf-dev protobuf-compiler libode-dev libboost-all-dev g++ libeigen3-dev libdc1394-22 libdc1394-22-dev libv4l-0 zlib1g-dev libgtkmm-2.4-dev libopencv-dev freeglut3-dev jq || echo "Failed to install some packages"

            # if you're using ubuntu, you don't need to build ODE from source. Lucky you!
            ;;
        "arch" )
            # update
            sudo pacman -Syyu

            # install most of required packages for Robocup-SSL official tools (without Autoref)
            sudo pacman -Sy git gcc qt4 eigen protobuf libdc1394 cmake v4l-utils jsoncpp mesa glu freeglut ode gtkmm zlib base-devel boost clang ninja libyaml jq --needed || echo "Failed to install some packages"
            ;;
        * )
            echo "Not supported.";
            exit
            ;;
    esac
    
    # install "vartypes" that required by grSim
    git clone https://github.com/szi/vartypes.git || echo "Failed to clone vartypes"
    cd vartypes
    mkdir build && cd "$_"
    cmake .. && make || echo "Failed to build vartypes"
    sudo make install || echo "Failed to install vartypes"

    cd ../../
    sudo rm -r "$path_tmp"

}

function build_ssl_tools() {
    echo "Download and build RoboCup-SSL Tools"
    echo "grSim , ssl-vision , ssl-logtools , ssl-game-controller , ssl-vision-client"
    echo ""
    echo "Where do you want to place these application?"
    echo "(if you're a beginner, just press Enter)"
    echo -n "[default:/home/$USER/Documents/robocup/tools] >"
    while :
    do
    read -r -t 60 SSL_DIR
    case $SSL_DIR in
        # if typed so it seems to be not problem, but can't do "git clone"
        "home/" | "home" | "/home" | "/home/" )
            echo "You Don't have permission to access. Please use /home/<username>/ or just type Enter.";;
        # other case
        * )
            # nothing typed
            if test -z "$SSL_DIR"
            then
                mkdir -p /home/"$USER"/Documents/robocup/tools && cd "$_" && break
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

    # grsim
    cd grSim && mkdir build && cd "$_"
    cmake .. && make || echo "Failed to build grSim"

    # ssl-vision/graphicalClient
    cd ../../ssl-vision
    make || echo "Failed to build ssl-vision"

    # ssl-logtools
    cd ../ssl-logtools && mkdir build && cd "$_"
    cmake .. && make || echo "Failed to build ssl-logtools"

    # new ssl client (ssl-game-controller and so on)
    cd ../../
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

    read -r -t 60 ins_tools
    case "$ins_tools" in
        "" | "y" | "Y" | "yes" | "Yes" | "YES" )
            case "$DISTRIBU" in
                "fedora" )
                    sudo dnf -y install htop wireshark strace ltrace vim
                    ;;
                "ubuntu" )
                    sudo apt-get -y install htop wireshark strace ltrace vim
                    ;;
                "arch" )
                    sudo pacman -Sy htop wireshark-cli strace ltrace vim
                    ;;
                * )
                    echo "Not supported.";
                    exit
                ;;
            esac
            firefox -url "https://qiita.com/mfujimori/items/9fd41bcd8d1ce9170301"
            ;;
        * )
            echo "Didn't install these tools."
            ;;
    esac
}


# Script start from here
echo "This installer will setup the tools for RoboCup-SSL in your computer."

install_libraries || exit
build_ssl_tools || exit
install_dev_tools

echo ""
echo "Done."
