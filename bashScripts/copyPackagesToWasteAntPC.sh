#!/bin/bash

# this script has to run from inside "bluerovws" by: source bashScripts/copyROSPackagesToBlueROV.sh
# it copies the desired packages from your local setup to the pis. Ensure that ~/ros_ws/src exists on the pis

copyFolder1_ws () {
#  ssh wasteantadmin@$1 mkdir -p ~/ros_ws/src/$2
# --delete not used
  rsync -avh $2/ wasteantadmin@$1:/home/wasteantadmin/Constructor-Robotics/Tim/ros_ws/$2 --exclude=cmake-build-debug --exclude=build --exclude=.git --exclude=.idea --exclude=cmake-build-release
}
# wasteantadmin@10.60.41.51

#wasteantadmin Tube
IP_ADDRESS="10.60.41.51"


copyFolder1_ws "$IP_ADDRESS" ".devcontainer"
copyFolder1_ws "$IP_ADDRESS" "configFiles"




copyFolder1_ws "$IP_ADDRESS" "src/fsregistration"
copyFolder1_ws "$IP_ADDRESS" "src/soft20"

#copyFolder1_ws "$IP_ADDRESS" "src/registrationml"
#copyFolder1_ws "$IP_ADDRESS" "src/commonBlueROVMSG"


#copyFolder1_ws "$IP_ADDRESS" "cache"