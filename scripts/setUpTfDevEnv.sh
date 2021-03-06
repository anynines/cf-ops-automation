#!/usr/bin/env bash

function setUpDevEnv {
    DEV_ENV=$1
    SECRET_REPO=$2
    DEPLOYMENT_PATH=$3

    cd $WORKDIR

    mkdir -p $DEV_ENV
    cd $DEV_ENV
    echo "preparing dev env into $(pwd)"

    # Set up git so that we can version our local dev env changes
    if [ ! -d ".git" ]; then
        git init

        #Intellij bash plugin doesn't like the heredoc syntax :-(
        #cat <<- EOF > .gitignore
        #.idea/
        #/generated-files/.terraform/
        #EOF

        echo ".idea/" > .gitignore
        echo "/generated-files/.terraform/" >> .gitignore

        git add .gitignore
        git commit -m "auto generated" .gitignore
    fi


    mkdir -p generated-files
    mkdir -p spec-applied
    ln -snf ${WORKDIR}/${SECRET_REPO} secret-state-resource
    cd generated-files/

    echo "setting up $(pwd)"

    ln -snfv  ${WORKDIR}/${SECRET_REPO}/${DEPLOYMENT_PATH}/terraform.tfstate terraform.tfstate

    #TODO: Manually fetch terraform.tfvars.json vi terraform.tfvars.json
    # An alternative is to ask concourse to run the generate-manifest.yml tasks through fly execute,
    # using local version of these tasks (from cf-ops-automation) and local copies of paas-template and paas-secret


    TEMPLATE_FILES=$(find ${WORKDIR}/paas-template/${DEPLOYMENT_PATH}/spec -mindepth 1 -maxdepth 1 )
    SECRET_FILES=$(find ${WORKDIR}/${SECRET_REPO}/${DEPLOYMENT_PATH}/spec  -mindepth 1 -maxdepth 1 )
    cd ../spec-applied/
    echo "setting up $(pwd)"

    for f in $TEMPLATE_FILES; do name=$(basename $f); ln -nsfv $f $name ; done;
    for f in $SECRET_FILES; do name=$(basename $f); ln -nsfv $f $name ; done;


}

cat << EOF

you may proceed with setting up your env with the following commands:
WORKDIR=/home/guillaume/code/workspaceElPaasov14

setUpDevEnv terraform-prod-micro-deps-env    bosh-cloudwatt-secrets          micro-depls/terraform-config
setUpDevEnv terraform-preprod-micro-deps-env bosh-cloudwatt-preprod-secrets  micro-depls/terraform-config
setUpDevEnv terraform-preprod-env            bosh-cloudwatt-preprod-secrets  ops-depls/cloudfoundry/terraform-config
setUpDevEnv terraform-preprod-ops-deps-env   bosh-cloudwatt-preprod-secrets  ops-depls/cloudfoundry/terraform-config
setUpDevEnv terraform-prod-ops-deps-env      bosh-cloudwatt-secrets          ops-depls/cloudfoundry/terraform-config

# You may now then use TF locally with:

cd \${WORKDIR}/terraform-preprod-env/generated-files
bash -c "\$(curl -fsSL https://raw.github.com/orange-cloudfoundry/terraform-provider-cloudfoundry/master/bin/install.sh)"
terraform init -input=false -upgrade -get-plugins=false -plugin-dir=/.terraform/plugins/linux_amd64 ../spec-applied/
terraform plan -input=false ../spec-applied/
EOF

# An alternative is to ask concourse to run the generate-manifest.yml and terraform_plan_cloudfoundry.yml tasks through fly execute,
# using local version of these tasks (from cf-ops-automation) and local copies of paas-template and paas-secret
# This would be slower than fully local development but enables testing in conditions closer to production without requiring git push delays.
