#!/bin/bash
installPip()
{
    if pip -V > /dev/null 2>&1; then
        echo 'python-pip has been installed.'
    else
        if command -v apt-get > /dev/null 2>&1; then
            apt-get -y install python-pip
        elif command -v yum > /dev/null 2>&1; then
            yum -y install epel-release
            yum -y install python-pip
        else
            echo 'Error: Dont find apt-get or yum.'
        fi
    fi
}
installPip