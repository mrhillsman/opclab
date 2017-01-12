#!/usr/bin/env bash

set -e -u -x
set -o pipefail

export ADMIN_PASSWORD=${ADMIN_PASSWORD:-"secrete"}
export DEPLOY_AIO=${DEPLOY_AIO:-"no"}
export DEPLOY_HAPROXY=${DEPLOY_HAPROXY:-"no"}
export DEPLOY_OA=${DEPLOY_OA:-"yes"}
export DEPLOY_ELK=${DEPLOY_ELK:-"no"}
export DEPLOY_MAAS=${DEPLOY_MAAS:-"no"}
export DEPLOY_TEMPEST=${DEPLOY_TEMPEST:-"no"}
export DEPLOY_CEILOMETER=${DEPLOY_CEILOMETER:-"no"}
export DEPLOY_CEPH=${DEPLOY_CEPH:-"no"}
export FORKS=${FORKS:-$(grep -c ^processor /proc/cpuinfo)}
export ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:-""}
export BOOTSTRAP_OPTS=${BOOTSTRAP_OPTS:-""}

OA_DIR='/opt/rpc-openstack/openstack-ansible'
RPCD_DIR='/opt/rpc-openstack/rpcd'
RPCD_VARS='/etc/openstack_deploy/user_extras_variables.yml'
RPCD_SECRETS='/etc/openstack_deploy/user_extras_secrets.yml'

function run_ansible {
  openstack-ansible ${ANSIBLE_PARAMETERS} --forks ${FORKS} $@
}

# begin the bootstrap process
cd ${OA_DIR}

# bootstrap ansible if need be
which openstack-ansible || ./scripts/bootstrap-ansible.sh

# ensure all needed passwords and tokens are generated
./scripts/pw-token-gen.py --file /etc/openstack_deploy/user_secrets.yml
./scripts/pw-token-gen.py --file $RPCD_SECRETS

# Apply any patched files.
cd ${RPCD_DIR}/playbooks
openstack-ansible -i "localhost," patcher.yml

# begin the openstack installation
if [[ "${DEPLOY_OA}" == "yes" ]]; then
  cd ${OA_DIR}/playbooks/

  # setup the hosts and build the basic containers
  run_ansible setup-hosts.yml

  # setup the infrastructure
  run_ansible setup-infrastructure.yml

  # setup openstack
  run_ansible setup-openstack.yml

fi

# begin the RPC installation
cd ${RPCD_DIR}/playbooks/

# build the RPC python package repository
run_ansible repo-build.yml

# configure all hosts and containers to use the RPC python packages
run_ansible repo-pip-setup.yml

# configure everything for RPC support access
run_ansible rpc-support.yml

# configure the horizon extensions
run_ansible horizon_extensions.yml