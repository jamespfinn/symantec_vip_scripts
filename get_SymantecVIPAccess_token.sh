#!/bin/bash
# 11.08.14 jfinn - created
# Intended to be run on Mac OS X
# This script will extract the oauth TOTP token from the Symantec VIP Access Application
# The Symantec app must be installed and run at least once.  You can remove it after getting
# the needed information from this script.  
# This will allow the token to be consumed by oathtool --totp $TOKEN on any system
# and generate the correct pseudorandom security code for 2nd factor auth.
#
# Because of the keychain access, its possible this must be done interactively so the user can click allow.
#
# This script will output the credential ID & token to be used
# If oathtool is available in $PATH, we will also output the security code 
# We need to get the machine ID aka SN of the Mac to access the kechain... (this will prompt the user to allow access)
# This is the most time consuming portion of the script, so we will cache it in /tmp/VIP.machineID
# If that file is present, we will use it, if not, we will do a manual check then cache the result.
#
# Example output:
#  credential:VSSABCDEFGHI|token:0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f|security_code:907302
#
# The token is un-changing for a particular credential.  If you register that credential for use, 
# you can then use that token on any system that supports oathtool (or via php, python, etc)
# Example of token usage:
# $ oathtool --totp 0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f
# 907302
#
# This also comes in handy if you simply don't want to have the Symantec VIP Access app running
# all the time.  This is a much more light-weigh solution for obtaining your one-time-password.
#
# TIP: if an error is received, try removing /tmp/VIP.machineID
#

if [ -s /tmp/VIP.machineID ] ; then
  MACHINE_ID=$(</tmp/VIP.machineID)
else
  MACHINE_ID=$(ioreg -rac IOPlatformExpertDevice | xpath 'plist/array/dict/key[.="IOPlatformSerialNumber"]/following-sibling::*[position()=1]/text()' 2>/dev/null| tail -1)
  echo $MACHINE_ID > /tmp/VIP.machineID
fi

#open the keychain and send in the password which is
# ${MACHINE_ID}SymantecVIPAccess${USER}
PASSWORD=${MACHINE_ID}SymantecVIPAccess${USER}
KEYCHAIN=/Users/${USER}/Library/Keychains/VIPAccess.keychain
AESKEY=D0D0D0E0D0D0DFDFDF2C34323937D7AE # thanks to p120ph37 for this!

if security unlock-keychain -p $PASSWORD /Users/${USER}/Library/Keychains/VIPAccess.keychain ; then
  # opened kestore successfully!
  KEYPAIR=$(security find-generic-password -gl CredentialStore $KEYCHAIN 2>&1 | egrep '^password|\"acct\"')
  ID_CRYPT=$(echo $KEYPAIR | cut -d\" -f6)
  KEY_CRYPT=$(echo $KEYPAIR | cut -d\"  -f2 )
  ID_DECRYPT=$(openssl enc -aes-128-cbc -d -K $AESKEY -iv 0 -a <<< $ID_CRYPT)
  KEY_DECRYPT=$(openssl enc -aes-128-cbc -d -K $AESKEY -iv 0 -a <<< $KEY_CRYPT)
  ID_STRIPPED=$(echo $ID_DECRYPT | sed 's/Symantec//g')
  KEY_HEX=$(echo -n $KEY_DECRYPT | xxd -p)  
  echo credential:$ID_STRIPPED\|token:$KEY_HEX$(type oathtool &>/dev/null && echo \|security_code:$(oathtool --totp $KEY_HEX) )
else
  echo could not open keystore... is the VIP Access client installed? Install @ https://idprotect.vip.symantec.com > /dev/stderr
  exit 1
fi 
