#!/usr/bin/env bash

set -ev

# Source the setup script
source /home/dokikai/Compute-PMC/pulp-dev/pulp_deb/setup.sh

PULP_URL=${PULP_URL:-http://localhost:5001}
export PULP_USER=admin
export PULP_PASSWORD=password

trap "rm -f frigg_1.0_ppc64.deb" EXIT

# download a package
wget https://fixtures.pulpproject.org/debian/pool/asgard/f/frigg/frigg_1.0_ppc64.deb

# upload the package and get package href
TASK_HREF=$(http --form $PULP_URL/pulp/api/v3/content/deb/packages/ file@frigg_1.0_ppc64.deb | jq -r .task)
wait_until_task_finished ${PULP_URL}${TASK_HREF}
PACKAGE_HREF=$(http ${PULP_URL}${TASK_HREF} | jq -r ".created_resources[0]")
echo ${PACKAGE_HREF}

# create a repo and distro
CREATE_REPO_RAW=$(http POST ${PULP_URL}/pulp/api/v3/repositories/deb/apt/ name=myrepo)
REPO_HREF=$(echo ${CREATE_REPO_RAW} | jq -r .pulp_href)
TASK_HREF=$(http POST ${PULP_URL}/pulp/api/v3/distributions/deb/apt/ name=myrepo base_path=myrepo repository=${REPO_HREF} | jq -r .task)
wait_until_task_finished ${PULP_URL}${TASK_HREF}
echo ${REPO_HREF}

# create the necessary content (release, comp, architecture)
# release
RELEASE_HREF=$(http POST ${PULP_URL}/pulp/api/v3/content/deb/releases/ codename=mycodename suite=mysuite distribution=mydist | jq -r .pulp_href)
echo ${RELEASE_HREF}

# create architecture
ARCH_HREF_TASK=$(http POST ${PULP_URL}/pulp/api/v3/content/deb/release_architectures/ architecture=ppc64 distribution=mydist | jq -r .task)
ARCH_HREF=$(wait_until_task_finished ${PULP_URL}${ARCH_HREF_TASK})
echo ${ARCH_HREF}

# create a component
COMP_HREF_TASK=$(http POST ${PULP_URL}/pulp/api/v3/content/deb/release_components/ component=mycomp distribution=mydist | jq -r .task)
COMP_HREF=$(wait_until_task_finished ${PULP_URL}${COMP_HREF_TASK})
echo ${COMP_HREF}

# create a package release component
PKG_COMP_HREF=$(http POST ${PULP_URL}/pulp/api/v3/content/deb/package_release_components/ package=$PACKAGE_HREF release_component=$COMP_HREF | jq -r .pulp_href)
echo ${PKG_COMP_HREF}

# add our content to the repository
TASK_HREF=$(http ${PULP_URL}${REPO_HREF}modify/ add_content_units:="[\"$RELEASE_HREF\", \"$COMP_HREF\", \"$PACKAGE_HREF\", \"$PKG_COMP_HREF\", \"$ARCH_HREF\"]" | jq -r .task)
wait_until_task_finished ${PULP_URL}${TASK_HREF}

# publish our repo
TASK_HREF=$(http ${PULP_URL}/pulp/api/v3/publications/deb/apt/ repository=$REPO_HREF | jq -r .task)
wait_until_task_finished ${PULP_URL}${TASK_HREF}

# check that our repo has our release
http --check-status ${PULP_URL}/pulp/content/myrepo/dists/mydist/mycomp/binary-ppc64/

echo "---------------Done---------------"