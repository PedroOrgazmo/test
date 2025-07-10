#!/bin/bash

if [ "$(id -u)" != "0" ];
 then
	echo "u not root!"
	exit 1
fi

INTERFACE="wlan0"
SCAN_TIME=20
TMP_FILE="/tmp/wifi_scan"

rm -f "${TMP_FILE}"*

airmon-ng check kill >/dev/null
airmon-ng start $INTERFACE >/dev/null
MON_INTERFACE="${INTERFACE}mon"
echo "Scan ${SCAN_TIME} seconds..."

airodump-ng $MON_INTERFACE -w $TMP_FILE --output-format csv &

AIRODUMP_PID=$!
sleep $SCAN_TIME
kill -INT $AIRODUMP_PID
wait $AIRODUMP_PID
sleep 4

echo -e "\nresults in ${TMP_FILE}"

#Create list bssid essid available wifi
NETWORK_LIST=()
while IFS=, read -r bssid _ _ _ _ _ _ _ _ _ _ _ _ essid; do
	if [[ -z "$bssid" && "$essid" ]]; then
		break
	fi 
	bssid=$(echo "$bssid" | xargs)
	essid=$(echo "$essid" | xargs)
	if [[ $bssid =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && [ -n $essid ]; then
		NETWORK_LIST+=("$bssid" "$essid")
	fi
done < <(grep -E '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' "${TMP_FILE}-01.csv" )

if [ ${#NETWORK_LIST[@]} -eq 0 ]; then
	echo "No networks found!"
	airmon-ng stop $MON_INERFACE
	exit 1
fi

echo -e "\nAvailable networks"
printf "%-3s %-18s %s\n" "No" "MAC-address" "Name"
echo "------------------------------------"
for ((i=0; i<${#NETWORK_LIST[@]}; i+=2)); do
	printf "%-3d %-18s %s\n" "$((i/2+1))" "${NETWORK_LIST[i]}" "${NETWORK_LIST[i+1]::-1}" 
done

#Choice wifi + get bssid essid 
while true; do
	read -p $'\nNumber networks: ' num
	if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le $((${#NETWORK_LIST[@]}/2)) ]; then
		index_mac=$(( (num-1)*2 ))
		index_essid=$(( ${index_mac}+1 ))
#		echo "${NETWORK_LIST[index_essid]}"
      		SELECTED_MAC="${NETWORK_LIST[index_mac]}"
		SELECTED_ESSID="${NETWORK_LIST[index_essid]::-1}" 
		break
	else
		echo "($num) Incorrect!"
	fi
done

airmon-ng stop $MON_INTERFACE >/dev/null 

echo -e "\n BSSID - \033[1;32m${SELECTED_MAC}\033[0m \n ESSID - \033[1;32m${SELECTED_ESSID}\033[0m" #ANSI! 
#Hello git!
