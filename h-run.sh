#!/usr/bin/env bash

export LD_LIBRARY_PATH=/hive/lib

cd `dirname $0`

[ -t 1 ] && . colors

. h-manifest.conf

[[ -z $CUSTOM_LOG_BASENAME ]] && echo -e "${RED}No CUSTOM_LOG_BASENAME is set${NOCOLOR}" && exit 1
[[ -z $CUSTOM_CONFIG_FILENAME ]] && echo -e "${RED}No CUSTOM_CONFIG_FILENAME is set${NOCOLOR}" && exit 1
[[ ! -f $CUSTOM_CONFIG_FILENAME ]] && echo -e "${RED}Custom config ${YELLOW}$CUSTOM_CONFIG_FILENAME${RED} is not found${NOCOLOR}" && exit 1
CUSTOM_LOG_BASEDIR=`dirname "$CUSTOM_LOG_BASENAME"`
[[ ! -d $CUSTOM_LOG_BASEDIR ]] && mkdir -p $CUSTOM_LOG_BASEDIR



conf1="$(cat /hive/miners/custom/$CUSTOM_NAME/$CUSTOM_NAME.conf)"
devices="$(echo $conf1 | awk 'match($0,/-d [0-9]+(\,[0-9]+)+?/) {print substr($0, RSTART, RLENGTH)}')"
device_string="$(echo $devices | cut -d " " -f2)"
device_array=(`echo $device_string | sed 's/,/\n/g'`)

counter=0
for i in "${device_array[@]}"
do
  if (($counter > 0))
then
    device_conf="${conf1/$devices/-d $i}"
    echo "/hive/miners/custom/$CUSTOM_NAME/veriblock-pow $device_conf | tee $CUSTOM_LOG_BASENAME.$i.log" > /hive/miners/custom/$CUSTOM_NAME/$CUSTOM_NAME.$i.sh
    chmod a+x /hive/miners/custom/$CUSTOM_NAME/$CUSTOM_NAME.$i.sh	
    sleep 1
    screen -X screen -t VERIBLOCK-$i /hive/miners/custom/$CUSTOM_NAME/$CUSTOM_NAME.$i.sh
fi    
    let counter=counter+1
done
first_device=${device_array[0]}
device_conf="${conf1/$devices/-d $first_device}"
./veriblock-pow $(echo $device_conf) | tee $CUSTOM_LOG_BASENAME".0.log"

