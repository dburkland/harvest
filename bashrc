# .bashrc
# Filename:             .bashrc
# By:                   Dan Burkland
# Date:                 2015-12-23
# Purpose:              The purpose of this bashrc file is to trigger the automated configuration
#			once a container has been created based on the "dburkland/harvest" Docker image.
#			Docker image.

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

export LANG="en_US.UTF-8"
#PROXY_PLACEHOLDER1

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi
