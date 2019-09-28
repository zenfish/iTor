
#
# fire up tor docker container, create an ipctl conf file for docker tor stuff, and rock 'n' roll
#

# container name
dtor_name="rdsubhas/tor-privoxy-alpine"

# web proxy = 8118
# sox = 9050
dtor_web_outside="8118"
dtor_web_inside="8118"
dtor_sox_outside="9050"
dtor_sox_inside="9050"

pfctl_to_docker="5080"
tor_server=localhost    # where docker opens the tor port


# is it already running?
# docker ps -a
# CONTAINER ID        IMAGE               COMMAND                  CREATED              STATUS              PORTS                                            NAMES
# 807f68d6c687        zdock-tor           "tini"                   4 seconds ago        Up 2 seconds        0.0.0.0:8118->8118/tcp, 0.0.0.0:9050->9050/tcp   vigorous_leavitt

did=$(docker ps -a | awk '$2~"'"$dtor_name"'" && / Up/ { print $1; exit }')

# drez=$(docker inspect -f {{.State.Running}} "$dtor_name" true)

if [ ! -z "$did" ]; then
    echo "Container is already running!  Bailing out...."
    exit 7
fi

# die die die on errz... have to do it after the above! :)
set -e

echo trying to start the Tor Docker container...

did=$(docker run -d -p $dtor_web_outside:$dtor_web_outside -p $dtor_sox_outside:$dtor_sox_inside "$dtor_name")

if ! docker top $did &> /dev/null; then
    echo "Error starting the Tor Docker container"
    exit 6
fi

#
# save some typing
#
function errz () {

    problem=$1
    var=$1

    if [ -z "$var" ] ; then
        echo "$problem needs to be set"
        exit 3
    fi
}

#
# Next: figure out the IP addr, interface, CIDR block, and loopback...
#

#
# try to determine who talks to the 'net
#
# if this doesn't work you can manually set (e.g. "INTERFACE=en0" or whatever)
#
INTERFACE=$(netstat -rn|awk '/default/ && ! /::/ { print $NF; exit}')

errz "The interface to the internet" $INTERFACE

# find the HW interface name associated with the interface we're using
HW=$(networksetup -listallhardwareports | awk '/Port/ { split($0, p, ":"); hw = p[2] } /Device/ { if ($2 == "'"$INTERFACE"'") print hw }' | sed 's/^ *//')

errz "Hardware interface name" $HW

LOOPY=$(ifconfig | awk '/LOOPBACK/ { print $1; exit}' | sed 's/://')

errz "Loopback interface" $LOOPY

# time to jump hoops for CIDR
# print first one if lots of ints go whereever... ignore ipv6 for now
IP=$(ifconfig $INTERFACE | awk '/inet / { print $2}')

errz "IP Address" $IP

#
# perl magic via https://stackoverflow.com/questions/47746535/bash-how-do-i-convert-a-hex-subnet-mask-into-bit-form-or-the-dot-decimal-addres
#
CIDR=$(ifconfig en0 | awk '/inet / { printf $4 }' | sed 's/0x//' | perl -pe '$_ = unpack("B32", pack("H*", $_)); s/0+$//g; $_ = length')

errz "The CIDR block" $CIDR

echo Using interface $INTERFACE, loopback $LOOPY, IP/CIDR: $IP/$CIDR

echo ""

#
# now create the Tor conf file with the above intel
#

PFCTL="torry-pfctl.conf"

# don't overwrite out of courtesy....
if [ -s "$PFCTL" ] ; then
    echo "Cowardly bailin' to prevent overwriting the Tor configuration file ($PFCTL)"
    exit 4
fi

cat > "$PFCTL" <<_EOT_

#
# to test syntax
#
#   pfctl -n -v -f $PFCTL
#

# run, debug+verbose+more debug
#
#   pfctl -g -x loud -v -f $PFCTL
#

#
# show all rules, etc.
#
#       pfctl -s all
#

# mac can't use docker's host, so have to work with ports

rdr pass on lo0 inet proto tcp from any to any port $pfctl_to_docker -> $tor_server port $dtor_web_outside

_EOT_

# rdr pass on lo0 inet proto tcp from any to any port $proxy_port -> $tor_server port $tor_port
# proxy_port = $pfctl_to_docker
# tor_port   = $dtor_web_outside
# tor_server = localhost

#
# finis
#

if [ $? ]; then
    echo "The pfctl configuration file ($PFCTL) has been successfully created..."
else
    echo "Error (code: $?) creating the pfctl configuration file ($PFCTL)... bailin' out..."
    exit 5
fi

if [ $(id -u) ]; then
    echo "The pfctl command must be run as root... will prompt for sudo...."
fi

# .... sigh...
set +e

# clear the decks
echo ""
echo Mercelessly nuking all pfctl rules, then trying to put in Tor ones
echo ""
sudo pfctl -d &> /dev/null
sudo pfctl -e &> /dev/null
cat "$PFCTL" | sudo pfctl -e -f - &> /dev/null

echo ""
echo "... if the gods are feeling benign... traffic sent to port $tor_server:$pfctl_to_docker (web) or $tor_server:$pfctl_to_docker   should go through tor... trying to test -"
echo ""

curl --proxy http://$tor_server:$pfctl_to_docker https://check.torproject.org/ 2> /dev/null | grep -q Congratulations

if [ $? ]; then
    echo -e "\n\n"
    echo "congrats, looks good...!  https://check.torproject.org/ should corraborate"
    echo -e "\n\n"
else
    echo "buzz... after all this, you'd think it'd work, eh?  Sorry...."
fi


echo
echo FINALLY - setting sox proxy for BROWSERs in the System Settings
echo
# echo "(networksetup -setsocksfirewallproxy $HW localhost $PORT)"
#
#
#
INT=$(networksetup -listallnetworkservices | awk '!/\*/ {print $0; exit}')
echo
echo For interface: $INT
echo
echo
# networksetup -setsocksfirewallproxy "$HW" localhost "$dtor_sox_outside"
networksetup -setsocksfirewallproxy "$INT" localhost "$dtor_sox_outside"

echo To stop using Tor et al, stop the running docker container:
echo 
echo -e "\tdocker stop $did"
echo 
echo Clear the pfctl rules with:
echo
echo -e "\tsudo pfctl -d && sudo pfctl -e"
echo
echo Remove the old pfctl configuration file
echo
echo -e "\trm $PFCTL"
echo
echo And finally kill off the socks network System Preferences
echo
# echo -e "\tnetworksetup -setsocksfirewallproxystate $HW off"
echo -e "\tnetworksetup -setsocksfirewallproxystate "$INT" off"
echo
echo "good luck!"
echo



