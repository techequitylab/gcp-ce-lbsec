#!/bin/bash
# 
# Copyright 2019-2021 Shiyghan Navti. Email shiyghan@techequity.company
#
#################################################################################
#############       Explore Load Balancing with Cloud Armor       ###############
#################################################################################

function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}


function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-ce-lbsec
export PROJDIR=`pwd`/gcp-ce-lbsec
export SCRIPTNAME=gcp-ce-lbsec.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=us-west2
export GCP_ZONE=us-west2-a
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
======================================================================
Configure HTTPs Load Balancing and Cloud Armor  
----------------------------------------------------------------------
Please enter number to select your choice:
 (1) Enable APIs
 (2) Create compute engine firewall rule
 (3) Create template and managed instance group 
 (4) Configure name port 
 (5) Configure basic healthcheck and backend services
 (6) Add backend services to instance groups and configure scaling
 (7) Configure URL map and target http proxy
 (8) Configure forwarding rules
 (9) Configure load balancer firewall rule
(10) Load test instances using the load balancer
(11) Configure security policy
(12) Configure managed SSL certificate
 (G) Launch user guide
 (Q) Quit
----------------------------------------------------------------------

EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud services enable compute.googleapis.com # to enable compute APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    echo
    echo "$ gcloud services enable compute.googleapis.com # to enable compute APIs" | pv -qL 100
    gcloud services enable compute.googleapis.com
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"
    echo
    echo "$ gcloud compute firewall-rules create glbsec-allow-http --network default --source-ranges 0.0.0.0/0 --allow tcp:80 --target-tags http-server # to create HTTP firewall rule" | pv -qL 100
    echo
    echo "$ gcloud compute firewall-rules create glbsec-allow-ssh --network default --source-ranges 0.0.0.0/0 --allow tcp:22 --target-tags http-server # to create SSH firewall rule" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"
    echo
    echo "$ gcloud compute firewall-rules create glbsec-allow-http --network default --source-ranges 0.0.0.0/0 --allow tcp:80 --target-tags http-server # to create HTTP firewall rule" | pv -qL 100
    gcloud compute firewall-rules create glbsec-allow-http --network default --source-ranges 0.0.0.0/0 --allow tcp:80 --target-tags http-server
    echo
    echo "$ gcloud compute firewall-rules create glbsec-allow-ssh --network default --source-ranges 0.0.0.0/0 --allow tcp:22 --target-tags http-server # to create HTTP firewall rule" | pv -qL 100
    gcloud compute firewall-rules create glbsec-allow-ssh --network default --source-ranges 0.0.0.0/0 --allow tcp:22 --target-tags http-server
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"
    echo
    echo "$ gcloud compute firewall-rules delete glbsec-allow-http # to delete HTTP firewall rule" | pv -qL 100
    gcloud compute firewall-rules delete glbsec-allow-http
    echo
    echo "$ gcloud compute firewall-rules delete glbsec-allow-ssh # to delete HTTP firewall rule" | pv -qL 100
    gcloud compute firewall-rules delete glbsec-allow-ssh
else
    export STEP="${STEP},2i"
    echo
    echo "1. Create HTTP firewall rule" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo
    echo "$ gcloud compute instance-templates create glbsec-us-east1-template --region us-east1 --network default --tags http-server --metadata startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh # to create template" | pv -qL 100
    echo
    echo "$ gcloud beta compute instance-groups managed create glbsec-us-east1-mig --template glbsec-us-east1-template --region us-east1 --size 1 # to create managed instance group" | pv -qL 100
    echo
    echo "$ gcloud beta compute instance-groups managed set-autoscaling glbsec-us-east1-mig --region us-east1 --cool-down-period 45 --max-num-replicas 5 --min-num-replicas 1 --target-cpu-utilization 0.8 # to configure autoscaling" | pv -qL 100
    echo
    echo "$ gcloud compute instance-templates create glbsec-europe-west1-template --region europe-west1 --network default --tags http-server --metadata startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh # to create template" | pv -qL 100
    echo
    echo "$ gcloud beta compute instance-groups managed create glbsec-europe-west1-mig --template glbsec-europe-west1-template --region europe-west1 --size 1 # to create managed instance group" | pv -qL 100
    echo
    echo "$ gcloud beta compute instance-groups managed set-autoscaling glbsec-europe-west1-mig --region europe-west1 --cool-down-period 45 --max-num-replicas 5 --min-num-replicas 1 --target-cpu-utilization 0.8 # to configure autoscaling"  | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"
    echo
    echo "$ gcloud compute instance-templates create glbsec-us-east1-template --region us-east1 --network default --tags http-server --metadata startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh # to create template" | pv -qL 100
    gcloud compute instance-templates create glbsec-us-east1-template --region us-east1 --network default --tags http-server --metadata startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh
    echo
    echo "$ gcloud beta compute instance-groups managed create glbsec-us-east1-mig --template glbsec-us-east1-template --region us-east1 --size 1 # to create managed instance group" | pv -qL 100
    gcloud beta compute instance-groups managed create glbsec-us-east1-mig --template glbsec-us-east1-template --region us-east1 --size 1
    echo
    echo "$ gcloud beta compute instance-groups managed set-autoscaling glbsec-us-east1-mig --region us-east1 --cool-down-period 45 --max-num-replicas 5 --min-num-replicas 1 --target-cpu-utilization 0.8 # to configure autoscaling" | pv -qL 100
    echo
    echo "$ gcloud compute instance-templates create glbsec-europe-west1-template --region europe-west1 --network default --tags http-server --metadata startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh # to create template" | pv -qL 100
    gcloud compute instance-templates create glbsec-europe-west1-template --region europe-west1 --network default --tags http-server --metadata startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh
    echo
    echo "$ gcloud beta compute instance-groups managed create glbsec-europe-west1-mig --template glbsec-europe-west1-template --region europe-west1 --size 1 # to create managed instance group" | pv -qL 100
    gcloud beta compute instance-groups managed create glbsec-europe-west1-mig --template glbsec-europe-west1-template --region europe-west1 --size 1
    echo
    echo "$ gcloud beta compute instance-groups managed set-autoscaling glbsec-europe-west1-mig --region europe-west1 --cool-down-period 45 --max-num-replicas 5 --min-num-replicas 1 --target-cpu-utilization 0.8 # to configure autoscaling" | pv -qL 100
    gcloud beta compute instance-groups managed set-autoscaling glbsec-europe-west1-mig --region europe-west1 --cool-down-period 45 --max-num-replicas 5 --min-num-replicas 1 --target-cpu-utilization 0.8
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"
    echo
    echo "$ gcloud beta compute instance-groups managed delete glbsec-europe-west1-mig --region europe-west1 # to delete managed instance group" | pv -qL 100
    gcloud beta compute instance-groups managed delete glbsec-europe-west1-mig --region europe-west1
    echo
    echo "$ gcloud compute instance-templates delete glbsec-europe-west1-template  # to delete template" | pv -qL 100
    gcloud compute instance-templates delete glbsec-europe-west1-template
    echo
    echo "$ gcloud beta compute instance-groups managed delete glbsec-us-east1-mig --region us-east1 # to delete managed instance group" | pv -qL 100
    gcloud beta compute instance-groups managed delete glbsec-us-east1-mig --region us-east1
    echo
    echo "$ gcloud compute instance-templates delete glbsec-us-east1-template # to delete template" | pv -qL 100
    gcloud compute instance-templates delete glbsec-us-east1-template
else
    export STEP="${STEP},3i"
    echo
    echo "1. Configure instance template" | pv -qL 100
    echo "2. Configure managed instance groups" | pv -qL 100
    echo "3. Set autoscalng" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"
    echo
    echo "$ gcloud compute instance-groups managed set-named-ports glbsec-us-east1-mig --named-ports http:80 --region us-east1 # to set port" | pv -qL 100
    echo
    echo "$ gcloud compute instance-groups managed set-named-ports glbsec-europe-west1-mig --named-ports http:80 --region europe-west1 # to set port" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"
    echo
    echo "$ gcloud compute instance-groups managed set-named-ports glbsec-us-east1-mig --named-ports http:80 --region us-east1 # to set port" | pv -qL 100
    gcloud compute instance-groups managed set-named-ports glbsec-us-east1-mig --named-ports http:80 --region us-east1
    echo
    echo "$ gcloud compute instance-groups managed set-named-ports glbsec-europe-west1-mig --named-ports http:80 --region europe-west1 # to set port" | pv -qL 100
    gcloud compute instance-groups managed set-named-ports glbsec-europe-west1-mig --named-ports http:80 --region europe-west1
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},4i"
    echo
    echo "1. Set port" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"
    echo
    echo "$ gcloud compute health-checks create http glbsec-http-health-check --port 80 # to create healthcheck" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services create glbsec-http-backend --protocol HTTP --health-checks glbsec-http-health-check --global # to create backend service" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    echo
    echo "$ gcloud compute health-checks create http glbsec-http-health-check --port 80 # to create healthcheck" | pv -qL 100
    gcloud compute health-checks create http glbsec-http-health-check --port 80
    echo
    echo "$ gcloud compute backend-services create glbsec-http-backend --protocol HTTP --health-checks glbsec-http-health-check --global # to create backend service" | pv -qL 100
    gcloud compute backend-services create glbsec-http-backend --protocol HTTP --health-checks glbsec-http-health-check --global
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    echo
    echo "$ gcloud compute backend-services delete glbsec-http-backend --global # to delete backend service" | pv -qL 100
    gcloud compute backend-services delete glbsec-http-backend --global
    echo
    echo "$ gcloud compute security-policies delete glbsec-denylist-siege" | pv -qL 100
    gcloud compute security-policies delete glbsec-denylist-siege
else
    export STEP="${STEP},5i"
    echo
    echo "1. Create healthcheck" | pv -qL 100
    echo "2. Create backend service" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"
    echo
    echo "$ gcloud compute backend-services add-backend glbsec-http-backend --balancing-mode RATE --max-rate-per-instance 50 --capacity-scaler 1.0 --instance-group glbsec-us-east1-mig --instance-group-region us-east1 --global # to create backend services" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services add-backend glbsec-http-backend --balancing-mode RATE --max-rate-per-instance 50 --capacity-scaler 1.0 --instance-group glbsec-europe-west1-mig --instance-group-region europe-west1 --global # to create backend services" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"
    echo
    echo "$ gcloud compute backend-services add-backend glbsec-http-backend --balancing-mode RATE --max-rate-per-instance 50 --capacity-scaler 1.0 --instance-group glbsec-us-east1-mig --instance-group-region us-east1 --global # to create backend services" | pv -qL 100
    gcloud compute backend-services add-backend glbsec-http-backend --balancing-mode RATE --max-rate-per-instance 50 --capacity-scaler 1.0 --instance-group glbsec-us-east1-mig --instance-group-region us-east1 --global
    echo
    echo "$ gcloud compute backend-services add-backend glbsec-http-backend --balancing-mode RATE --max-rate-per-instance 50 --capacity-scaler 1.0 --instance-group glbsec-europe-west1-mig --instance-group-region europe-west1 --global # to create backend services" | pv -qL 100
    gcloud compute backend-services add-backend glbsec-http-backend --balancing-mode RATE --max-rate-per-instance 50 --capacity-scaler 1.0 --instance-group glbsec-europe-west1-mig --instance-group-region europe-west1 --global
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},6i"
    echo
    echo "1. Create backend services" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"7")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},7i"
    echo
    echo "$ gcloud compute url-maps create glbsec-url-map --default-service glbsec-http-backend # to create URL maps" | pv -qL 100
    echo
    echo "$ gcloud compute url-maps add-path-matcher glbsec-url-map --path-matcher-name glbsec-url-map-path --default-service glbsec-http-backend --path-rules=\"/=glbsec-http-backend\" # to add a path matcher to URL map" | pv -qL 100
    echo
    echo "$ gcloud compute target-http-proxies create glbsec-target-http-proxy --url-map glbsec-url-map # to create a target HTTP proxy to route requests to URL map" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"
    echo
    echo "$ gcloud compute url-maps create glbsec-url-map --default-service glbsec-http-backend # to create URL maps" | pv -qL 100
    gcloud compute url-maps create glbsec-url-map --default-service glbsec-http-backend
    echo
    echo "$ gcloud compute url-maps add-path-matcher glbsec-url-map --path-matcher-name glbsec-url-map-path --default-service glbsec-http-backend --path-rules=\"/=glbsec-http-backend\" # to add a path matcher to URL map" | pv -qL 100
    gcloud compute url-maps add-path-matcher glbsec-url-map --path-matcher-name glbsec-url-map-path --default-service glbsec-http-backend --path-rules="/=glbsec-http-backend"
    echo
    echo "$ gcloud compute target-http-proxies create glbsec-target-http-proxy --url-map glbsec-url-map # to create a target HTTP proxy to route requests to URL map" | pv -qL 100
    gcloud compute target-http-proxies create glbsec-target-http-proxy --url-map glbsec-url-map
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},7x"
    echo
    echo "$ gcloud compute target-http-proxies delete glbsec-target-http-proxy # to delete a target HTTP proxy to route requests to URL map" | pv -qL 100
    gcloud compute target-http-proxies delete glbsec-target-http-proxy
    echo
    echo "$ gcloud compute url-maps delete glbsec-url-map # to delete URL maps" | pv -qL 100
    gcloud compute url-maps delete glbsec-url-map
else
    export STEP="${STEP},7i"
    echo
    echo "1. Create URL maps" | pv -qL 100
    echo "2. Add path matcher to URL map" | pv -qL 100
    echo "3. Create a target HTTP proxy to route requests to URL map" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"8")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},8i"
    echo
    echo "$ gcloud compute addresses create glbsec-ipv4-address --ip-version IPV4 --global # to create static IPV4 address" | pv -qL 100
    echo
    echo "$ gcloud compute forwarding-rules create glbsec-forwarding-rule-ipv4 --address \$IPV4 --global --target-http-proxy glbsec-target-http-proxy --ports 80 # to create IPV4 global forwarding rule" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},8"
    echo
    echo "$ gcloud compute addresses create glbsec-ipv4-address --ip-version IPV4 --global # to create static IPV4 address" | pv -qL 100
    gcloud compute addresses create glbsec-ipv4-address --ip-version IPV4 --global
    export IPV4=$(gcloud compute addresses list --format='value(ADDRESS)' --filter='name:glbsec-ipv4-address')
    echo
    echo "$ gcloud compute forwarding-rules create glbsec-forwarding-rule-ipv4 --address $IPV4 --global --target-http-proxy glbsec-target-http-proxy --ports 80 # to create IPV4 global forwarding rule" | pv -qL 100
    gcloud compute forwarding-rules create glbsec-forwarding-rule-ipv4 --address $IPV4 --global --target-http-proxy glbsec-target-http-proxy --ports 80
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},8x"
    echo
    echo "$ gcloud compute forwarding-rules delete glbsec-forwarding-rule-ipv4 --global # to delete IPV4 global forwarding rule" | pv -qL 100
    gcloud compute forwarding-rules delete glbsec-forwarding-rule-ipv4 --global
    echo
    echo "$ gcloud compute addresses delete glbsec-ipv4-address --global # to delete static IPV4 address" | pv -qL 100
    gcloud compute addresses delete glbsec-ipv4-address --global
else
    export STEP="${STEP},8i"
    echo
    echo "1. Create static IPV4 address" | pv -qL 100
    echo "2. Create IPV4 global forwarding rule" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"9")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},9i"
    echo
    echo "$ gcloud compute firewall-rules create glbsec-allow-health-check --network default --source-ranges 130.211.0.0/22,35.191.0.0/16 --allow tcp:80 --target-tags http-server # to create health check firewall rules" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},9"
    echo
    echo "$ gcloud compute firewall-rules create glbsec-allow-health-check --network default --source-ranges 130.211.0.0/22,35.191.0.0/16 --allow tcp:80 --target-tags http-server # to create health check firewall rules" | pv -qL 100
    gcloud compute firewall-rules create glbsec-allow-health-check --network default --source-ranges 130.211.0.0/22,35.191.0.0/16 --allow tcp:80 --target-tags http-server
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},9x"
    echo
    echo "$ gcloud compute firewall-rules delete glbsec-allow-health-check # to delete health check firewall rules" | pv -qL 100
    gcloud compute firewall-rules delete glbsec-allow-health-check 
else
    export STEP="${STEP},9i"
    echo
    echo "1. Create health check firewall rules" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"10")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},10i"
    echo
    echo "$ gcloud compute instances create glbsec-siege-vm --network default --zone us-west1-c --provisioning-model=SPOT # to create siege load testing instance" | pv -qL 100
    echo
    echo "$ gcloud compute ssh --quiet --zone us-west1-c glbsec-siege-vm --command=\"sudo apt-get -y install siege\" # to install siege" | pv -qL 100
    echo
    echo "$ gcloud compute ssh --quiet --zone us-west1-c glbsec-siege-vm --command=\"siege -c 250 http://\$IPV4\" & # to load test with siege" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},10"
    export IPV4=$(gcloud compute addresses list --format='value(ADDRESS)' --filter='name:glbsec-ipv4-address') > /dev/null 2>&1
    echo
    echo "$ gcloud compute instances create glbsec-siege-vm --network default --zone us-west1-c --provisioning-model=SPOT # to create siege load testing instance" | pv -qL 100
    gcloud compute instances create glbsec-siege-vm --network default --zone us-west1-c --provisioning-model=SPOT
    echo
    sleep 60
    echo "$ gcloud compute ssh --quiet --zone us-west1-c glbsec-siege-vm --command=\"sudo apt-get -y install siege\" # to install siege" | pv -qL 100
    gcloud compute ssh --quiet --zone us-west1-c glbsec-siege-vm --command="sudo apt-get -y install siege"
    echo
    echo "$ gcloud compute ssh --quiet --zone us-west1-c glbsec-siege-vm --command=\"siege -c 250 http://$IPV4\" & # to load test with siege" | pv -qL 100
    gcloud compute ssh --quiet --zone us-west1-c glbsec-siege-vm --command="siege -c 250 http://$IPV4"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},10"
    echo
    echo "$ gcloud compute instances delete glbsec-siege-vm --zone us-west1-c # to delete siege load testing instance" | pv -qL 100
    gcloud compute instances delete glbsec-siege-vm --zone us-west1-c
else
    export STEP="${STEP},10i"
    echo
    echo "1. Create siege load testing instance" | pv -qL 100
    echo "2. Install siege" | pv -qL 100
    echo "3. Load test with siege" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"11")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},11i"
    echo
    echo "$ gcloud compute security-policies create glbsec-denylist-siege" | pv -qL 100
    echo
    echo "$ gcloud compute security-policies rules create 1000 --action deny-403 --security-policy glbsec-denylist-siege --src-ip-ranges \$IPV4" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services update glbsec-http-backend --security-policy=glbsec-denylist-siege --global" | pv -qL 100
    echo
    echo "$ gcloud compute ssh --quiet --zone us-west1-c glbsec-siege-vm --command=\"curl http://\$IPV4\" # to request endpoint" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},11"
    export IPV4=$(gcloud compute addresses list --format='value(ADDRESS)' --filter='name:glbsec-ipv4-address') > /dev/null 2>&1
    echo
    echo "$ gcloud compute security-policies create glbsec-denylist-siege" | pv -qL 100
    gcloud compute security-policies create glbsec-denylist-siege
    echo
    echo "$ gcloud compute security-policies rules create 1000 --action deny-403 --security-policy glbsec-denylist-siege --src-ip-ranges $IPV4" | pv -qL 100
    gcloud compute security-policies rules create 1000 --action deny-403 --security-policy glbsec-denylist-siege --src-ip-ranges $IPV4
    echo
    echo "$ gcloud compute backend-services update glbsec-http-backend --security-policy=glbsec-denylist-siege --global" | pv -qL 100
    gcloud compute backend-services update glbsec-http-backend --security-policy=glbsec-denylist-siege --global
    echo
    echo "$ export IPV4=\$(gcloud compute instances describe glbsec-siege-vm --zone us-west1-c --format=text  | grep '^networkInterfaces\[[0-9]\+\]\.accessConfigs\[[0-9]\+\]\.natIP:' | sed 's/^.* //g' 2>&1) # to set IP" | pv -qL 100
    export IPV4=$(gcloud compute instances describe glbsec-siege-vm --zone us-west1-c --format=text  | grep '^networkInterfaces\[[0-9]\+\]\.accessConfigs\[[0-9]\+\]\.natIP:' | sed 's/^.* //g' 2>&1)
    echo
    echo "$ gcloud compute ssh --quiet --zone us-west1-c glbsec-siege-vm --command=\"curl http://$IPV4\" # to request endpoint" | pv -qL 100
    gcloud compute ssh --quiet --zone us-west1-c glbsec-siege-vm --command="curl http://$IPV4"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},11x"
    echo
    echo "$ gcloud compute security-policies rules delete 1000 --security-policy glbsec-denylist-siege # to delete rules" | pv -qL 100
    gcloud compute security-policies rules delete 1000 --security-policy glbsec-denylist-siege
else
    export STEP="${STEP},11i"
    echo
    echo "1. Create security policies" | pv -qL 100
    echo "2. Create security policies rules" | pv -qL 100
    echo "3. Add security policy to backend service" | pv -qL 100
    echo "4. Invoke endpoint" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"12")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},12i"
    echo
    echo "$ gcloud compute ssl-certificates create glbsec-ssl-cert --domains=\$IPV4.nip.io --global # to create a global Google-managed SSL certificate" | pv -qL 100
    echo
    echo "$ gcloud compute target-https-proxies create glbsec-target-https-proxy --url-map glbsec-url-map --ssl-certificates glbsec-ssl-cert --global-ssl-certificates --global # to associate SSL certificate with target HTTPS proxy" | pv -qL 100
    echo
    echo "$ gcloud compute forwarding-rules create glbsec-https-forwarding-rule-ipv4 --address \$IPV4 --global --target-https-proxy glbsec-target-https-proxy --ports 443 # to create IPV4 global forwarding rule" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},12"
    export IPV4=$(gcloud compute addresses list --format='value(ADDRESS)' --filter='name:glbsec-ipv4-address')
    echo
    echo "$ gcloud compute ssl-certificates create glbsec-ssl-cert --domains=$IPV4.nip.io --global # to create a global Google-managed SSL certificate" | pv -qL 100
    gcloud compute ssl-certificates create glbsec-ssl-cert --domains=$IPV4.nip.io --global
    echo
    echo "$ gcloud compute target-https-proxies create glbsec-target-https-proxy --url-map glbsec-url-map --ssl-certificates glbsec-ssl-cert --global-ssl-certificates --global # to associate SSL certificate with target HTTPS proxy" | pv -qL 100
    gcloud compute target-https-proxies create glbsec-target-https-proxy --url-map glbsec-url-map --ssl-certificates glbsec-ssl-cert --global-ssl-certificates --global
    echo
    echo "$ gcloud compute forwarding-rules create glbsec-https-forwarding-rule-ipv4 --address $IPV4 --global --target-https-proxy glbsec-target-https-proxy --ports 443 # to create IPV4 global forwarding rule" | pv -qL 100
    gcloud compute forwarding-rules create glbsec-https-forwarding-rule-ipv4 --address $IPV4 --global --target-https-proxy glbsec-target-https-proxy --ports 443
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},12x"
    echo
    echo "$ gcloud compute forwarding-rules delete glbsec-https-forwarding-rule-ipv4 --global # to delete IPV4 global forwarding rule" | pv -qL 100
    gcloud compute forwarding-rules delete glbsec-https-forwarding-rule-ipv4 --global 
    echo
    echo "$ gcloud compute target-https-proxies delete glbsec-target-https-proxy --global # to associate SSL certificate with target HTTPS proxy" | pv -qL 100
    gcloud compute target-https-proxies delete glbsec-target-https-proxy --global
    echo
    echo "$ gcloud compute ssl-certificates delete glbsec-ssl-cert --global # to delete global Google-managed SSL certificate" | pv -qL 100
    gcloud compute ssl-certificates delete glbsec-ssl-cert --global
else
    export STEP="${STEP},12i"
    echo
    echo "1. Create global Google-managed SSL certificate" | pv -qL 100
    echo "2. Associate SSL certificate with target HTTPS proxy" | pv -qL 100
    echo "3. Create IPV4 global forwarding rule" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
