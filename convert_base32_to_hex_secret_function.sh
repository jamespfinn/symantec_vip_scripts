#!/bin/bash
# 03.24.16 jfinn - THis script does the opposite of what this says -->
#		   Created this function to convert a base64 hex totp token to a 
#		   Base32 TOTP Secret for use in apps like Authy or Google Authenticator
#		   that can display your OTP.  
#		   This is useful when converting the base64 value we receive from the
#		   Symantec VIP access generator and extractor scripts.
function convBase32TOTPtoHexSecret(){ oathtool --totp -b -v $1 | grep ^Hex | cut -d\  -f3 ; }
