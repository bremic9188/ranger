#############################################
#	Password notification script for    	#
#	Active Directory user accounts.			#
#	Sends HTML formatted email to users		#
#	who are 5 days from expiration. 	 	#
#	Continues sending until the password	#
#	has been reset by the user.				#
#############################################

Cls
$next = 5

$today = (get-date)

#get current domain password policy
$policy=Get-ADDefaultDomainPasswordPolicy
#save the password age in days
$days=$Policy.MaxPasswordAge.TotalDays

#Start = Today - [MaxPasswordAge]
#End = Today - ([MaxPasswordAge] - 5)
$Start=(Get-Date).AddDays(-$days)
$End=(Get-Date).AddDays(-($days-$next))

$days_before_expire = (get-date).Subtract((New-TimeSpan -Days 60))

#creates the text files to be sent to administrator for review
new-item -path c:\RBSTemp\_scripts\AD\expiredpasswords.txt -type file
new-item -path c:\RBSTemp\_scripts\AD\emailsentto.txt -type file

#sets the filter for users who need to be notified
#if $Start <= PasswordLastSet <= $End
$users_to_be_notified = Get-ADUser -Filter {Enabled -eq $True -AND PasswordNeverExpires -eq $false -AND PasswordLastSet -ge $Start.Date -AND PasswordLastSet -le $End.Date};

foreach ($user in $users_to_be_notified) {
	$username = Get-ADUser $user -Properties SamAccountName | Select -ExpandProperty SamAccountName
	$fullname = Get-ADUser $user -Properties Name | Select -ExpandProperty Name
	$passlastset = get-aduser $user -properties PasswordLastSet | select -ExpandProperty PasswordLastSet
	$expireDate = $passlastset.AddDays($days)
	$days_remaining = ($expireDate - $today).days + 1
	$resetby = $expireDate.tostring('MM/dd/yyyy')
	$to = $username + '@oneprop.com'
	$from = 'support@rangersolutions.com'
	$smtpserver = 'relay.appriver.com'
	$smtpport = 2525
	$subject = "Reminder - Password is expiring in $days_remaining day(s)."
	$body = "<html>
				<head></head>
					<body>
					$fullname,
					<BR><BR>
					Your password will expire in <span style='font-size:20px; color:#ff0000; font-weight:bold;'>$days_remaining day(s)</span>. Please change it by <span style='font-size:20px; color:#ff0000; font-weight:bold;'>$resetby</span>.<BR><BR>
					<b>Users in Dallas office:</b> You can reset your password by pressing <b>Ctrl + Alt + Del</b> and selecting <b>Change password</b>.<BR>
			<b>Remote Users:</b> All remote users can reset their password by going to the <a href='http://pwm.oneprop.com/pm'>ONEprop password portal</a>. If you have never used the portal before, you must first enroll your account by following the instructions attached. The password portal is <i>ONLY</i> available to remote users.<BR>
					<span style='font-style:italic; font-weight:bold; font-size:0.8em;'>Note: </span><span style='font-style:italic; font-size:0.8em;'>This password is not associated with your @oneprop.com email. After resetting this password, your email password will remain the same. The password this email is referring to is your domain/network, ShoreTel, and Egnyte password.</span><BR><BR>
					If you have any issues, please submit a ticket using the Ranger agent icon in the system tray or send an email to <a href='mailto:support@rangersolutions.com'>support@rangersolutions.com</a>.<BR><BR>
			You will receive this notification daily until your password is changed.<BR><BR>
					Thank You!<BR>
					Ranger Business Solutions<BR>
					support@rangersolutions.com<BR>
					214.329.1349
					</body>
			</html>"
	
	#adds expired usernames to txt file		
	if ($days_remaining -le 0) {
		add-content -path 'c:\RBSTemp\_scripts\AD\expiredpasswords.txt' -value "User: $username","Expired On: $expireDate","`n`n`n"
	}
	#adds usernames who received notifications to txt file
	if ($days_remaining -gt 0) {
		send-mailmessage -bodyashtml -to $to -from $from -subject $subject -body $body -attachment 'C:\RBSTemp\_scripts\AD\PWMHowTo.pdf' -smtpserver $smtpserver -port $smtpport
		add-content -path 'C:\RBSTemp\_scripts\AD\emailsentto.txt' -value "User: $username","Reset By: $resetby","`n`n`n"
	}
}

#sends txt files to administrator
$to = 'report@rangersolutions.com'
$subject = "ONEprop Password Notifications"
$body = "<html>
		<head></head>
			<body>
			Two documents are attached to this email.<br>
			<ol>
				<li>A list of users who were sent an email warning them of their upcoming password expiration</li>
				<li>A list of users who have expired passwords</li>
			</ol>
		</body>
	</html>"
send-mailmessage -bodyashtml -to $to -from $from -subject $subject -body $body -attachment 'C:\RBSTemp\_scripts\AD\emailsentto.txt','c:\RBSTemp\_scripts\AD\expiredpasswords.txt' -smtpserver $smtpserver -port $smtpport

#removes both txt files from local storage to prepare for next processing
remove-item -path c:\RBSTemp\_scripts\AD\expiredpasswords.txt
remove-item -path c:\RBSTemp\_scripts\AD\emailsentto.txt