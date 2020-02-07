#!/bin/sh

set -x

if [ $EUID -ne 0 ]; then
   echo "This script must be run as root"
   exit 1
fi

if [ "$1" = "--install" ]; then

	# Move the files into place
	cp -r SimpleEndpointApp.app /Applications
	mkdir -p /Library/SimpleEndpoint/
	cp launchDaemon /Library/SimpleEndpoint/
	cp com.endpoint.SimpleEndpoint.plist /Library/LaunchDaemons/

	# Load the extension 
	/Applications/SimpleEndpointApp.app/Contents/MacOS/SimpleEndpointApp --install
	if [ "$?" -ne 0 ]; then
		echo "Unable to load system extension"
	else
		echo "Loaded system extension"
		launchctl load -w /Library/LaunchDaemons/com.endpoint.SimpleEndpoint.plist
	fi
fi

if [ "$1" = "--uninstall" ]; then

	# Stop the launchdaemon 
	launchctl unload /Library/LaunchDaemons/com.endpoint.SimpleEndpoint.plist

	# Stop the system extension
	/Applications/SimpleEndpointApp.app/Contents/MacOS/SimpleEndpointApp --uninstall
	if [ "$?" -ne 0 ]; then
		echo "Unable to unload system extension"
	else

		# remove the install
		rm -rf /Library/SimpleEndpoint/
		rm -rf /Applications/SimpleEndpointApp.app
		rm /Library/LaunchDaemons/com.endpoint.SimpleEndpoint.plist
	fi
fi




