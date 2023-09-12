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

printf "%s\n" "${YELLOW}Starting mass updates${NORMAL}";
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
    printf "%s\n" "${BRIGHT}    Navigating to $rp to run  mass updates${NORMAL}";    
    cd $rp;
    printf "%s\n" "${BRIGHT}    Running mass updates${NORMAL}";
    #Make sure yarn audit-fix exists
    ncu -u;
    yarn install
   
    cd $rpfolder
done
# Navigate back to the repository folder
printf "%s\n" "${WHITE}      Returning to repository folder $rpfolder${NORMAL}";
cd $rpfolder;
