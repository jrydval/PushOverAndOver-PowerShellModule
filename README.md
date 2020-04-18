## What is it?

Small and light module for sending notifications using Pushover service

## Usage

Run ``Set-PushoverCredentials`` first, it will create a file .pushover.cred with stored credentials in the current directory and will use it when calling Send-PushoverNotifications function later\.

``
Set-PushoverCredentials -User u... -ApiToken a...
Send-PushoverNotification -Message 'Notify me from PowerShell'
``

Or you can move .pushover.cred file anywhere and point the function to it:

``
Send-PushoverNotification -Message 'Notify me from PowerShell' -CredentialsPath '/path/.pushover.cred'
``

Or specify credentials every time you call the ``Send-PushoverNotification``.

``
Send-PushoverNotification -Message 'Notify me from PowerShell' -User u... -ApiToken a...
``

Function ``Send-PushoverNotification`` supports all the optional arguments:
-Attachment filename.jpg
-Url http://somewhere.net/
-UrlTitle 'Link somewhere'
-Priority [NoAlert, Quite, Normal, HighPriority, HighPriorityAndConfirmation] 
-Retry x - Retry interval is seconds for HighPriorityAndConfirmation notifications
-Expire x - How many seconds your notification will continue to be retried for HighPriorityAndConfirmation notifications
-Timestamp (Get-Date -Date '01/01/2000') - Timestamp when different from sending time
-Sound [None, Alien, Bike, ...] - name of the notification sound, autocompletion supported
-Device name - device the notification should be delivered to instead of to all devices
-Callback - URL which will be 'called' when notification is confirmed

## Disclaimer

I have nothing in common with Pushover service. I just like it and use it...