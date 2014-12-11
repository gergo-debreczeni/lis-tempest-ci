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
set +o xtrace

# Source the conf file
if [ -e lis-tempest.conf ]; then
    . lis-tempest.conf.sh
else
    LogMsg "ERROR: Unable to source the constants file."
    exit 1
fi

# Variables
if [[ -z $1 ]]; then
    TEMPEST_DIR="$HOME/lis-tempest"
    LOG_DIR="$HOME/lis-tempest-logs/$TEST_SUITE"
    SUITE="TEST_Win2012R2"
    IMAGE="centos64-cloudimg-amd64-vss" 
    AGGREGATE="2012R2" 
    HOST_IP="10.7.21.15"
    DEFAULT_SSH_USER="root"
    OpenStack_USER="admin"
    OpenStack_TENANT="admin"
    OpenStack_PASSWORD="Passw0rd"
else
    source $1
fi

TEMPEST_CONF=$TEMPEST_DIR/etc/tempest.conf

# Source utils functions
source functions.sh


# Main script body
# ================

cd $TEMPEST_DIR

python tools/install_venv.py
source .venv/bin/activate

pip install -r requirements.txt

if [ -d ".testrepository" ]; then
    rm -rf .testrepository
fi

export OS_USERNAME="$OpenStack_USER"
export OS_TENANT_NAME="$OpenStack_TENANT"
export OS_PASSWORD="$OpenStack_PASSWORD"
export OS_AUTH_URL="http://$HOST_IP:5000/v2.0/"

# Set the flavour
test_flavour=get_flavour_by_metadata $TEST_AGGREGATE
iniset $TEMPEST_CONF compute flavor_ref_alt $test_flavour
iniset $TEMPEST_CONF compute flavor_ref $test_flavour

# Set the image
test_image=get_imageid $IMAGE

# Set the ssh user
test_ssh_user=get_ssh_user_from_image $test_image 
iniset $TEMPEST_CONF compute image_ssh_user $test_ssh_user
iniset $TEMPEST_CONF compute ssh_user $test_ssh_user
iniset $TEMPEST_CONF compute image_alt_ssh_user $test_ssh_user

# nova flavor-create m1.nano 42 96 1 1
# nova flavor-create m1.micro 84 128 2 1


initset $TEMPEST_CONF DEFAULT lock_path /tmp


iniset $TEMPEST_CONF identity auth_version v2
iniset $TEMPEST_CONF identity admin_domain_name Default

iniset $TEMPEST_CONF identity admin_tenant_name admin
iniset $TEMPEST_CONF identity admin_username admin
iniset $TEMPEST_CONF identity admin_password $OS_PASSWORD

iniset $TEMPEST_CONF identity alt_username demo
iniset $TEMPEST_CONF identity alt_tenant_name demo
iniset $TEMPEST_CONF identity alt_password $OS_PASSWORD

iniset $TEMPEST_CONF identity username demo
iniset $TEMPEST_CONF identity tenant_name demo
iniset $TEMPEST_CONF identity password $OS_PASSWORD

iniset $TEMPEST_CONF identity uri_v3 http://10.19.28.3:5000/v3/
iniset $TEMPEST_CONF identity uri http://10.19.28.3:5000/v2.0/

iniset $TEMPEST_CONF compute volume_device_name sdb
iniset $TEMPEST_CONF compute ssh_connect_method floating

iniset $TEMPEST_CONF compute ssh_timeout 196
iniset $TEMPEST_CONF compute ip_version_for_ssh 4
iniset $TEMPEST_CONF compute network_for_ssh private
iniset $TEMPEST_CONF compute allow_tenant_isolation True


iniset $TEMPEST_CONF compute build_interval 1
iniset $TEMPEST_CONF compute build_timeout 196

iniset $TEMPEST_CONF compute-feature-enabled rdp_console True
iniset $TEMPEST_CONF compute-feature-enabled change_password False
iniset $TEMPEST_CONF compute-feature-enabled resize True
iniset $TEMPEST_CONF compute-feature-enabled live_migration False
iniset $TEMPEST_CONF compute-feature-enabled block_migrate_cinder_iscsi False
iniset $TEMPEST_CONF compute-feature-enabled block_migration_for_live_migration False


#image_ref_alt = 5ec07fe6-c3bd-4b4b-bac1-b8286866a3e1
#image_ref = 5ec07fe6-c3bd-4b4b-bac1-b8286866a3e1


# iniset $TEMPEST_CONF scenario img_disk_format vhd
# iniset $TEMPEST_CONF scenario img_file cirros-0.3.3-x86_64.vhdx
# iniset $TEMPEST_CONF scenario img_dir /root

# MIN_TEST=tempest.scenario.test_minimum_basic.TestMinimumBasicScenario.test_minimum_basic_scenario

testr init

testr list-tests | grep lis

# testr run --subunit $MIN_TEST | tee >(subunit2junitxml --output-to=results.xml) | subunit-2to1 | tools/colorizer.py


# Restore xtrace
$XTRACE