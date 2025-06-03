##############################################
##                                          ##
##      Script:  Tape_Import.ps1	    ##
##      Version: 1.0			    ##
##		Date:	 31.01.2024         ##
##                                          ##
##      Author: Chalid Mohamed Fathallah    ##
##					    ##
##                                          ##
##      Desc:   Script for importing +      ##
##		unprotecting tapes and 	    ##
##		moving them into the	    ##
##              "free" pool 		    ##
##                                          ##
##############################################


#Connect to a Veeam backup server as a current user.(if running as sheduled Task from another server via run-as)#
#Connect-VBRServer [-Server <String>] [-Port <Int32>] [-Timeout <Int32>]  [<CommonParameters>]#


### globals ###
###set script location###
#
$dir_base = "C:\Veeam-Skripts\Tape-Reporting"

### set time filter for log file ###
#
filter timestamp {"`n$(Get-Date -Format hh:mm:ss): $_"}

### set log files location ###
#
$f_log = "$dir_base\LOG\tape_import.log"

### E-Mail Konfiguration ###
#
# Set SMTP Server #
$SmtpServer = "mailserver.domain.local"

# Define the target email address #
$to = "target@yourmail.com"

# Define the sender email address #
$from = "sender@yourmail.com"

# Define the name of the tape library #
#
# Example:  $Library = "IBM 3573-TL 1502" #
$Library = "Your Tape Library"

### clean up old log ###
#
if(Test-Path $f_log){
remove-item $f_log
}

### Import tapes to libary ###
#

try {

	Write-Output "Start tape import" | timestamp | add-content  $f_log
	Import-VBRTapeMedium -library $Library -wait  | add-content  $f_log

} catch {

	### write error to error log ###
	#
	$event_entry = "Exception Type: $($_.Exception.GetType().FullName)`nException Message: $($_.Exception.Message)"
	"$event_entry" | timestamp | add-content  $f_log

}	
	
### wait till next discovery (5 min.) ###
#
Write-Output "Wait till next disovery (5 min.)" | timestamp | add-content  $f_log
start-sleep -s 300


 ### Find Expired Media & Unprotect them ###
 try {

 Write-Output "Find Expired Media" | timestamp | add-content  $f_log
 $number = (Get-VBRTapeMedium -Library $Library | ?{$_.IsExpired}).count
 #(if($number -ne 0 )) { 
 Write-Output "Found $number expired media and disabling TapeProtection" | timestamp | add-content  $f_log

 Get-VBRTapeMedium -Library $Library | ?{$_.IsExpired} | Disable-VBRTapeProtection
 #} else {
 #Write-Output "No Media to Import" | timestamp | add-content  $f_log
 #Return
 #} 
 } catch {
 
	### write error to error log ###
	#
	$event_entry = "Exception Type: $($_.Exception.GetType().FullName)`nException Message: $($_.Exception.Message)"
	"$event_entry" | timestamp | add-content  $f_log
}


 ###Move Media to Free Pool###
 try {
 Write-Output "Move Media to Free Pool" | timestamp | add-content  $f_log
  $number = (Get-VBRTapeMedium -Library $Library | ?{$_.IsExpired}).count
 #(if($number -ne 0 )) { 
 Write-Output "Moved $number expired media to Free Pool" | timestamp | add-content  $f_log

 Get-VBRTapeMedium -Library $Library | ?{$_.IsExpired} | Move-VBRTapeMedium -MediaPool Free
  } catch {

	### write error to error log ###
	#
	$event_entry = "Exception Type: $($_.Exception.GetType().FullName)`nException Message: $($_.Exception.Message)"
	"$event_entry" | timestamp | add-content  $f_log
}

 Write-Output "End" | timestamp | add-content  $f_log


# Define the content of the email
$body = "$number tapes were imported into the library" 
# Send the email via Exchange
Send-MailMessage -To $to  -Subject $subject -From $from -Body $body -SmtpServer $SmtpServer
