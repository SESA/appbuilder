IP=ip
SSH=ssh
SCP=scp

function myIPS()
{
    local line
    ${IP} a | while read line; do
	if [[ $line =~ .*inet\ (.*)\ brd.* ]]; then
	    echo ${BASH_REMATCH[1]%%/*};
	fi
    done
}

function myMACS()
{
    local line
    ${IP} a | while read line; do
	if [[ $line =~ .*link/ether\ (.*)\ brd.* ]]; then
	    echo ${BASH_REMATCH[1]%%/*};
	fi
    done
}

function MAC2Interface()
{
#    set -x
    local mac=$1
    local line
    local i
    local iface
    local mac
    local info
    
    ${IP} link | while read line; do
	if [[ $line =~ ^([0-9]+):\ ([^\ ]+):\.* ]]; then
	    i=${BASH_REMATCH[1]}; iface=${BASH_REMATCH[2]};
	    if ${IP} link show $iface &> /dev/null; then
		${IP} link show $iface | while read line; do
		    if [[ $line =~ .*link/ether\ (.*)\ brd.* ]]; then
			devmac=${BASH_REMATCH[1]%%/*};
			if [[ -z $mac ]]; then
			    echo $iface $devmac
			elif [[ $mac == $devmac ]]; then
			    echo $iface
			fi
		    fi
		done
	    fi
	fi
    done
#    set +x
}

function myNetClass()
{
    echo ${APP_MYIP##*/}
}

function myIP()
{
    local myip=${APP_MYIP%%/*}
    
    if [[ -z $myip ]]; then
	local addrs=( $(myIPS) )
	myip=${addrs[0]}
    fi
    [[ -z $myip ]] && myip=NOIP
    echo ${myip}
}

function myMAC()
{
    local mymac=${APP_MYMAC}
    local macs=( $(myMACS) )
    
    mymac=${macs[0]}
    echo ${mymac}
}

function myNode()
{
    local mynode=${APP_MYNODE}
    if [[ -z $mynode ]]; then
	mynode=$(myMAC)
	mynode=${mynode//:/_}
    fi
    [[ -z $mynode ]] && mynode=NONODE
    echo ${mynode}
}

function myCtlUser()
{
    echo ${APP_CTLUSER}
}

function myCtlServer()
{
    echo ${APP_CTLSERVER}
}

function myCtlDir()
{
    echo ${APP_CTLDIR}
}

function myCtlId()
{
    local mynode=$(myNode)
    local myip=$(myIP)
    echo "${mynode}-${myip}"
}

function myCtlFile()
{
    local host=$(myCtlServer)
    local dir=$(myCtlDir)
    local file=${APP_CTLFILE}
    
    [[ -z $file ]] && file="$(myCtlId).out"

    if [[ -z $host ]]; then
	if [[ -z $dir ]]; then
	    echo "$file"
	else
	    echo "${dir}/$file"
	fi
    else 
	if [[ -z $dir ]]; then
	    echo "$host:$file"
	else
	    echo "$host:${dir}/$file"
	fi
    fi
}

function ctlIfaceDown()
{
    local mymac=$(myMAC)
    local iface=$(MAC2Interface $mymac)
    ${IP} link set $iface down
}

function ctlIfaceUp()
{
    local mymac=$(myMAC)
    local iface=$(MAC2Interface $mymac)
    local myip=$(myIP)
    local mynetclass=$(myNetClass)
    
    ${IP} addr flush $iface
   # make X configurable
    ${IP} addr add ${myip}/${mynetclass} dev $iface
    ${IP} link set $iface up
}

function rendezvous()
{
#   set -x
   local src=$1
   local dst=$2
   local myip=$3
   local mynode=$4
   
   [[ -z $myip ]] && myip=$(myIP)
   [[ -z $mynode ]] && mynode=$(myNode)  

   if [[ -z ${dst} ]]; then
       dst=$(myCtlFile)
       local ctluser=$(myCtlUser)
        [[ -n $ctluser ]] && dst=${ctluser}@${dst}
   fi

   local sshhost=${dst%%:*}
   local sshfile=${dst##*:}

   if [[ $sshhost == $sshfile ]]; then
       echo "ERROR: rendezvous could not determine a destination" > /dev/stderr
       return -1
   fi

   # retry up to 5 times if the transfer fails
   for (( i=0; i<5; i++ )); do
       if [[ -n $src && -e $src ]]; then
	   ${SCP} $src $dst
       else
	   [[ -z $src ]] && src="READY"
	   echo "$mynode : $myip : $src" | ${SSH} $sshhost "/bin/cat >> $sshfile"
       fi
       # if rendezvous worked then quit esle retry 
       (( $? == 0 )) && break;
   done
#   set +x
   return 0
}

function saveResults()
{
    local myid=$(myCtlId)
    local sshhost=$(myCtlServer)
    local ctluser=$(myCtlUser)
    [[ -n $ctluser ]] && sshhost=${ctluser}@${sshhost}
    local sshdir=$(myCtlDir)/${myid}

    local dst=${sshhost}:${sshdir}

    
    if (( $# == 0 )); then
	results=${APP_DIR}
    fi

    ${SSH} $sshhost "/bin/mkdir -p $sshdir"
    for item in $results "$@"; do
	if [[ -d $item ]]; then
	    if ! ${SCP} -r $item $dst; then
		echo "ERROR: failed to copy $ITEM to $dst" >> /dev/stderr
	    fi
	elif [[ -f $item ]]; then
	    if ! ${SCP} $item $dst; then
		echo "ERROR: failed to copy $ITEM to $dst" >> /dev/stderr
	    fi	
	else
	    echo "$item" | ${SSH} $sshhost "/bin/cat >> $sshdir/extra"
	    if (( $? != 0 )); then
		echo "ERROR: failed to save $ITEM to $sshdir/extra"
	    fi
	fi
    done
}
		
