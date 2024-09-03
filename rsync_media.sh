#!/bin/bash

PMSServer='000.000.000.000'
PMSPort='32400'
RemoteHost="user@domain.tld"
RemotePath="./Media/"
XPlexToken='REPLACEME'
localsync='/media/Media/'
logfile="/root/rsync_media.log"
rpid="/var/tmp/rsyncpid"
userint=""

SAVEIFS=$IFS;
IFS=$(echo -en "\n\b");

# Are we in an interactive shell or not?
if [ -t 1 ] ; then 
    userint="1"
fi

# Check if the pid file exists, if it doesn't NULL it with ###
if [ -e $rpid ]; then
	pid=$(cat $rpid)
else
	pid='###'
fi

# Does the PID process exist?
if [ ! -e /proc/$pid ]; then
        # Record the PID of this script so we don't run multiple at the same time
        echo $$ > $rpid

        # Verify the Destination is mounted
	if df -h ${localsync} | grep "$(echo ${localsync} | rev | cut -c 2- | rev)" > /dev/null; then
                # Are we in a shell or cron?
		if [ $userint ]; then
			rsync --remove-source-files --exclude=".*" -PrtDh --perms --chmod 755 --log-file=${logfile} ${RemoteHost}:${RemotePath} ${localsync}
		else
			rsync --remove-source-files --exclude=".*" -PrtDhq --perms --chmod 755 --log-file=${logfile} ${RemoteHost}:${RemotePath} ${localsync}
		fi

                # Scan TV If TV Detected
                if grep -q -e 'TV/' ${logfile}; then
                    for folder in `grep -e "TV/.*/$" ${logfile} | sed 's/^.*TV\///g' | sort | uniq | grep -e "/$" | sed 's/^/\/media\/Media\/TV\//g' | grep -i Season`; do
                        curl -s -G -H "X-Plex-Token: ${XPlexToken}" --data-urlencode "path=$folder" http://${PMSServer}:${PMSPort}/library/sections/5/refresh;
                    done;
                fi

                # Scan Movies If Movies Detected
                if grep -q -e 'Movies/' ${logfile}; then
                    for folder in `grep -e "Movies/.*/$" ${logfile} | sed 's/^.*Movies\///g' | sort | uniq | grep -e "/$" | sed 's/^/\/media\/Media\/Movies\//g'`; do
                        curl -s -G -H "X-Plex-Token: ${XPlexToken}" --data-urlencode "path=$folder" http://${PMSServer}:${PMSPort}/library/sections/7/refresh;
                    done;
                fi

                # python3 /root/torrents.py >> ${logfile}
                cat ${logfile} >> ${logfile}.full.log
		truncate --size 0 ${logfile}
	fi
else
	if [ $userint ]; then
		echo "process $pid running";
	fi
fi

IFS=$SAVEIFS;
