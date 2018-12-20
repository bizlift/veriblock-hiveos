#!/usr/bin/env bash

#######################
# Functions
#######################


get_cards_hashes(){
	# hs is global
	hs=''
	for (( i=0; i < ${GPU_COUNT_NVIDIA}; i++ )); do
		hs[$i]=0
	done
	local MHS=`cat $LOG_NAME | grep -a "GPU #" | tail -n 1 | awk 'match($0, /[0-9]+.[0-9]+ MH/) {print substr($0, RSTART, RLENGTH)}'|  cut -d " " -f1`
	hs[$GPU_ID]=`echo $MHS`
}

get_nvidia_cards_temp(){
	echo $(jq -c "[.temp$nvidia_indexes_array]" <<< $gpu_stats)
}

get_nvidia_cards_fan(){
	echo $(jq -c "[.fan$nvidia_indexes_array]" <<< $gpu_stats)
}

get_miner_uptime(){
	local tmp=$(ps -p `pgrep $CUSTOM_NAME` -o lstart=)
	local start=$(date +%s -d "$tmp")
        local now=$(date +%s)
        echo $((now - start))
}

get_total_hashes(){
        # khs is global
	local Total=`cat $LOG_NAME | grep -a " : " | tail -n 1 | awk 'match($0, /[0-9]+.[0-9]+ MH/) {print substr($0, RSTART, RLENGTH)}'|  cut -d " " -f1 |  awk '{printf $1*1000}'` 
        echo $Total
}

get_miner_shares_ac(){
	echo $(cat $LOG_NAME | grep -a "GPU #" | tail -n 1 | awk 'match($0, /shares: [0-9]+/) {print substr($0, RSTART, RLENGTH)}'| cut -d " " -f2)
}

get_miner_shares_rj(){
	local Shares=`cat $LOG_NAME | grep -a "GPU #" | tail -n 1 | awk 'match($0, /shares: [0-9]+\/[0-9]+/) {print substr($0, RSTART, RLENGTH)}' | cut -d " " -f2`
	local Accepted=`echo $Shares | cut -d "/" -f1`
	local TotalShares=`echo $Shares | cut -d "/" -f2`
	echo $((TotalShares - Accepted))
}


#######################
# MAIN script body
#######################

. /hive/miners/custom/$CUSTOM_MINER/h-manifest.conf
local LOG_NAME="$CUSTOM_LOG_BASENAME.log"

[[ -z $GPU_COUNT_NVIDIA ]] &&
	GPU_COUNT_NVIDIA=`gpu-detect NVIDIA`

local GPU_ID=`cat $CUSTOM_CONFIG_FILENAME | awk 'match($0, /-d [0-9]+/) {print substr($0, RSTART, RLENGTH)}'|  cut -d " " -f2`

# Calc log freshness
local diffTime=110
local maxDelay=120

# If log is fresh the calc miner stats or set to null if not
if [ "$diffTime" -lt "$maxDelay" ]; then
	local hs=
	get_cards_hashes			# hashes array
	local hs_units='mhs'			# hashes units
	local temp=$(get_nvidia_cards_temp)	# cards temp
	local fan=$(get_nvidia_cards_fan)	# cards fan
	local uptime=$(get_miner_uptime)	# miner uptime
	local algo="blake2b"			# algo

	# A/R shares by pool
	local ac=$(get_miner_shares_ac)
	local rj=$(get_miner_shares_rj)

	# make JSON
	stats=$(jq -nc \
				--argjson hs "`echo ${hs[@]} | tr " " "\n" | jq -cs '.'`" \
				--arg hs_units "$hs_units" \
				--argjson temp "$temp" \
				--argjson fan "$fan" \
				--arg uptime "$uptime" \
       				--arg ac "$ac" --arg rj "$rj" \
				--arg algo "$algo" \
                                '{$hs, $hs_units,  $temp, $fan, $uptime, ar: [$ac, $rj], algo: $algo}')
	# total hashrate in khs
	khs=$(get_total_hashes)
else
	stats=""
	khs=0
	echo stale
fi

# debug output


#echo gpu: $GPU_ID
#echo temp:  $temp
#echo fan:   $fan
#echo $stats | jq -c -M '.'
#echo khs:   $khs
#echo diff: $diffTime
#echo uptime: $uptime
