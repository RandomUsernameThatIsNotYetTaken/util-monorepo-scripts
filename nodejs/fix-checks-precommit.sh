#!/bin/bash
#skip to line 75 for main logic
# how many folders to go up before giving up
declare -i retries=3;
# yarn commands to look for in package.json
yarnCommands=("audit:fix" "lint:fix" "test");

BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)
function ProgressBar {
# Process data
    let _progress=(${1}*100/${2}*100)/100
    let _done=(${_progress}*4)/10
    let _left=40-$_done
# Build progressbar string lengths
    _fill=$(printf "%${_done}s")
    _empty=$(printf "%${_left}s")

# 1.2 Build progressbar strings and print the ProgressBar line
# 1.2.1 Output example:                           
# 1.2.1.1 Progress : [########################################] 100%
printf "\r${WHITE}Progress: [$progressdone/$progresstotal] [${_fill// /#}${_empty// /-}] ${_progress}%%"

}
declare -i counter=0;

# create tmp log folder
tmpfolder=$(xxd -l 32 -c 32 -p < /dev/random | head -c 8);
tmpfolder=/tmp/fixchecksprecommit-$tmpfolder
echo "";
printf "%s\n" "${YELLOW}Creating temporary folder for logs: $tmpfolder ${NORMAL}";
echo "";
mkdir -p "$tmpfolder";

# Read command line flag called --git-repository
if [ $# -eq 0 ]; then
    printf "%s\n" "${RED}No arguments provided, please add git repository name as it is on your system${NORMAL}}";
    exit 1;
fi
# Find the repository folder
while [ $counter -le $retries ]; do
  if [ -d "../$1" ]; then
    rpfolder=$(realpath ../$1);
    printf "%s\n" "${GREEN}Current folder is repository folder: $rpfolder ${NORMAL}";
    found=true;	
    cd $rpfolder;
    counter=$retries;
    break;
  else
    rp=$(realpath ./);
    printf "%s\n" "${WHITE}Current folder: $rp ${NORMAL}";
    printf "%s\n" "${ORANGE}Could not find repository folder, going up a level (try $counter/$retries).${NORMAL}";
    cd ..;
    counter=$counter+1;
  fi
done
if [ "$found" != true ]; then
  printf "%s\n" "${RED}Could not find repository folder, we're not recursively going to scan your whole computer for it.${NORMAL}";
  exit 1;
fi

printf "%s\n" "${YELLOW}Starting Checks${NORMAL}";
printf "%s\n" "${YELLOW}*********Containers - YARN${NORMAL}";

# List all folders inside the repository that contain package.json
printf "%s\n" "${BRIGHT}  Searching package.json files${NORMAL}";
printf "%s\n" "${WHITE}  $(find $rpfolder -maxdepth 3 -type f -name "package.json") ${NORMAL}";
for package in $(find . -maxdepth 3 -type f -name "package.json"); do
    printf "%s\n" "${YELLOW}    Checking $(realpath $package) ${NORMAL}";
    rpjson=$(realpath $package);
    rp=$(realpath $(dirname  $package));
    mainfolder=$(basename $(dirname $(dirname $rpjson)));
    # Navigate to the code subfolder
    printf "%s\n" "${BRIGHT}    Navigating to $rp to run checks${NORMAL}";    
    cd $rp;
    printf "%s\n" "${BRIGHT}    Running checks${NORMAL}";
    # For each command in yarnCommands, check if it exists in package.json
    for command in "${yarnCommands[@]}"; do
        #if it does, run it. If not, print a message
        if grep -q "$command" "package.json"; then
            logfile=$tmpfolder/yarn-$mainfolder-$command.log
            logfile=$(echo "$logfile" | sed 's/:/_/g' );
            printf "%s\n" "${GREEN}        Found $command command in $package${NORMAL}";
            printf "%s\n" "${WHITE}        yarn $command${NORMAL} > $logfile ${NORMAL}";
            # Run the command in parallel and save the output to a log file
            yarn -s $command > $logfile  2>&1 &
        else
            printf "%s\n" "${ORANGE}        Could not find $command, skipping${NORMAL}";
        fi
    done
    cd $rpfolder
done
# Navigate back to the repository folder
printf "%s\n" "${WHITE}      Returning to repository folder $rpfolder${NORMAL}";
cd $rpfolder;

# Move to terraform folder and for each subfolder run terraform fmt
printf "%s\n" "${YELLOW}*********TERRAFORM ${NORMAL}";
cd terraform;
for folder in $(find . -maxdepth 1 -type d); do
    if [ "$folder" != "." ]; then
        printf "%s\n" "${WHITE}  Running terraform fmt in $folder${NORMAL}";
        logfile=$tmpfolder/terraform-$(basename $folder).log
        logfile=$(echo "$logfile" | sed 's/:/_/g' );
        printf "%s\n" "${WHITE}  terraform fmt${NORMAL} > $logfile ${NORMAL}";
        terraform fmt > $logfile  2>&1 &
    fi
done

# Wait for all subcommands to finish
printf "%s\n" "${YELLOW}  While you wait, logs can be found in: $tmpfolder ${NORMAL}";
echo ""
printf "%s\n" "${WHITE}  Waiting for all subcommands to finish:${NORMAL}";
echo ""
declare -i progresstotal=$(jobs -p | wc -w);
declare -i progressremaining=$(jobs -p | wc -w);
declare -i progressdone=$progresstotal-$progressremaining+1;
while [ $progressdone -lt $progresstotal ]; do
    progressremaining=$(jobs -p | wc -w);
    progressdone=$progresstotal-$progressremaining+1;
    ProgressBar $progressdone $progresstotal;
    sleep 1;
done
echo "";
# Check if any yarn commands failed
printf "%s\n" "${YELLOW}  Checking if any yarn commands failed ${NORMAL}";
yarnok=1
for logfile in $(find $tmpfolder -type f -name 'yarn-*'); do
    if grep -q "Error:" "$logfile"; then
        printf "%s\n" "${RED}    Found error in $logfile ${NORMAL}";
        cat $logfile;
        yarnok=0;
        exit 1;
    fi
done
if [ $yarnok -eq 1 ]; then
    printf "%s\n" "${GREEN}    Yarn output looks ok!${NORMAL}";
fi
echo "";
#check if any terraform commands failed
printf "%s\n" "${YELLOW}  Checking if any terraform commands failed ${NORMAL}";
terraformok=1
for logfile in $(find $tmpfolder -type f -name 'terraform-*'); do
    if grep -q "Error:" "$logfile"; then
        printf "%s\n" "${RED}    Found error in $logfile ${NORMAL}";
        cat $logfile;
        terraformok=0;
        exit 1;
    fi
done
if [ $terraformok -eq 1 ]; then
    printf "%s\n" "${GREEN}    Terraform output looks ok!${NORMAL}";
fi
echo "";
printf "%s\n" "${BRIGHT}${YELLOW}   Check Git Status for changes${NORMAL}";
printf "%s\n" "${BRIGHT}${YELLOW}   Script will not commit these for yous${NORMAL}";
git status
