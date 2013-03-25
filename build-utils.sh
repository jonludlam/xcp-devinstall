#!/usr/bin/env bash

BUILD_DEST=~

function _install {
    sudo yum install -y $@
}

function _tools_install {
    _install make gcc wget git
}

function opam_config_env {
    eval `opam config env`
}

function ocaml_install {
    if [ `which ocaml` ]
    then
        echo "ocaml already installed"
        return
    fi

    _install gdbm-devel ncurses-devel rpm-build

    ocaml_repo="https://nazar.karan.org/results/misc/ocaml/20130319164433/4.00.1-2.el6.x86_64/"
    rpm_suffix="-4.00.1-2.el6.centos.alt.x86_64.rpm"
    rpm_prefixes="ocaml% ocaml-camlp4% ocaml-camlp4-devel% ocaml-compiler-libs% ocaml-debuginfo% ocaml-docs% ocaml-ocamldoc% ocaml-runtime% ocaml-source%"
    rpms=$(echo $rpm_prefixes | sed "s/%/${rpm_suffix}/g")
    for rpm_name in $rpms
    do
        if [ -a ${rpm_name} ]
        then
            echo "Skipping download of ${rpm_name}"
        else
            wget ${ocaml_repo}${rpm_name}
        fi
    done

    rpm -i --replacepkgs $rpms
}

function opam_build {
    cd $BUILD_DEST

    if [ `which opam` ]
    then
        echo "opam already installed"
        return
    fi

    _tools_install
    ocaml_install
    
    if [ -a opam-latest ]
    then
        echo "Skipping download of Opam"
    else
        wget https://github.com/OCamlPro/opam/archive/latest.tar.gz -O opam-latest.tgz
        tar -xf opam-latest.tgz
        rm -rf opam-latest.tgz
    fi

    cd opam-latest
    ./configure
    
    make clean
    make uninstall
    rm -rf ~/.opam

    make
    make install

    opam init -y
    opam_config_env
    echo 'eval `opam config env`' >> ~/.bash_profile
}

function xapi_deps_install {
    _install xen-devel libuuid-devel time pam-devel tk-devel libvirt-devel zlib-devel autoconf automake

    wget http://a94cd2de16980073c274-9e5915cce229bfd373f03bf01a9a7c85.r57.cf3.rackcdn.com/vncterm-1.6.10-251.x86_64.rpm
    rpm -i --replacepkgs vncterm-1.6.10-251.x86_64.rpm

    wget http://a94cd2de16980073c274-9e5915cce229bfd373f03bf01a9a7c85.r57.cf3.rackcdn.com/eliloader -O /usr/bin/eliloader
    chmod +x /usr/bin/eliloader

    opam_config_env

    opam install -y ocamlfind omake

    opam remote -y add xen-dev git://github.com/xen-org/opam-repo-dev || true
    opam install -y xen-api-libs-transitional stdext nbd tapctl libvhd oclock cdrom netdev xenopsd
}

function xapi_configure {
    echo openvswitch >/etc/xensource/network.conf
}

function xapi_sm_build {
    cd $BUILD_DEST

    _install swig python-devel

    git clone https://github.com/JohnGarbutt/xcp-storage-managers.git
    cd xcp-storage-managers

    export DESTDIR=/
    export PYTHON_INCLUDE=/usr/include/python2.6/
    make
}

function xapi_build {
    cd $BUILD_DEST

    if [ `which xe` ]
    then
        echo "xen-api already installed"
        return
    fi

    xapi_deps_install

    if [ -a xen-api ]
    then
        echo "Skipping download of xen-api"
        cd xen-api
    else
        git clone https://github.com/JohnGarbutt/xen-api.git
        cd xen-api
        git checkout centos64
    fi

    make clean
    make

    set DEST_DIR=/
    make install

    xapi_configure
    xapi_sm_build
}


function ovs_build {
    cd $BUILD_DEST

    if [ `which ovs-vsctl` ]
    then
        echo "ovs already installed"
        return
    fi

    _install openssl-devel

    # HACK see: http://openvswitch.org/pipermail/discuss/2012-August/008064.html
    cp /usr/share/aclocal/pkg.m4 /usr/local/share/aclocal-1.13/

    if [ -a openvswitch-1.4.5 ]
    then
        echo "Skipping download of ovs"
    else
        wget http://openvswitch.org/releases/openvswitch-1.4.5.tar.gz
        tar -xf openvswitch-1.4.5.tar.gz
    fi

    cd openvswitch-1.4.5
    ./boot.sh
    ./configure
    make

    prefix=/usr
    make install
}
