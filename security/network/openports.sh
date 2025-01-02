#!/bin/bash
#
#


tCount=$(sudo lsof -i -P -n | grep LISTEN|wc -l);

notify-send -i $notifyIcon "Showing $OS_name open ports $tCount in total"
#nmap -sT 0 localhost;	

i=30;
function gotoSleep(){
  	
	#printf "Refresh in"
	while [ $i -ge 1 ]
	do
	
	echo -en "\rRefresh in: ${i}";
	sleep 1
	i=`expr $i - 1`
	done
	
}


while :
    do
        clear
        print_good "Showing $OS_name $tCount open ports:-";
        echo "";
        sudo lsof -i -P -n | grep LISTEN;
        echo "--------------------------------------------------------------------------------------------------";
        echo "";
        sudo netstat -tulpn | grep LISTEN
        echo "--------------------------------------------------------------------------------------------------";        
        gotoSleep;
        i=30;
done

#sudo netstat -tulpn | grep LISTEN
#sudo nmap -sTU -O IP-address-Here
echo "";
exit 1;






 






