A script - FOR MACs ONLY - that fires up Tor in a docker container, deals with details
-----

DO NOT RUN, lol. Still testing it out.

If you do want to run it anyway... simply type -

    ./iTor.sh


Deets
----

While checking out Jessie's nifty Linux docker Tor thing at -

    https://blog.jessfraz.com/post/routing-traffic-through-tor-docker-container/

I was internally lamenting how nothing works at all on a mac with
networking and docker. But....


This attempts to grab a Tor docker container - the nifty little one at:

    https://github.com/rdsubhas/docker-tor-privoxy-alpine

... and tries to set up all the ipctl, proxy, etc. stuff.  It tests itself
as it goes along, eventually trying to connect to check.torproject.org
to see if they think it's Tor or not.


IN THEORY. 

After running this your browser will use the Tor container as a socks
proxy - typically set by menus/by hand in:

    System Preferences->HW-interface->Advanced->Proxies->SOCKS Proxy

It'll create a pfctl configuration file to shunt traffic from local ports
to the docker proxy. Eventually this could take over 443, 80, etc., but
I was too chicken initially to do this. However, you could check that it's
working with curl like thus (this is done in the script, but...)

    curl --socks5 http://localhost:9050 https://check.torproject.org/|grep Congratulations


I'm sure it'll keel over in all sorts of ways.


TODO:

    - lots

    - properly deal with CIDRs that Tor shouldn't be seeing (e.g. 10/8, etc.)




Output
-----

Here's what the script looks like when I run it -

    $ ./iTor.sh

    trying to start the Tor Docker container...
    Unable to find image 'rdsubhas/tor-privoxy-alpine:latest' locally
    latest: Pulling from rdsubhas/tor-privoxy-alpine
    ff3a5c916c92: Pulling fs layer
    3db7ce00a871: Pulling fs layer
    3570578356bf: Pulling fs layer
    3570578356bf: Verifying Checksum
    3570578356bf: Download complete
    ff3a5c916c92: Verifying Checksum
    ff3a5c916c92: Download complete
    ff3a5c916c92: Pull complete
    3db7ce00a871: Verifying Checksum
    3db7ce00a871: Download complete
    3db7ce00a871: Pull complete
    3570578356bf: Pull complete
    Digest: sha256:1f48b2d88a0f44fdd7e79fe60abb8c15f6af0bf716e13243c44c1598c31ebc7b
    Status: Downloaded newer image for rdsubhas/tor-privoxy-alpine:latest
    Using interface en0, loopback lo0, IP/CIDR: 192.168.0.132/24
    
    The pfctl configuration file (torry-pfctl.conf) has been successfully created...
    The pfctl command must be run as root... will prompt for sudo....
    
    Mercelessly nuking all pfctl rules, then trying to put in Tor ones
    
    Password:
    
    ... if the gods are feeling benign... traffic sent to port localhost:5080 (web) or localhost:5080   should go through tor... trying to test -
    
    
    
    
    congrats, looks good...!  https://check.torproject.org/ should corraborate
    
    
    
    
    FINALLY - setting sox proxy for BROWSERs in the System Settings
    
    (networksetup -setsocksfirewallproxy Ethernet localhost )
    
    To stop using Tor et al, stop the running docker container:
    
    	docker stop 8a2f878a5b4cd7aa6cf6757609d69410b23eaab69eade6b95729515299da4876
    
    Clear the pfctl rules with:
    
    	sudo pfctl -d && sudo pfctl -e
    
    Remove the old pfctl configuration file
    
    	rm torry-pfctl.conf
    
    And finally kill off the socks network System Preferences
    
    	networksetup -setsocksfirewallproxystate Ethernet off
    
    good luck!





Details
-----

To get the system back to normal, you need to kill off the container, clear pfctl, 
and set back the networksetup proxy state. The script tells you all this, but basically
it's something like:

    	docker stop $dockerID
    
    	sudo pfctl -d && sudo pfctl -e
    
    	networksetup -setsocksfirewallproxystate Ethernet off
    

