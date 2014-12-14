#!/bin/bash
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


# Save trace setting
XTRACE=$(set +o | grep xtrace)
set -o xtrace

# Get current timestamp
TIME_STAMP=$(date +"%H%M%S-%d%m%Y")

# Source utils functions
source functions.sh

# Load the configuration file
if [[ -z $1 ]]; then
    echo "ERROR: You must provide a configuration file in YAML format as a parameter!"
    exit 1
elif [[ ! -f $1 ]]; then
    #statements
    echo "ERROR: There is not such file <$1>!"
    exit 1
else
    eval $(parse_yaml $1 "CONF_")
fi

# Check if env_tempestdir and test_list variable are set
if [[ -z $CONF_env_tempestdir ]] || [[ -z $CONF_test_list ]]; then
    echo "ERROR: The env_tempestdir or test_list are not set in $1!"
    exit 1
else
    # Copy the tempest conf sample and test list file
    cp tempest.conf.sample $CONF_env_tempestdir/etc/tempest.conf
    cp $CONF_test_list $CONF_env_tempestdir/
fi

# Main script body
# ================

cd $CONF_env_tempestdir

# sudo python tools/install_venv.py
# source .venv/bin/activate

# sudo pip install -r requirements.txt

if [[ -d ".testrepository" ]]; then
    rm -rf .testrepository
fi

export OS_USERNAME="$CONF_env_osuser"
export OS_TENANT_NAME="$CONF_env_ostenant"
export OS_PASSWORD="$CONF_env_ospassword"
export OS_AUTH_URL="http://$CONF_env_hostip:5000/v2.0/"

# Get the flavour
if [[ -z $CONF_image_flavour ]]; then
CONF_image_flavour=$(get_flavour_by_metadata $CONF_test_aggregate)
fi

# Get the image id
if [[ -z $CONF_image_id ]]; then
CONF_image_id=$(get_imageid $CONF_image_name)
fi

# Get the ssh user
if [[ -z $CONF_image_ssh_user ]]; then
CONF_image_ssh_user=$(get_ssh_user_from_image $CONF_image_name)
fi

# Get the network for ssh
if [[ -z $CONF_env_network_ssh ]]; then
    CONF_env_network_ssh=$(neutron net-list | grep private | awk 'FNR == 1 {print $2}')
    echo "INFO: No ssh network defined in $1. Using the <$CONF_env_network_ssh> network"
fi

# Get the public network
if [[ -z $CONF_env_network_public ]]; then
    CONF_env_network_public=$(neutron net-external-list | grep public | awk 'FNR == 1 {print $2}')
    echo "INFO: No public network defined in $1. Using the <$CONF_env_network_public> network"
fi

# Configure logging
if [[ ! -z "$CONF_test_logdir" ]] && [[ ! -d "$CONF_test_logdir" ]]; then
    mkdir -pv "$CONF_test_logdir"
    # Logfile
    CONF_test_subunitlog=$CONF_test_logdir/$TIME_STAMP-$CONF_test_name + ".sub"
    CONF_test_tempestlog=$CONF_test_logdir/$TIME_STAMP-$CONF_test_name + ".log"
fi

set +o xtrace
echo -e "\\nTempest configuration is:"
compgen -A variable | grep CONF_* | while read var; do printf "%s: %q\n" "$var" "${!var}"; done
set -o xtrace
# [compute] 
iniset $CONF_env_tempestdir/etc/tempest.conf compute flavor_ref_alt $CONF_image_flavour
iniset $CONF_env_tempestdir/etc/tempest.conf compute flavor_ref $CONF_image_flavour
iniset $CONF_env_tempestdir/etc/tempest.conf compute image_alt_ssh_user $CONF_image_ssh_user
iniset $CONF_env_tempestdir/etc/tempest.conf compute image_ref_alt $CONF_image_id
iniset $CONF_env_tempestdir/etc/tempest.conf compute image_ssh_user $CONF_image_ssh_user
iniset $CONF_env_tempestdir/etc/tempest.conf compute image_ref = $CONF_image_id
iniset $CONF_env_tempestdir/etc/tempest.conf compute network_for_ssh $CONF_env_network_ssh
iniset $CONF_env_tempestdir/etc/tempest.conf compute ssh_user $CONF_image_ssh_user

iniset $CONF_env_tempestdir/etc/tempest.conf compute allow_tenant_isolation False
iniset $CONF_env_tempestdir/etc/tempest.conf compute build_interval 1
iniset $CONF_env_tempestdir/etc/tempest.conf compute build_timeout 196
iniset $CONF_env_tempestdir/etc/tempest.conf compute ssh_timeout 196
iniset $CONF_env_tempestdir/etc/tempest.conf compute ip_version_for_ssh 4
iniset $CONF_env_tempestdir/etc/tempest.conf compute volume_device_name sdb
iniset $CONF_env_tempestdir/etc/tempest.conf compute ssh_connect_method floating


# [DEFAULT] 
iniset $CONF_env_tempestdir/etc/tempest.conf DEFAULT log_file $CONF_test_tempestlog

iniset $CONF_env_tempestdir/etc/tempest.conf DEFAULT debug True
iniset $CONF_env_tempestdir/etc/tempest.conf DEFAULT use_stderr False
iniset $CONF_env_tempestdir/etc/tempest.conf DEFAULT verbose True

# [host_credentials]
iniset $CONF_env_tempestdir/etc/tempest.conf host_credentials host_user_name $CONF_env_hyperv_user
iniset $CONF_env_tempestdir/etc/tempest.conf host_credentials host_password $CONF_env_hyperv_pass
iniset $CONF_env_tempestdir/etc/tempest.conf host_credentials host_setupscripts_folder $CONF_env_hyperv_scriptdir



# MIN_TEST=tempest.scenario.test_minimum_basic.TestMinimumBasicScenario.test_minimum_basic_scenario

# Run tempest
testr init

# Check if parallel testing is enabled
if [[ $CONF_test_parallel ]]; then
    testr run --parallel --subunit  --load-list=$CONF_test_list |  subunit-2to1  > $CONF_test_subunitlog 2>&1
else
    testr run --subunit  --load-list=$CONF_test_list |  subunit-2to1  > $CONF_test_subunitlog 2>&1
fi

cat $CONF_test_subunitlog | /opt/stack/tempest/tools/colorizer.py > $CONF_test_tempestlog 2>&1
python /home/ubuntu/bin/subunit2html.py $CONF_test_tempestlog

# Restore xtrace
$XTRACE
