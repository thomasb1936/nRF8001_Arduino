#!/bin/bash 

sep="------------------------------------------------------------------"
echo $sep
echo "This will integrate our ble stack into the existing TinyOS setup "
echo "using the following env vars:"
echo $sep
echo "TOSROOT: " $TOSROOT
echo "TOSDIR: " $TOSDIR
echo "CLASSPATH: " $CLASSPATH
echo "MAKERULES: " $MAKERULES
echo $sep

# ------------------------------------------------------------------
# This will integrate our ble stack into the existing TinyOS setup 
# using the following env vars:
# ------------------------------------------------------------------
# TOSROOT:  /Users/dderiso/Code/TinyOs/tinyos-release
# TOSDIR:  /Users/dderiso/Code/TinyOs/tinyos-release/tos
# CLASSPATH:  :/Users/dderiso/Code/TinyOs/tinyos-release/support/sdk/java
# MAKERULES:  /Users/dderiso/Code/TinyOs/tinyos-release/support/make/Makerules
# ------------------------------------------------------------------

dest="$TOSROOT/support/make/"
echo "...copying file support/make/micable.target" $dest
cp support/make/micable.target $dest/

# check if the correct file
topline=`cat $TOSROOT/support/make/micable.target | grep bluemoon`

if [ "$topline" == "#bluemoon" ]
then
	echo "	copied successfully"
else
	echo "	there was a problem copying"
fi

dest=$TOSROOT/tos/platforms/
echo "...copying directory tos/platforms/micable to " $dest
yes | cp -rf tos/platforms/micable/ $dest

# check if the correct file
topline=`cat $TOSROOT/tos/platforms/micable/.platform | grep bluemoon`

if [ "$topline" == "#bluemoon" ]
then
	echo "	copied successfully"
else
	echo "	there was a problem copying"
fi

dest=$TOSROOT/tos/chips/
echo "...copying tos/chips/nrf8001 to " $dest
yes | cp -rf tos/chips/nrf8001/ $dest

# check if the correct file
topline=`cat $TOSROOT/tos/chips/nrf8001/README | grep bluemoon`

if [ "$topline" == "#bluemoon" ]
then
	echo "	copied successfully"
else
	echo "	there was a problem copying"
fi

echo "done"



