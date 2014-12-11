# Copyright 2014 Cloudbase Solutions S.R.L. (http://cloudbase.it)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# Use it at your own peril and, quite frankly, it probably won’t work for 
# you :).  But you may be desperate enough to try it.
#
# See the License for the specific language governing permissions and
# limitations under the License.

# functions.sh - Common functions used by lis-tempest-ci scripts.
#
# This file is sorted alphabetically within the function groups.
#
# - Config Functions
# - Control Functions
# - Distro Functions
# - Git Functions
# - OpenStack Functions
# - Package Functions
# - Process Functions
# - Python Functions
# - Service Functions
# - System Functions
#
# The following variables are assumed to be defined by certain functions:
#
# - ``GIT_DEPTH``
# - ``ENABLED_SERVICES``
# - ``ERROR_ON_CLONE``
# - ``FILES``
# - ``OFFLINE``
# - ``PIP_DOWNLOAD_CACHE``
# - ``RECLONE``
# - ``REQUIREMENTS_DIR``
# - ``STACK_USER``
# - ``TRACK_DEPENDS``
# - ``UNDO_REQUIREMENTS``
# - ``http_proxy``, ``https_proxy``, ``no_proxy``
#

# Save trace setting
XTRACE=$(set +o | grep xtrace)
set +o xtrace

# Global Config Variables
# declare -A GITREPO
# declare -A GITBRANCH
# declare -A GITDIR


# Config Functions
# ================

# Append a new option in an ini file without replacing the old value
# iniadd config-file section option value1 value2 value3 ...
function iniadd {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3
    shift 3

    local values="$(iniget_multiline $file $section $option) $@"
    iniset_multiline $file $section $option $values
    $xtrace
}

# Comment an option in an INI file
# inicomment config-file section option
function inicomment {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3

    sed -i -e "/^\[$section\]/,/^\[.*\]/ s|^\($option[ \t]*=.*$\)|#\1|" "$file"
    $xtrace
}

# Get an option from an INI file
# iniget config-file section option
function iniget {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3
    local line

    line=$(sed -ne "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ p; }" "$file")
    echo ${line#*=}
    $xtrace
}

# Get a multiple line option from an INI file
# iniget_multiline config-file section option
function iniget_multiline {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3
    local values

    values=$(sed -ne "/^\[$section\]/,/^\[.*\]/ { s/^$option[ \t]*=[ \t]*//gp; }" "$file")
    echo ${values}
    $xtrace
}

# Determinate is the given option present in the INI file
# ini_has_option config-file section option
function ini_has_option {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3
    local line

    line=$(sed -ne "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ p; }" "$file")
    $xtrace
    [ -n "$line" ]
}

# Add another config line for a multi-line option.
# It's normally called after iniset of the same option and assumes
# that the section already exists.
#
# Note that iniset_multiline requires all the 'lines' to be supplied
# in the argument list. Doing that will cause incorrect configuration
# if spaces are used in the config values.
#
# iniadd_literal config-file section option value
function iniadd_literal {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3
    local value=$4

    [[ -z $section || -z $option ]] && return

    # Add it
    sed -i -e "/^\[$section\]/ a\\
$option = $value
" "$file"

    $xtrace
}

# Set an option in an INI file
# iniset config-file section option value
function iniset {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3
    local value=$4

    [[ -z $section || -z $option ]] && return

    if ! grep -q "^\[$section\]" "$file" 2>/dev/null; then
        # Add section at the end
        echo -e "\n[$section]" >>"$file"
    fi
    if ! ini_has_option "$file" "$section" "$option"; then
        # Add it
        sed -i -e "/^\[$section\]/ a\\
$option = $value
" "$file"
    else
        local sep=$(echo -ne "\x01")
        # Replace it
        sed -i -e '/^\['${section}'\]/,/^\[.*\]/ s'${sep}'^\('${option}'[ \t]*=[ \t]*\).*$'${sep}'\1'"${value}"${sep} "$file"
    fi
    $xtrace
}

# Set a multiple line option in an INI file
# iniset_multiline config-file section option value1 value2 valu3 ...
function iniset_multiline {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3

    shift 3
    local values
    for v in $@; do
        # The later sed command inserts each new value in the line next to
        # the section identifier, which causes the values to be inserted in
        # the reverse order. Do a reverse here to keep the original order.
        values="$v ${values}"
    done
    if ! grep -q "^\[$section\]" "$file"; then
        # Add section at the end
        echo -e "\n[$section]" >>"$file"
    else
        # Remove old values
        sed -i -e "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ d; }" "$file"
    fi
    # Add new ones
    for v in $values; do
        sed -i -e "/^\[$section\]/ a\\
$option = $v
" "$file"
    done
    $xtrace
}

# Uncomment an option in an INI file
# iniuncomment config-file section option
function iniuncomment {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local file=$1
    local section=$2
    local option=$3
    sed -i -e "/^\[$section\]/,/^\[.*\]/ s|[^ \t]*#[ \t]*\($option[ \t]*=.*$\)|\1|" "$file"
    $xtrace
}

# Normalize config values to True or False
# Accepts as False: 0 no No NO false False FALSE
# Accepts as True: 1 yes Yes YES true True TRUE
# VAR=$(trueorfalse default-value test-value)
function trueorfalse {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local default=$1
    local testval=$2

    [[ -z "$testval" ]] && { echo "$default"; return; }
    [[ "0 no No NO false False FALSE" =~ "$testval" ]] && { echo "False"; return; }
    [[ "1 yes Yes YES true True TRUE" =~ "$testval" ]] && { echo "True"; return; }
    echo "$default"
    $xtrace
}


# Control Functions
# =================

# Prints backtrace info
# filename:lineno:function
# backtrace level
function backtrace {
    local level=$1
    local deep=$((${#BASH_SOURCE[@]} - 1))
    echo "[Call Trace]"
    while [ $level -le $deep ]; do
        echo "${BASH_SOURCE[$deep]}:${BASH_LINENO[$deep-1]}:${FUNCNAME[$deep-1]}"
        deep=$((deep - 1))
    done
}

# Prints line number and "message" then exits
# die $LINENO "message"
function die {
    local exitcode=$?
    set +o xtrace
    local line=$1; shift
    if [ $exitcode == 0 ]; then
        exitcode=1
    fi
    backtrace 2
    err $line "$*"
    # Give buffers a second to flush
    sleep 1
    exit $exitcode
}

# Checks an environment variable is not set or has length 0 OR if the
# exit code is non-zero and prints "message" and exits
# NOTE: env-var is the variable name without a '$'
# die_if_not_set $LINENO env-var "message"
function die_if_not_set {
    local exitcode=$?
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local line=$1; shift
    local evar=$1; shift
    if ! is_set $evar || [ $exitcode != 0 ]; then
        die $line "$*"
    fi
    $xtrace
}

# Prints line number and "message" in error format
# err $LINENO "message"
function err {
    local exitcode=$?
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local msg="[ERROR] ${BASH_SOURCE[2]}:$1 $2"
    echo $msg 1>&2;
    if [[ -n ${SCREEN_LOGDIR} ]]; then
        echo $msg >> "${SCREEN_LOGDIR}/error.log"
    fi
    $xtrace
    return $exitcode
}

# Checks an environment variable is not set or has length 0 OR if the
# exit code is non-zero and prints "message"
# NOTE: env-var is the variable name without a '$'
# err_if_not_set $LINENO env-var "message"
function err_if_not_set {
    local exitcode=$?
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local line=$1; shift
    local evar=$1; shift
    if ! is_set $evar || [ $exitcode != 0 ]; then
        err $line "$*"
    fi
    $xtrace
    return $exitcode
}

# Exit after outputting a message about the distribution not being supported.
# exit_distro_not_supported [optional-string-telling-what-is-missing]
function exit_distro_not_supported {
    if [[ -z "$DISTRO" ]]; then
        GetDistro
    fi

    if [ $# -gt 0 ]; then
        die $LINENO "Support for $DISTRO is incomplete: no support for $@"
    else
        die $LINENO "Support for $DISTRO is incomplete."
    fi
}

# Test if the named environment variable is set and not zero length
# is_set env-var
function is_set {
    local var=\$"$1"
    eval "[ -n \"$var\" ]" # For ex.: sh -c "[ -n \"$var\" ]" would be better, but several exercises depends on this
}

# Prints line number and "message" in warning format
# warn $LINENO "message"
function warn {
    local exitcode=$?
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local msg="[WARNING] ${BASH_SOURCE[2]}:$1 $2"
    echo $msg 1>&2;
    if [[ -n ${SCREEN_LOGDIR} ]]; then
        echo $msg >> "${SCREEN_LOGDIR}/error.log"
    fi
    $xtrace
    return $exitcode
}


# Distro Functions
# ================

# Determine OS Vendor, Release and Update
# Tested with OS/X, Ubuntu, RedHat, CentOS, Fedora
# Returns results in global variables:
# ``os_VENDOR`` - vendor name: ``Ubuntu``, ``Fedora``, etc
# ``os_RELEASE`` - major release: ``14.04`` (Ubuntu), ``20`` (Fedora)
# ``os_UPDATE`` - update: ex. the ``5`` in ``RHEL6.5``
# ``os_PACKAGE`` - package type: ``deb`` or ``rpm``
# ``os_CODENAME`` - vendor's codename for release: ``snow leopard``, ``trusty``
declare os_VENDOR os_RELEASE os_UPDATE os_PACKAGE os_CODENAME

# GetOSVersion
function GetOSVersion {

    # Figure out which vendor we are
    if [[ -x "`which sw_vers 2>/dev/null`" ]]; then
        # OS/X
        os_VENDOR=`sw_vers -productName`
        os_RELEASE=`sw_vers -productVersion`
        os_UPDATE=${os_RELEASE##*.}
        os_RELEASE=${os_RELEASE%.*}
        os_PACKAGE=""
        if [[ "$os_RELEASE" =~ "10.7" ]]; then
            os_CODENAME="lion"
        elif [[ "$os_RELEASE" =~ "10.6" ]]; then
            os_CODENAME="snow leopard"
        elif [[ "$os_RELEASE" =~ "10.5" ]]; then
            os_CODENAME="leopard"
        elif [[ "$os_RELEASE" =~ "10.4" ]]; then
            os_CODENAME="tiger"
        elif [[ "$os_RELEASE" =~ "10.3" ]]; then
            os_CODENAME="panther"
        else
            os_CODENAME=""
        fi
    elif [[ -x $(which lsb_release 2>/dev/null) ]]; then
        os_VENDOR=$(lsb_release -i -s)
        os_RELEASE=$(lsb_release -r -s)
        os_UPDATE=""
        os_PACKAGE="rpm"
        if [[ "Debian,Ubuntu,LinuxMint" =~ $os_VENDOR ]]; then
            os_PACKAGE="deb"
        elif [[ "SUSE LINUX" =~ $os_VENDOR ]]; then
            lsb_release -d -s | grep -q openSUSE
            if [[ $? -eq 0 ]]; then
                os_VENDOR="openSUSE"
            fi
        elif [[ $os_VENDOR == "openSUSE project" ]]; then
            os_VENDOR="openSUSE"
        elif [[ $os_VENDOR =~ Red.*Hat ]]; then
            os_VENDOR="Red Hat"
        fi
        os_CODENAME=$(lsb_release -c -s)
    elif [[ -r /etc/redhat-release ]]; then
        # Red Hat Enterprise Linux Server release 5.5 (Tikanga)
        # Red Hat Enterprise Linux Server release 7.0 Beta (Maipo)
        # CentOS release 5.5 (Final)
        # CentOS Linux release 6.0 (Final)
        # Fedora release 16 (Verne)
        # XenServer release 6.2.0-70446c (xenenterprise)
        os_CODENAME=""
        for r in "Red Hat" CentOS Fedora XenServer; do
            os_VENDOR=$r
            if [[ -n "`grep \"$r\" /etc/redhat-release`" ]]; then
                ver=`sed -e 's/^.* \([0-9].*\) (\(.*\)).*$/\1\|\2/' /etc/redhat-release`
                os_CODENAME=${ver#*|}
                os_RELEASE=${ver%|*}
                os_UPDATE=${os_RELEASE##*.}
                os_RELEASE=${os_RELEASE%.*}
                break
            fi
            os_VENDOR=""
        done
        os_PACKAGE="rpm"
    elif [[ -r /etc/SuSE-release ]]; then
        for r in openSUSE "SUSE Linux"; do
            if [[ "$r" = "SUSE Linux" ]]; then
                os_VENDOR="SUSE LINUX"
            else
                os_VENDOR=$r
            fi

            if [[ -n "`grep \"$r\" /etc/SuSE-release`" ]]; then
                os_CODENAME=`grep "CODENAME = " /etc/SuSE-release | sed 's:.* = ::g'`
                os_RELEASE=`grep "VERSION = " /etc/SuSE-release | sed 's:.* = ::g'`
                os_UPDATE=`grep "PATCHLEVEL = " /etc/SuSE-release | sed 's:.* = ::g'`
                break
            fi
            os_VENDOR=""
        done
        os_PACKAGE="rpm"
    # If lsb_release is not installed, we should be able to detect Debian OS
    elif [[ -f /etc/debian_version ]] && [[ $(cat /proc/version) =~ "Debian" ]]; then
        os_VENDOR="Debian"
        os_PACKAGE="deb"
        os_CODENAME=$(awk '/VERSION=/' /etc/os-release | sed 's/VERSION=//' | sed -r 's/\"|\(|\)//g' | awk '{print $2}')
        os_RELEASE=$(awk '/VERSION_ID=/' /etc/os-release | sed 's/VERSION_ID=//' | sed 's/\"//g')
    fi
    export os_VENDOR os_RELEASE os_UPDATE os_PACKAGE os_CODENAME
}

# Translate the OS version values into common nomenclature
# Sets global ``DISTRO`` from the ``os_*`` values
declare DISTRO

function GetDistro {
    GetOSVersion
    if [[ "$os_VENDOR" =~ (Ubuntu) || "$os_VENDOR" =~ (Debian) ]]; then
        # 'Everyone' refers to Ubuntu / Debian releases by the code name adjective
        DISTRO=$os_CODENAME
    elif [[ "$os_VENDOR" =~ (Fedora) ]]; then
        # For Fedora, just use 'f' and the release
        DISTRO="f$os_RELEASE"
    elif [[ "$os_VENDOR" =~ (openSUSE) ]]; then
        DISTRO="opensuse-$os_RELEASE"
    elif [[ "$os_VENDOR" =~ (SUSE LINUX) ]]; then
        # For SLE, also use the service pack
        if [[ -z "$os_UPDATE" ]]; then
            DISTRO="sle${os_RELEASE}"
        else
            DISTRO="sle${os_RELEASE}sp${os_UPDATE}"
        fi
    elif [[ "$os_VENDOR" =~ (Red Hat) || \
        "$os_VENDOR" =~ (CentOS) || \
        "$os_VENDOR" =~ (OracleServer) ]]; then
        # Drop the . release as we assume it's compatible
        DISTRO="rhel${os_RELEASE::1}"
    elif [[ "$os_VENDOR" =~ (XenServer) ]]; then
        DISTRO="xs$os_RELEASE"
    else
        # Catch-all for now is Vendor + Release + Update
        DISTRO="$os_VENDOR-$os_RELEASE.$os_UPDATE"
    fi
    export DISTRO
}

# Utility function for checking machine architecture
# is_arch arch-type
function is_arch {
    [[ "$(uname -m)" == "$1" ]]
}

# Quick check for a rackspace host; n.b. rackspace provided images
# have these Xen tools installed but a custom image may not.
function is_rackspace {
    [ -f /usr/bin/xenstore-ls ] && \
        sudo /usr/bin/xenstore-ls vm-data | grep -q "Rackspace"
}

# Determine if current distribution is a Fedora-based distribution
# (Fedora, RHEL, CentOS, etc).
# is_fedora
function is_fedora {
    if [[ -z "$os_VENDOR" ]]; then
        GetOSVersion
    fi

    [ "$os_VENDOR" = "Fedora" ] || [ "$os_VENDOR" = "Red Hat" ] || \
        [ "$os_VENDOR" = "CentOS" ] || [ "$os_VENDOR" = "OracleServer" ]
}


# Determine if current distribution is a SUSE-based distribution
# (openSUSE, SLE).
# is_suse
function is_suse {
    if [[ -z "$os_VENDOR" ]]; then
        GetOSVersion
    fi

    [ "$os_VENDOR" = "openSUSE" ] || [ "$os_VENDOR" = "SUSE LINUX" ]
}


# Determine if current distribution is an Ubuntu-based distribution
# It will also detect non-Ubuntu but Debian-based distros
# is_ubuntu
function is_ubuntu {
    if [[ -z "$os_PACKAGE" ]]; then
        GetOSVersion
    fi
    [ "$os_PACKAGE" = "deb" ]
}


# Git Functions
# =============

# Returns openstack release name for a given branch name
# ``get_release_name_from_branch branch-name``
function get_release_name_from_branch {
    local branch=$1
    if [[ $branch =~ "stable/" || $branch =~ "proposed/" ]]; then
        echo ${branch#*/}
    else
        echo "master"
    fi
}

# git clone only if directory doesn't exist already.  Since ``DEST`` might not
# be owned by the installation user, we create the directory and change the
# ownership to the proper user.
# Set global ``RECLONE=yes`` to simulate a clone when dest-dir exists
# Set global ``ERROR_ON_CLONE=True`` to abort execution with an error if the git repo
# does not exist (default is False, meaning the repo will be cloned).
# Set global ``GIT_DEPTH=<number>`` to limit the history depth of the git clone
# Uses globals ``ERROR_ON_CLONE``, ``OFFLINE``, ``RECLONE``, ``GIT_DEPTH``
# git_clone remote dest-dir branch
function git_clone {
    local git_remote=$1
    local git_dest=$2
    local git_ref=$3
    local orig_dir=$(pwd)
    local git_clone_flags=""

    RECLONE=$(trueorfalse False $RECLONE)

    if [[ -n "${GIT_DEPTH}" ]]; then
        git_clone_flags="$git_clone_flags --depth $GIT_DEPTH"
    fi

    if [[ "$OFFLINE" = "True" ]]; then
        echo "Running in offline mode, clones already exist"
        # print out the results so we know what change was used in the logs
        cd $git_dest
        git show --oneline | head -1
        cd $orig_dir
        return
    fi

    if echo $git_ref | egrep -q "^refs"; then
        # If our branch name is a gerrit style refs/changes/...
        if [[ ! -d $git_dest ]]; then
            [[ "$ERROR_ON_CLONE" = "True" ]] && \
                die $LINENO "Cloning not allowed in this configuration"
            git_timed clone $git_clone_flags $git_remote $git_dest
        fi
        cd $git_dest
        git_timed fetch $git_remote $git_ref && git checkout FETCH_HEAD
    else
        # do a full clone only if the directory doesn't exist
        if [[ ! -d $git_dest ]]; then
            [[ "$ERROR_ON_CLONE" = "True" ]] && \
                die $LINENO "Cloning not allowed in this configuration"
            git_timed clone $git_clone_flags $git_remote $git_dest
            cd $git_dest
            # This checkout syntax works for both branches and tags
            git checkout $git_ref
        elif [[ "$RECLONE" = "True" ]]; then
            # if it does exist then simulate what clone does if asked to RECLONE
            cd $git_dest
            # set the url to pull from and fetch
            git remote set-url origin $git_remote
            git_timed fetch origin
            # remove the existing ignored files (like pyc) as they cause breakage
            # (due to the py files having older timestamps than our pyc, so python
            # thinks the pyc files are correct using them)
            find $git_dest -name '*.pyc' -delete

            # handle git_ref accordingly to type (tag, branch)
            if [[ -n "`git show-ref refs/tags/$git_ref`" ]]; then
                git_update_tag $git_ref
            elif [[ -n "`git show-ref refs/heads/$git_ref`" ]]; then
                git_update_branch $git_ref
            elif [[ -n "`git show-ref refs/remotes/origin/$git_ref`" ]]; then
                git_update_remote_branch $git_ref
            else
                die $LINENO "$git_ref is neither branch nor tag"
            fi

        fi
    fi

    # print out the results so we know what change was used in the logs
    cd $git_dest
    git show --oneline | head -1
    cd $orig_dir
}

# A variation on git clone that lets us specify a project by it's
# actual name, like oslo.config. This is exceptionally useful in the
# library installation case
function git_clone_by_name {
    local name=$1
    local repo=${GITREPO[$name]}
    local dir=${GITDIR[$name]}
    local branch=${GITBRANCH[$name]}
    git_clone $repo $dir $branch
}


# git can sometimes get itself infinitely stuck with transient network
# errors or other issues with the remote end.  This wraps git in a
# timeout/retry loop and is intended to watch over non-local git
# processes that might hang.  GIT_TIMEOUT, if set, is passed directly
# to timeout(1); otherwise the default value of 0 maintains the status
# quo of waiting forever.
# usage: git_timed <git-command>
function git_timed {
    local count=0
    local timeout=0

    if [[ -n "${GIT_TIMEOUT}" ]]; then
        timeout=${GIT_TIMEOUT}
    fi

    until timeout -s SIGINT ${timeout} git "$@"; do
        # 124 is timeout(1)'s special return code when it reached the
        # timeout; otherwise assume fatal failure
        if [[ $? -ne 124 ]]; then
            die $LINENO "git call failed: [git $@]"
        fi

        count=$(($count + 1))
        warn "timeout ${count} for git call: [git $@]"
        if [ $count -eq 3 ]; then
            die $LINENO "Maximum of 3 git retries reached"
        fi
        sleep 5
    done
}

# git update using reference as a branch.
# git_update_branch ref
function git_update_branch {
    local git_branch=$1

    git checkout -f origin/$git_branch
    # a local branch might not exist
    git branch -D $git_branch || true
    git checkout -b $git_branch
}

# git update using reference as a branch.
# git_update_remote_branch ref
function git_update_remote_branch {
    local git_branch=$1

    git checkout -b $git_branch -t origin/$git_branch
}

# git update using reference as a tag. Be careful editing source at that repo
# as working copy will be in a detached mode
# git_update_tag ref
function git_update_tag {
    local git_tag=$1

    git tag -d $git_tag
    # fetching given tag only
    git_timed fetch origin tag $git_tag
    git checkout -f $git_tag
}


# OpenStack Functions
# ===================

# Get flavour by metadata
# get_flavour_by_metadata metadata
function get_flavour_by_metadata {
    local metadata=$1

    [[ -z $metadata ]] && return
    
    local flavour=$(nova flavor-list --extra-specs | grep "$metadata" | awk 'FNR == 1 {print $2}')
    if [[ -z $flavour ]]; then
        echo "No valid flavor found"
        exit
    fi
    return $flavour
}

# Check if image exists and return id
# get_imageid imagename
function get_imageid {
    local imagename=$1

    [[ -z $imagename ]] && return
    
    local checkimage=$(nova image-list | grep "$imagename")
    if [[ -z $checkimage ]]; then
        echo "ERROR: \"$imagename\" was not found in glance."
        exit
    fi

    local imageid=$(echo $checkimage | awk 'FNR == 1 {print $2}')
    if [[ -z $imageid ]]; then
        echo "ERROR: Coud not return image id for \"$imagename\"."
        exit
    fi
    echo $imageid
}

# Get ssh user from image metadata
# get_ssh_user_from_image imageid
function get_ssh_user_from_image {
    local imageid=$1

    [[ -z $imageid ]] && return
    
    local ssh_user=$(glance image-show $imageid | grep ssh_user | awk 'FNR == 1 {print $5}')
    
    if [[ -z $ssh_user ]]; then
        echo "INFO: No ssh user metadata found. Continuing with default username (root)."
        return $DEFAULT_SSH_USER
    fi
    return "$ssh_user"
}

# Get the default value for HOST_IP
# get_default_host_ip fixed_range floating_range host_ip_iface host_ip
function get_default_host_ip {
    local fixed_range=$1
    local floating_range=$2
    local host_ip_iface=$3
    local host_ip=$4

    # Find the interface used for the default route
    host_ip_iface=${host_ip_iface:-$(ip route | sed -n '/^default/{ s/.*dev \(\w\+\)\s\+.*/\1/; p; }' | head -1)}
    # Search for an IP unless an explicit is set by ``HOST_IP`` environment variable'
    if [ -z "$host_ip" -o "$host_ip" == "dhcp" ]; then
        host_ip=""
        local host_ips=$(LC_ALL=C ip -f inet addr show ${host_ip_iface} | awk '/inet/ {split($2,parts,"/");  print parts[1]}')
        local ip
        for ip in $host_ips; do
            # Attempt to filter out IP addresses that are part of the fixed and
            # floating range. Note that this method only works if the ``netaddr``
            # python library is installed. If it is not installed, an error
            # will be printed and the first IP from the interface will be used.
            # If that is not correct set ``HOST_IP`` in ``localrc`` to the correct
            # address.
            if ! (address_in_net $ip $fixed_range || address_in_net $ip $floating_range); then
                host_ip=$ip
                break;
            fi
        done
    fi
    echo $host_ip
}

# Generates hex string from ``size`` byte of pseudo random data
# generate_hex_string size
function generate_hex_string {
    local size=$1
    hexdump -n "$size" -v -e '/1 "%02x"' /dev/urandom
}

# Grab a numbered field from python prettytable output
# Fields are numbered starting with 1
# Reverse syntax is supported: -1 is the last field, -2 is second to last, etc.
# get_field field-number
function get_field {
    local data field
    while read data; do
        if [ "$1" -lt 0 ]; then
            field="(\$(NF$1))"
        else
            field="\$$(($1 + 1))"
        fi
        echo "$data" | awk -F'[ \t]*\\|[ \t]*' "{print $field}"
    done
}

# Add a policy to a policy.json file
# Do nothing if the policy already exists
# ``policy_add policy_file policy_name policy_permissions``
function policy_add {
    local policy_file=$1
    local policy_name=$2
    local policy_perm=$3

    if grep -q ${policy_name} ${policy_file}; then
        echo "Policy ${policy_name} already exists in ${policy_file}"
        return
    fi

    # Add a terminating comma to policy lines without one
    # Remove the closing '}' and all lines following to the end-of-file
    local tmpfile=$(mktemp)
    uniq ${policy_file} | sed -e '
        s/]$/],/
        /^[}]/,$d
    ' > ${tmpfile}

    # Append policy and closing brace
    echo "    \"${policy_name}\": ${policy_perm}" >>${tmpfile}
    echo "}" >>${tmpfile}

    mv ${tmpfile} ${policy_file}
}

# Gets or creates a domain
# Usage: get_or_create_domain <name> <description>
function get_or_create_domain {
    local os_url="$KEYSTONE_SERVICE_URI/v3"
    # Gets domain id
    local domain_id=$(
        # Gets domain id
        openstack --os-token=$OS_TOKEN --os-url=$os_url \
            --os-identity-api-version=3 domain show $1 \
            -f value -c id 2>/dev/null ||
        # Creates new domain
        openstack --os-token=$OS_TOKEN --os-url=$os_url \
            --os-identity-api-version=3 domain create $1 \
            --description "$2" \
            -f value -c id
    )
    echo $domain_id
}

# Gets or creates user
# Usage: get_or_create_user <username> <password> <project> [<email> [<domain>]]
function get_or_create_user {
    if [[ ! -z "$4" ]]; then
        local email="--email=$4"
    else
        local email=""
    fi
    local os_cmd="openstack"
    local domain=""
    if [[ ! -z "$5" ]]; then
        domain="--domain=$5"
        os_cmd="$os_cmd --os-url=$KEYSTONE_SERVICE_URI/v3 --os-identity-api-version=3"
    fi
    # Gets user id
    local user_id=$(
        # Creates new user with --or-show
        $os_cmd user create \
            $1 \
            --password "$2" \
            --project $3 \
            $email \
            $domain \
            --or-show \
            -f value -c id
    )
    echo $user_id
}

# Gets or creates project
# Usage: get_or_create_project <name> [<domain>]
function get_or_create_project {
    # Gets project id
    local os_cmd="openstack"
    local domain=""
    if [[ ! -z "$2" ]]; then
        domain="--domain=$2"
        os_cmd="$os_cmd --os-url=$KEYSTONE_SERVICE_URI/v3 --os-identity-api-version=3"
    fi
    local project_id=$(
        # Creates new project with --or-show
        $os_cmd project create $1 $domain --or-show -f value -c id
    )
    echo $project_id
}

# Gets or creates role
# Usage: get_or_create_role <name>
function get_or_create_role {
    local role_id=$(
        # Creates role with --or-show
        openstack role create $1 --or-show -f value -c id
    )
    echo $role_id
}

# Gets or adds user role
# Usage: get_or_add_user_role <role> <user> <project>
function get_or_add_user_role {
    # Gets user role id
    local user_role_id=$(openstack user role list \
        $2 \
        --project $3 \
        --column "ID" \
        --column "Name" \
        | grep " $1 " | get_field 1)
    if [[ -z "$user_role_id" ]]; then
        # Adds role to user
        user_role_id=$(openstack role add \
            $1 \
            --user $2 \
            --project $3 \
            | grep " id " | get_field 2)
    fi
    echo $user_role_id
}

# Gets or creates service
# Usage: get_or_create_service <name> <type> <description>
function get_or_create_service {
    # Gets service id
    local service_id=$(
        # Gets service id
        openstack service show $1 -f value -c id 2>/dev/null ||
        # Creates new service if not exists
        openstack service create \
            $1 \
            --type=$2 \
            --description="$3" \
            -f value -c id
    )
    echo $service_id
}

# Gets or creates endpoint
# Usage: get_or_create_endpoint <service> <region> <publicurl> <adminurl> <internalurl>
function get_or_create_endpoint {
    # Gets endpoint id
    local endpoint_id=$(openstack endpoint list \
        --column "ID" \
        --column "Region" \
        --column "Service Name" \
        | grep " $2 " \
        | grep " $1 " | get_field 1)
    if [[ -z "$endpoint_id" ]]; then
        # Creates new endpoint
        endpoint_id=$(openstack endpoint create \
            $1 \
            --region $2 \
            --publicurl $3 \
            --adminurl $4 \
            --internalurl $5 \
            | grep " id " | get_field 2)
    fi
    echo $endpoint_id
}


# Package Functions
# =================

# _get_package_dir
function _get_package_dir {
    local pkg_dir
    if is_ubuntu; then
        pkg_dir=$FILES/debs
    elif is_fedora; then
        pkg_dir=$FILES/rpms
    elif is_suse; then
        pkg_dir=$FILES/rpms-suse
    else
        exit_distro_not_supported "list of packages"
    fi
    echo "$pkg_dir"
}

# Wrapper for ``apt-get`` to set cache and proxy environment variables
# Uses globals ``OFFLINE``, ``*_proxy``
# apt_get operation package [package ...]
function apt_get {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace

    [[ "$OFFLINE" = "True" || -z "$@" ]] && return
    local sudo="sudo"
    [[ "$(id -u)" = "0" ]] && sudo="env"

    $xtrace
    $sudo DEBIAN_FRONTEND=noninteractive \
        http_proxy=$http_proxy https_proxy=$https_proxy \
        no_proxy=$no_proxy \
        apt-get --option "Dpkg::Options::=--force-confold" --assume-yes "$@"
}

# get_packages() collects a list of package names of any type from the
# prerequisite files in ``files/{debs|rpms}``.  The list is intended
# to be passed to a package installer such as apt or yum.
#
# Only packages required for the services in 1st argument will be
# included.  Two bits of metadata are recognized in the prerequisite files:
#
# - ``# NOPRIME`` defers installation to be performed later in `stack.sh`
# - ``# dist:DISTRO`` or ``dist:DISTRO1,DISTRO2`` limits the selection
#   of the package to the distros listed.  The distro names are case insensitive.
function get_packages {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local services=$@
    local package_dir=$(_get_package_dir)
    local file_to_parse
    local service

    INSTALL_TESTONLY_PACKAGES=$(trueorfalse False $INSTALL_TESTONLY_PACKAGES)

    if [[ -z "$package_dir" ]]; then
        echo "No package directory supplied"
        return 1
    fi
    if [[ -z "$DISTRO" ]]; then
        GetDistro
        echo "Found Distro $DISTRO"
    fi
    for service in ${services//,/ }; do
        # Allow individual services to specify dependencies
        if [[ -e ${package_dir}/${service} ]]; then
            file_to_parse="${file_to_parse} $service"
        fi
        # NOTE(sdague) n-api needs glance for now because that's where
        # glance client is
        if [[ $service == n-api ]]; then
            if [[ ! $file_to_parse =~ nova ]]; then
                file_to_parse="${file_to_parse} nova"
            fi
            if [[ ! $file_to_parse =~ glance ]]; then
                file_to_parse="${file_to_parse} glance"
            fi
        elif [[ $service == c-* ]]; then
            if [[ ! $file_to_parse =~ cinder ]]; then
                file_to_parse="${file_to_parse} cinder"
            fi
        elif [[ $service == ceilometer-* ]]; then
            if [[ ! $file_to_parse =~ ceilometer ]]; then
                file_to_parse="${file_to_parse} ceilometer"
            fi
        elif [[ $service == s-* ]]; then
            if [[ ! $file_to_parse =~ swift ]]; then
                file_to_parse="${file_to_parse} swift"
            fi
        elif [[ $service == n-* ]]; then
            if [[ ! $file_to_parse =~ nova ]]; then
                file_to_parse="${file_to_parse} nova"
            fi
        elif [[ $service == g-* ]]; then
            if [[ ! $file_to_parse =~ glance ]]; then
                file_to_parse="${file_to_parse} glance"
            fi
        elif [[ $service == key* ]]; then
            if [[ ! $file_to_parse =~ keystone ]]; then
                file_to_parse="${file_to_parse} keystone"
            fi
        elif [[ $service == q-* ]]; then
            if [[ ! $file_to_parse =~ neutron ]]; then
                file_to_parse="${file_to_parse} neutron"
            fi
        elif [[ $service == ir-* ]]; then
            if [[ ! $file_to_parse =~ ironic ]]; then
                file_to_parse="${file_to_parse} ironic"
            fi
        fi
    done

    for file in ${file_to_parse}; do
        local fname=${package_dir}/${file}
        local OIFS line package distros distro
        [[ -e $fname ]] || continue

        OIFS=$IFS
        IFS=$'\n'
        for line in $(<${fname}); do
            if [[ $line =~ "NOPRIME" ]]; then
                continue
            fi

            # Assume we want this package
            package=${line%#*}
            inst_pkg=1

            # Look for # dist:xxx in comment
            if [[ $line =~ (.*)#.*dist:([^ ]*) ]]; then
                # We are using BASH regexp matching feature.
                package=${BASH_REMATCH[1]}
                distros=${BASH_REMATCH[2]}
                # In bash ${VAR,,} will lowecase VAR
                # Look for a match in the distro list
                if [[ ! ${distros,,} =~ ${DISTRO,,} ]]; then
                    # If no match then skip this package
                    inst_pkg=0
                fi
            fi

            # Look for # testonly in comment
            if [[ $line =~ (.*)#.*testonly.* ]]; then
                package=${BASH_REMATCH[1]}
                # Are we installing test packages? (test for the default value)
                if [[ $INSTALL_TESTONLY_PACKAGES = "False" ]]; then
                    # If not installing test packages the skip this package
                    inst_pkg=0
                fi
            fi

            if [[ $inst_pkg = 1 ]]; then
                echo $package
            fi
        done
        IFS=$OIFS
    done
    $xtrace
}

# Distro-agnostic package installer
# Uses globals ``NO_UPDATE_REPOS``, ``REPOS_UPDATED``, ``RETRY_UPDATE``
# install_package package [package ...]
function update_package_repo {
    if [[ "$NO_UPDATE_REPOS" = "True" ]]; then
        return 0
    fi

    if is_ubuntu; then
        local xtrace=$(set +o | grep xtrace)
        set +o xtrace
        if [[ "$REPOS_UPDATED" != "True" || "$RETRY_UPDATE" = "True" ]]; then
            # if there are transient errors pulling the updates, that's fine.
            # It may be secondary repositories that we don't really care about.
            apt_get update  || /bin/true
            REPOS_UPDATED=True
        fi
        $xtrace
    fi
}

function real_install_package {
    if is_ubuntu; then
        apt_get install "$@"
    elif is_fedora; then
        yum_install "$@"
    elif is_suse; then
        zypper_install "$@"
    else
        exit_distro_not_supported "installing packages"
    fi
}

# Distro-agnostic package installer
# install_package package [package ...]
function install_package {
    update_package_repo
    real_install_package $@ || RETRY_UPDATE=True update_package_repo && real_install_package $@
}

# Distro-agnostic function to tell if a package is installed
# is_package_installed package [package ...]
function is_package_installed {
    if [[ -z "$@" ]]; then
        return 1
    fi

    if [[ -z "$os_PACKAGE" ]]; then
        GetOSVersion
    fi

    if [[ "$os_PACKAGE" = "deb" ]]; then
        dpkg -s "$@" > /dev/null 2> /dev/null
    elif [[ "$os_PACKAGE" = "rpm" ]]; then
        rpm --quiet -q "$@"
    else
        exit_distro_not_supported "finding if a package is installed"
    fi
}

# Distro-agnostic package uninstaller
# uninstall_package package [package ...]
function uninstall_package {
    if is_ubuntu; then
        apt_get purge "$@"
    elif is_fedora; then
        sudo yum remove -y "$@"
    elif is_suse; then
        sudo zypper rm "$@"
    else
        exit_distro_not_supported "uninstalling packages"
    fi
}

# Wrapper for ``yum`` to set proxy environment variables
# Uses globals ``OFFLINE``, ``*_proxy``
# yum_install package [package ...]
function yum_install {
    [[ "$OFFLINE" = "True" ]] && return
    local sudo="sudo"
    [[ "$(id -u)" = "0" ]] && sudo="env"

    # The manual check for missing packages is because yum -y assumes
    # missing packages are OK.  See
    # https://bugzilla.redhat.com/show_bug.cgi?id=965567
    $sudo http_proxy=$http_proxy https_proxy=$https_proxy \
        no_proxy=$no_proxy \
        yum install -y "$@" 2>&1 | \
        awk '
            BEGIN { fail=0 }
            /No package/ { fail=1 }
            { print }
            END { exit fail }' || \
                die $LINENO "Missing packages detected"

    # also ensure we catch a yum failure
    if [[ ${PIPESTATUS[0]} != 0 ]]; then
        die $LINENO "Yum install failure"
    fi
}

# zypper wrapper to set arguments correctly
# Uses globals ``OFFLINE``, ``*_proxy``
# zypper_install package [package ...]
function zypper_install {
    [[ "$OFFLINE" = "True" ]] && return
    local sudo="sudo"
    [[ "$(id -u)" = "0" ]] && sudo="env"
    $sudo http_proxy=$http_proxy https_proxy=$https_proxy \
        zypper --non-interactive install --auto-agree-with-licenses "$@"
}


# Process Functions
# =================

# _run_process() is designed to be backgrounded by run_process() to simulate a
# fork.  It includes the dirty work of closing extra filehandles and preparing log
# files to produce the same logs as screen_it().  The log filename is derived
# from the service name and global-and-now-misnamed ``SCREEN_LOGDIR``
# Uses globals ``CURRENT_LOG_TIME``, ``SCREEN_LOGDIR``, ``SCREEN_NAME``, ``SERVICE_DIR``
# If an optional group is provided sg will be used to set the group of
# the command.
# _run_process service "command-line" [group]
function _run_process {
    local service=$1
    local command="$2"
    local group=$3

    # Undo logging redirections and close the extra descriptors
    exec 1>&3
    exec 2>&3
    exec 3>&-
    exec 6>&-

    if [[ -n ${SCREEN_LOGDIR} ]]; then
        exec 1>&${SCREEN_LOGDIR}/screen-${service}.${CURRENT_LOG_TIME}.log 2>&1
        ln -sf ${SCREEN_LOGDIR}/screen-${service}.${CURRENT_LOG_TIME}.log ${SCREEN_LOGDIR}/screen-${service}.log

        # TODO(dtroyer): Hack to get stdout from the Python interpreter for the logs.
        export PYTHONUNBUFFERED=1
    fi

    # Run under ``setsid`` to force the process to become a session and group leader.
    # The pid saved can be used with pkill -g to get the entire process group.
    if [[ -n "$group" ]]; then
        setsid sg $group "$command" & echo $! >$SERVICE_DIR/$SCREEN_NAME/$service.pid
    else
        setsid $command & echo $! >$SERVICE_DIR/$SCREEN_NAME/$service.pid
    fi

    # Just silently exit this process
    exit 0
}

# Helper to remove the ``*.failure`` files under ``$SERVICE_DIR/$SCREEN_NAME``.
# This is used for ``service_check`` when all the ``screen_it`` are called finished
# Uses globals ``SCREEN_NAME``, ``SERVICE_DIR``
# init_service_check
function init_service_check {
    SCREEN_NAME=${SCREEN_NAME:-stack}
    SERVICE_DIR=${SERVICE_DIR:-${DEST}/status}

    if [[ ! -d "$SERVICE_DIR/$SCREEN_NAME" ]]; then
        mkdir -p "$SERVICE_DIR/$SCREEN_NAME"
    fi

    rm -f "$SERVICE_DIR/$SCREEN_NAME"/*.failure
}

# Find out if a process exists by partial name.
# is_running name
function is_running {
    local name=$1
    ps auxw | grep -v grep | grep ${name} > /dev/null
    local exitcode=$?
    # some times I really hate bash reverse binary logic
    return $exitcode
}

# Run a single service under screen or directly
# If the command includes shell metachatacters (;<>*) it must be run using a shell
# If an optional group is provided sg will be used to run the
# command as that group.
# run_process service "command-line" [group]
function run_process {
    local service=$1
    local command="$2"
    local group=$3

    if is_service_enabled $service; then
        if [[ "$USE_SCREEN" = "True" ]]; then
            screen_process "$service" "$command" "$group"
        else
            # Spawn directly without screen
            _run_process "$service" "$command" "$group" &
        fi
    fi
}

# Helper to launch a process in a named screen
# Uses globals ``CURRENT_LOG_TIME``, ``SCREEN_NAME``, ``SCREEN_LOGDIR``,
# ``SERVICE_DIR``, ``USE_SCREEN``
# screen_process name "command-line" [group]
# Run a command in a shell in a screen window, if an optional group
# is provided, use sg to set the group of the command.
function screen_process {
    local name=$1
    local command="$2"
    local group=$3

    SCREEN_NAME=${SCREEN_NAME:-stack}
    SERVICE_DIR=${SERVICE_DIR:-${DEST}/status}
    USE_SCREEN=$(trueorfalse True $USE_SCREEN)

    # Append the process to the screen rc file
    screen_rc "$name" "$command"

    screen -S $SCREEN_NAME -X screen -t $name

    if [[ -n ${SCREEN_LOGDIR} ]]; then
        screen -S $SCREEN_NAME -p $name -X logfile ${SCREEN_LOGDIR}/screen-${name}.${CURRENT_LOG_TIME}.log
        screen -S $SCREEN_NAME -p $name -X log on
        ln -sf ${SCREEN_LOGDIR}/screen-${name}.${CURRENT_LOG_TIME}.log ${SCREEN_LOGDIR}/screen-${name}.log
    fi

    # sleep to allow bash to be ready to be send the command - we are
    # creating a new window in screen and then sends characters, so if
    # bash isn't running by the time we send the command, nothing happens
    sleep 3

    NL=`echo -ne '\015'`
    # This fun command does the following:
    # - the passed server command is backgrounded
    # - the pid of the background process is saved in the usual place
    # - the server process is brought back to the foreground
    # - if the server process exits prematurely the fg command errors
    # and a message is written to stdout and the process failure file
    #
    # The pid saved can be used in stop_process() as a process group
    # id to kill off all child processes
    if [[ -n "$group" ]]; then
        command="sg $group '$command'"
    fi
    screen -S $SCREEN_NAME -p $name -X stuff "$command & echo \$! >$SERVICE_DIR/$SCREEN_NAME/${name}.pid; fg || echo \"$name failed to start\" | tee \"$SERVICE_DIR/$SCREEN_NAME/${name}.failure\"$NL"
}

# Screen rc file builder
# Uses globals ``SCREEN_NAME``, ``SCREENRC``
# screen_rc service "command-line"
function screen_rc {
    SCREEN_NAME=${SCREEN_NAME:-stack}
    SCREENRC=$TOP_DIR/$SCREEN_NAME-screenrc
    if [[ ! -e $SCREENRC ]]; then
        # Name the screen session
        echo "sessionname $SCREEN_NAME" > $SCREENRC
        # Set a reasonable statusbar
        echo "hardstatus alwayslastline '$SCREEN_HARDSTATUS'" >> $SCREENRC
        # Some distributions override PROMPT_COMMAND for the screen terminal type - turn that off
        echo "setenv PROMPT_COMMAND /bin/true" >> $SCREENRC
        echo "screen -t shell bash" >> $SCREENRC
    fi
    # If this service doesn't already exist in the screenrc file
    if ! grep $1 $SCREENRC 2>&1 > /dev/null; then
        NL=`echo -ne '\015'`
        echo "screen -t $1 bash" >> $SCREENRC
        echo "stuff \"$2$NL\"" >> $SCREENRC

        if [[ -n ${SCREEN_LOGDIR} ]]; then
            echo "logfile ${SCREEN_LOGDIR}/screen-${1}.${CURRENT_LOG_TIME}.log" >>$SCREENRC
            echo "log on" >>$SCREENRC
        fi
    fi
}

# Stop a service in screen
# If a PID is available use it, kill the whole process group via TERM
# If screen is being used kill the screen window; this will catch processes
# that did not leave a PID behind
# Uses globals ``SCREEN_NAME``, ``SERVICE_DIR``, ``USE_SCREEN``
# screen_stop_service service
function screen_stop_service {
    local service=$1

    SCREEN_NAME=${SCREEN_NAME:-stack}
    SERVICE_DIR=${SERVICE_DIR:-${DEST}/status}
    USE_SCREEN=$(trueorfalse True $USE_SCREEN)

    if is_service_enabled $service; then
        # Clean up the screen window
        screen -S $SCREEN_NAME -p $service -X kill
    fi
}

# Stop a service process
# If a PID is available use it, kill the whole process group via TERM
# If screen is being used kill the screen window; this will catch processes
# that did not leave a PID behind
# Uses globals ``SERVICE_DIR``, ``USE_SCREEN``
# stop_process service
function stop_process {
    local service=$1

    SERVICE_DIR=${SERVICE_DIR:-${DEST}/status}
    USE_SCREEN=$(trueorfalse True $USE_SCREEN)

    if is_service_enabled $service; then
        # Kill via pid if we have one available
        if [[ -r $SERVICE_DIR/$SCREEN_NAME/$service.pid ]]; then
            pkill -g $(cat $SERVICE_DIR/$SCREEN_NAME/$service.pid)
            rm $SERVICE_DIR/$SCREEN_NAME/$service.pid
        fi
        if [[ "$USE_SCREEN" = "True" ]]; then
            # Clean up the screen window
            screen_stop_service $service
        fi
    fi
}

# Helper to get the status of each running service
# Uses globals ``SCREEN_NAME``, ``SERVICE_DIR``
# service_check
function service_check {
    local service
    local failures
    SCREEN_NAME=${SCREEN_NAME:-stack}
    SERVICE_DIR=${SERVICE_DIR:-${DEST}/status}


    if [[ ! -d "$SERVICE_DIR/$SCREEN_NAME" ]]; then
        echo "No service status directory found"
        return
    fi

    # Check if there is any falure flag file under $SERVICE_DIR/$SCREEN_NAME
    # make this -o errexit safe
    failures=`ls "$SERVICE_DIR/$SCREEN_NAME"/*.failure 2>/dev/null || /bin/true`

    for service in $failures; do
        service=`basename $service`
        service=${service%.failure}
        echo "Error: Service $service is not running"
    done

    if [ -n "$failures" ]; then
        die $LINENO "More details about the above errors can be found with screen, with ./rejoin-stack.sh"
    fi
}

# Tail a log file in a screen if USE_SCREEN is true.
function tail_log {
    local name=$1
    local logfile=$2

    USE_SCREEN=$(trueorfalse True $USE_SCREEN)
    if [[ "$USE_SCREEN" = "True" ]]; then
        screen_process "$name" "sudo tail -f $logfile"
    fi
}


# Deprecated Functions
# --------------------

# _old_run_process() is designed to be backgrounded by old_run_process() to simulate a
# fork.  It includes the dirty work of closing extra filehandles and preparing log
# files to produce the same logs as screen_it().  The log filename is derived
# from the service name and global-and-now-misnamed ``SCREEN_LOGDIR``
# Uses globals ``CURRENT_LOG_TIME``, ``SCREEN_LOGDIR``, ``SCREEN_NAME``, ``SERVICE_DIR``
# _old_run_process service "command-line"
function _old_run_process {
    local service=$1
    local command="$2"

    # Undo logging redirections and close the extra descriptors
    exec 1>&3
    exec 2>&3
    exec 3>&-
    exec 6>&-

    if [[ -n ${SCREEN_LOGDIR} ]]; then
        exec 1>&${SCREEN_LOGDIR}/screen-${1}.${CURRENT_LOG_TIME}.log 2>&1
        ln -sf ${SCREEN_LOGDIR}/screen-${1}.${CURRENT_LOG_TIME}.log ${SCREEN_LOGDIR}/screen-${1}.log

        # TODO(dtroyer): Hack to get stdout from the Python interpreter for the logs.
        export PYTHONUNBUFFERED=1
    fi

    exec /bin/bash -c "$command"
    die "$service exec failure: $command"
}

# old_run_process() launches a child process that closes all file descriptors and
# then exec's the passed in command.  This is meant to duplicate the semantics
# of screen_it() without screen.  PIDs are written to
# ``$SERVICE_DIR/$SCREEN_NAME/$service.pid`` by the spawned child process.
# old_run_process service "command-line"
function old_run_process {
    local service=$1
    local command="$2"

    # Spawn the child process
    _old_run_process "$service" "$command" &
    echo $!
}

# Compatibility for existing start_XXXX() functions
# Uses global ``USE_SCREEN``
# screen_it service "command-line"
function screen_it {
    if is_service_enabled $1; then
        # Append the service to the screen rc file
        screen_rc "$1" "$2"

        if [[ "$USE_SCREEN" = "True" ]]; then
            screen_process "$1" "$2"
        else
            # Spawn directly without screen
            old_run_process "$1" "$2" >$SERVICE_DIR/$SCREEN_NAME/$1.pid
        fi
    fi
}

# Compatibility for existing stop_XXXX() functions
# Stop a service in screen
# If a PID is available use it, kill the whole process group via TERM
# If screen is being used kill the screen window; this will catch processes
# that did not leave a PID behind
# screen_stop service
function screen_stop {
    # Clean up the screen window
    stop_process $1
}


# Python Functions
# ================

# Get the path to the pip command.
# get_pip_command
function get_pip_command {
    which pip || which pip-python

    if [ $? -ne 0 ]; then
        die $LINENO "Unable to find pip; cannot continue"
    fi
}

# Get the path to the direcotry where python executables are installed.
# get_python_exec_prefix
function get_python_exec_prefix {
    if is_fedora || is_suse; then
        echo "/usr/bin"
    else
        echo "/usr/local/bin"
    fi
}

# Wrapper for ``pip install`` to set cache and proxy environment variables
# Uses globals ``OFFLINE``, ``PIP_DOWNLOAD_CACHE``,
# ``TRACK_DEPENDS``, ``*_proxy``
# pip_install package [package ...]
function pip_install {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    if [[ "$OFFLINE" = "True" || -z "$@" ]]; then
        $xtrace
        return
    fi

    if [[ -z "$os_PACKAGE" ]]; then
        GetOSVersion
    fi
    if [[ $TRACK_DEPENDS = True && ! "$@" =~ virtualenv ]]; then
        # TRACK_DEPENDS=True installation creates a circular dependency when
        # we attempt to install virtualenv into a virualenv, so we must global
        # that installation.
        source $DEST/.venv/bin/activate
        local cmd_pip=$DEST/.venv/bin/pip
        local sudo_pip="env"
    else
        local cmd_pip=$(get_pip_command)
        local sudo_pip="sudo"
    fi

    $xtrace
    $sudo_pip PIP_DOWNLOAD_CACHE=${PIP_DOWNLOAD_CACHE:-/var/cache/pip} \
        http_proxy=$http_proxy \
        https_proxy=$https_proxy \
        no_proxy=$no_proxy \
        $cmd_pip install \
        $@

    INSTALL_TESTONLY_PACKAGES=$(trueorfalse False $INSTALL_TESTONLY_PACKAGES)
    if [[ "$INSTALL_TESTONLY_PACKAGES" == "True" ]]; then
        local test_req="$@/test-requirements.txt"
        if [[ -e "$test_req" ]]; then
            $sudo_pip PIP_DOWNLOAD_CACHE=${PIP_DOWNLOAD_CACHE:-/var/cache/pip} \
                http_proxy=$http_proxy \
                https_proxy=$https_proxy \
                no_proxy=$no_proxy \
                $cmd_pip install \
                -r $test_req
        fi
    fi
}

# should we use this library from their git repo, or should we let it
# get pulled in via pip dependencies.
function use_library_from_git {
    local name=$1
    local enabled=1
    [[ ,${LIBS_FROM_GIT}, =~ ,${name}, ]] && enabled=0
    return $enabled
}

# setup a library by name. If we are trying to use the library from
# git, we'll do a git based install, otherwise we'll punt and the
# library should be installed by a requirements pull from another
# project.
function setup_lib {
    local name=$1
    local dir=${GITDIR[$name]}
    setup_install $dir
}

# setup a library by name in editiable mode. If we are trying to use
# the library from git, we'll do a git based install, otherwise we'll
# punt and the library should be installed by a requirements pull from
# another project.
#
# use this for non namespaced libraries
function setup_dev_lib {
    local name=$1
    local dir=${GITDIR[$name]}
    setup_develop $dir
}

# this should be used if you want to install globally, all libraries should
# use this, especially *oslo* ones
function setup_install {
    local project_dir=$1
    setup_package_with_req_sync $project_dir
}

# this should be used for projects which run services, like all services
function setup_develop {
    local project_dir=$1
    setup_package_with_req_sync $project_dir -e
}

# determine if a project as specified by directory is in
# projects.txt. This will not be an exact match because we throw away
# the namespacing when we clone, but it should be good enough in all
# practical ways.
function is_in_projects_txt {
    local project_dir=$1
    local project_name=$(basename $project_dir)
    return grep "/$project_name\$" $REQUIREMENTS_DIR/projects.txt >/dev/null
}

# ``pip install -e`` the package, which processes the dependencies
# using pip before running `setup.py develop`
#
# Updates the dependencies in project_dir from the
# openstack/requirements global list before installing anything.
#
# Uses globals ``TRACK_DEPENDS``, ``REQUIREMENTS_DIR``, ``UNDO_REQUIREMENTS``
# setup_develop directory
function setup_package_with_req_sync {
    local project_dir=$1
    local flags=$2

    # Don't update repo if local changes exist
    # Don't use buggy "git diff --quiet"
    # ``errexit`` requires us to trap the exit code when the repo is changed
    local update_requirements=$(cd $project_dir && git diff --exit-code >/dev/null || echo "changed")

    if [[ $update_requirements != "changed" ]]; then
        if [[ "$REQUIREMENTS_MODE" == "soft" ]]; then
            if is_in_projects_txt $project_dir; then
                (cd $REQUIREMENTS_DIR; \
                    python update.py $project_dir)
            else
                # soft update projects not found in requirements project.txt
                (cd $REQUIREMENTS_DIR; \
                    python update.py -s $project_dir)
            fi
        else
            (cd $REQUIREMENTS_DIR; \
                python update.py $project_dir)
        fi
    fi

    setup_package $project_dir $flags

    # We've just gone and possibly modified the user's source tree in an
    # automated way, which is considered bad form if it's a development
    # tree because we've screwed up their next git checkin. So undo it.
    #
    # However... there are some circumstances, like running in the gate
    # where we really really want the overridden version to stick. So provide
    # a variable that tells us whether or not we should UNDO the requirements
    # changes (this will be set to False in the OpenStack ci gate)
    if [ $UNDO_REQUIREMENTS = "True" ]; then
        if [[ $update_requirements != "changed" ]]; then
            (cd $project_dir && git reset --hard)
        fi
    fi
}

# ``pip install -e`` the package, which processes the dependencies
# using pip before running `setup.py develop`
# Uses globals ``STACK_USER``
# setup_develop_no_requirements_update directory
function setup_package {
    local project_dir=$1
    local flags=$2

    pip_install $flags $project_dir
    # ensure that further actions can do things like setup.py sdist
    if [[ "$flags" == "-e" ]]; then
        safe_chown -R $STACK_USER $1/*.egg-info
    fi
}


# Service Functions
# =================

# remove extra commas from the input string (i.e. ``ENABLED_SERVICES``)
# _cleanup_service_list service-list
function _cleanup_service_list {
    echo "$1" | sed -e '
        s/,,/,/g;
        s/^,//;
        s/,$//
    '
}

# disable_all_services() removes all current services
# from ``ENABLED_SERVICES`` to reset the configuration
# before a minimal installation
# Uses global ``ENABLED_SERVICES``
# disable_all_services
function disable_all_services {
    ENABLED_SERVICES=""
}

# Remove all services starting with '-'.  For example, to install all default
# services except rabbit (rabbit) set in ``localrc``:
# ENABLED_SERVICES+=",-rabbit"
# Uses global ``ENABLED_SERVICES``
# disable_negated_services
function disable_negated_services {
    local tmpsvcs="${ENABLED_SERVICES}"
    local service
    for service in ${tmpsvcs//,/ }; do
        if [[ ${service} == -* ]]; then
            tmpsvcs=$(echo ${tmpsvcs}|sed -r "s/(,)?(-)?${service#-}(,)?/,/g")
        fi
    done
    ENABLED_SERVICES=$(_cleanup_service_list "$tmpsvcs")
}

# disable_service() removes the services passed as argument to the
# ``ENABLED_SERVICES`` list, if they are present.
#
# For example:
#   disable_service rabbit
#
# This function does not know about the special cases
# for nova, glance, and neutron built into is_service_enabled().
# Uses global ``ENABLED_SERVICES``
# disable_service service [service ...]
function disable_service {
    local tmpsvcs=",${ENABLED_SERVICES},"
    local service
    for service in $@; do
        if is_service_enabled $service; then
            tmpsvcs=${tmpsvcs//,$service,/,}
        fi
    done
    ENABLED_SERVICES=$(_cleanup_service_list "$tmpsvcs")
}

# enable_service() adds the services passed as argument to the
# ``ENABLED_SERVICES`` list, if they are not already present.
#
# For example:
#   enable_service qpid
#
# This function does not know about the special cases
# for nova, glance, and neutron built into is_service_enabled().
# Uses global ``ENABLED_SERVICES``
# enable_service service [service ...]
function enable_service {
    local tmpsvcs="${ENABLED_SERVICES}"
    local service
    for service in $@; do
        if ! is_service_enabled $service; then
            tmpsvcs+=",$service"
        fi
    done
    ENABLED_SERVICES=$(_cleanup_service_list "$tmpsvcs")
    disable_negated_services
}

# is_service_enabled() checks if the service(s) specified as arguments are
# enabled by the user in ``ENABLED_SERVICES``.
#
# Multiple services specified as arguments are ``OR``'ed together; the test
# is a short-circuit boolean, i.e it returns on the first match.
#
# There are special cases for some 'catch-all' services::
#   **nova** returns true if any service enabled start with **n-**
#   **cinder** returns true if any service enabled start with **c-**
#   **ceilometer** returns true if any service enabled start with **ceilometer**
#   **glance** returns true if any service enabled start with **g-**
#   **neutron** returns true if any service enabled start with **q-**
#   **swift** returns true if any service enabled start with **s-**
#   **trove** returns true if any service enabled start with **tr-**
#   For backward compatibility if we have **swift** in ENABLED_SERVICES all the
#   **s-** services will be enabled. This will be deprecated in the future.
#
# Cells within nova is enabled if **n-cell** is in ``ENABLED_SERVICES``.
# We also need to make sure to treat **n-cell-region** and **n-cell-child**
# as enabled in this case.
#
# Uses global ``ENABLED_SERVICES``
# is_service_enabled service [service ...]
function is_service_enabled {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local enabled=1
    local services=$@
    local service
    for service in ${services}; do
        [[ ,${ENABLED_SERVICES}, =~ ,${service}, ]] && enabled=0

        # Look for top-level 'enabled' function for this service
        if type is_${service}_enabled >/dev/null 2>&1; then
            # A function exists for this service, use it
            is_${service}_enabled
            enabled=$?
        fi

        # TODO(dtroyer): Remove these legacy special-cases after the is_XXX_enabled()
        #                are implemented

        [[ ${service} == n-cell-* && ${ENABLED_SERVICES} =~ "n-cell" ]] && enabled=0
        [[ ${service} == n-cpu-* && ${ENABLED_SERVICES} =~ "n-cpu" ]] && enabled=0
        [[ ${service} == "nova" && ${ENABLED_SERVICES} =~ "n-" ]] && enabled=0
        [[ ${service} == "cinder" && ${ENABLED_SERVICES} =~ "c-" ]] && enabled=0
        [[ ${service} == "ceilometer" && ${ENABLED_SERVICES} =~ "ceilometer-" ]] && enabled=0
        [[ ${service} == "glance" && ${ENABLED_SERVICES} =~ "g-" ]] && enabled=0
        [[ ${service} == "ironic" && ${ENABLED_SERVICES} =~ "ir-" ]] && enabled=0
        [[ ${service} == "neutron" && ${ENABLED_SERVICES} =~ "q-" ]] && enabled=0
        [[ ${service} == "trove" && ${ENABLED_SERVICES} =~ "tr-" ]] && enabled=0
        [[ ${service} == "swift" && ${ENABLED_SERVICES} =~ "s-" ]] && enabled=0
        [[ ${service} == s-* && ${ENABLED_SERVICES} =~ "swift" ]] && enabled=0
        [[ ${service} == key-* && ${ENABLED_SERVICES} =~ "key" ]] && enabled=0
    done
    $xtrace
    return $enabled
}

# Toggle enable/disable_service for services that must run exclusive of each other
#  $1 The name of a variable containing a space-separated list of services
#  $2 The name of a variable in which to store the enabled service's name
#  $3 The name of the service to enable
function use_exclusive_service {
    local options=${!1}
    local selection=$3
    local out=$2
    [ -z $selection ] || [[ ! "$options" =~ "$selection" ]] && return 1
    local opt
    for opt in $options;do
        [[ "$opt" = "$selection" ]] && enable_service $opt || disable_service $opt
    done
    eval "$out=$selection"
    return 0
}


# System Functions
# ================

# Only run the command if the target file (the last arg) is not on an
# NFS filesystem.
function _safe_permission_operation {
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local args=( $@ )
    local last
    local sudo_cmd
    local dir_to_check

    let last="${#args[*]} - 1"

    local dir_to_check=${args[$last]}
    if [ ! -d "$dir_to_check" ]; then
        dir_to_check=`dirname "$dir_to_check"`
    fi

    if is_nfs_directory "$dir_to_check" ; then
        $xtrace
        return 0
    fi

    if [[ $TRACK_DEPENDS = True ]]; then
        sudo_cmd="env"
    else
        sudo_cmd="sudo"
    fi

    $xtrace
    $sudo_cmd $@
}

# Exit 0 if address is in network or 1 if address is not in network
# ip-range is in CIDR notation: 1.2.3.4/20
# address_in_net ip-address ip-range
function address_in_net {
    local ip=$1
    local range=$2
    local masklen=${range#*/}
    local network=$(maskip ${range%/*} $(cidr2netmask $masklen))
    local subnet=$(maskip $ip $(cidr2netmask $masklen))
    [[ $network == $subnet ]]
}

# Add a user to a group.
# add_user_to_group user group
function add_user_to_group {
    local user=$1
    local group=$2

    if [[ -z "$os_VENDOR" ]]; then
        GetOSVersion
    fi

    # SLE11 and openSUSE 12.2 don't have the usual usermod
    if ! is_suse || [[ "$os_VENDOR" = "openSUSE" && "$os_RELEASE" != "12.2" ]]; then
        sudo usermod -a -G "$group" "$user"
    else
        sudo usermod -A "$group" "$user"
    fi
}

# Convert CIDR notation to a IPv4 netmask
# cidr2netmask cidr-bits
function cidr2netmask {
    local maskpat="255 255 255 255"
    local maskdgt="254 252 248 240 224 192 128"
    set -- ${maskpat:0:$(( ($1 / 8) * 4 ))}${maskdgt:$(( (7 - ($1 % 8)) * 4 )):3}
    echo ${1-0}.${2-0}.${3-0}.${4-0}
}

# Gracefully cp only if source file/dir exists
# cp_it source destination
function cp_it {
    if [ -e $1 ] || [ -d $1 ]; then
        cp -pRL $1 $2
    fi
}

# HTTP and HTTPS proxy servers are supported via the usual environment variables [1]
# ``http_proxy``, ``https_proxy`` and ``no_proxy``. They can be set in
# ``localrc`` or on the command line if necessary::
#
# [1] http://www.w3.org/Daemon/User/Proxies/ProxyClients.html
#
#     http_proxy=http://proxy.example.com:3128/ no_proxy=repo.example.net ./stack.sh

function export_proxy_variables {
    if [[ -n "$http_proxy" ]]; then
        export http_proxy=$http_proxy
    fi
    if [[ -n "$https_proxy" ]]; then
        export https_proxy=$https_proxy
    fi
    if [[ -n "$no_proxy" ]]; then
        export no_proxy=$no_proxy
    fi
}

# Returns true if the directory is on a filesystem mounted via NFS.
function is_nfs_directory {
    local mount_type=`stat -f -L -c %T $1`
    test "$mount_type" == "nfs"
}

# Return the network portion of the given IP address using netmask
# netmask is in the traditional dotted-quad format
# maskip ip-address netmask
function maskip {
    local ip=$1
    local mask=$2
    local l="${ip%.*}"; local r="${ip#*.}"; local n="${mask%.*}"; local m="${mask#*.}"
    local subnet=$((${ip%%.*}&${mask%%.*})).$((${r%%.*}&${m%%.*})).$((${l##*.}&${n##*.})).$((${ip##*.}&${mask##*.}))
    echo $subnet
}

# Service wrapper to restart services
# restart_service service-name
function restart_service {
    if is_ubuntu; then
        sudo /usr/sbin/service $1 restart
    else
        sudo /sbin/service $1 restart
    fi
}

# Only change permissions of a file or directory if it is not on an
# NFS filesystem.
function safe_chmod {
    _safe_permission_operation chmod $@
}

# Only change ownership of a file or directory if it is not on an NFS
# filesystem.
function safe_chown {
    _safe_permission_operation chown $@
}

# Service wrapper to start services
# start_service service-name
function start_service {
    if is_ubuntu; then
        sudo /usr/sbin/service $1 start
    else
        sudo /sbin/service $1 start
    fi
}

# Service wrapper to stop services
# stop_service service-name
function stop_service {
    if is_ubuntu; then
        sudo /usr/sbin/service $1 stop
    else
        sudo /sbin/service $1 stop
    fi
}

# Runs a command multiple times
# exec_with_retry 5 2 cat
function exec_with_retry () {
    local MAX_RETRIES=$1
    local INTERVAL=$2

    local COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        local EXIT=0
        eval '${@:3}' || EXIT=$?
        if [ $EXIT -eq 0 ]; then
            return 0
        fi
        let COUNTER=COUNTER+1

        if [ -n "$INTERVAL" ]; then
            sleep $INTERVAL
        fi
    done
    return $EXIT
}

# Restore xtrace
$XTRACE

# Local variables:
# mode: shell-script
# End:
