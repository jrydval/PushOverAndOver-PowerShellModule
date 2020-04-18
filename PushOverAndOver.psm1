enum PushoverSound {
    Alien
    Bike
    Bugle
    Cashregister
    Classical
    Climb
    Cosmic
    Echo
    Falling
    Gamelan
    Incoming
    Intermission
    Magic
    Mechanical
    None
    Persistent
    Pianobar
    Pushover
    Siren
    Spacealarm
    Tugboat
    Updown
    Vibrate
}

enum PushoverPriority {
    NoAlert = -2
    Quite = -1
    Normal = 0
    HighPriority = 1
    HighPriorityAndConfirmation = 2
}

$PushoverCredentials = "./.pushover.cred"
function Send-PushoverNotification {
    <#
    .SYNOPSIS
    Function for sending notifications via Pushover service.
    See https://pushover.net/

    .DESCRIPTION
    You can send Notification or Glance. 
    Notification is displayed as a popup or in notification area on your device. 
    Glance is displayed on small displays like Apple Watch without sound or vibration.

    .PARAMETER User
    Pushover user name, usually starts with "u".

    .PARAMETER ApiToken
    Pushover API token generated when creating an application, usually starts with "a".

    .PARAMETER Glance
    Switch indicating that a glance will be sent instead of ordinary notification. The glance is displayed on small devices like smart watches.
#>


    [CmdletBinding(SupportsShouldProcess = $true)] 
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $User,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ApiToken,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Io.FileInfo]
        $CredentialsPath,  

        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Message to be sent",
            ParameterSetName = "Notification")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Message,

        [Parameter(
            Mandatory = $false,
            Position = 1,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Title for your message")]
        [string]
        $Title,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Url which will be sent with the message",
            ParameterSetName = "Notification")]
        [ValidateNotNullOrEmpty()]
        [uri]
        $Url,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Title for your message",
            ParameterSetName = "Notification")]
        [string]
        $UrlTitle,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Device to deliver your notification to")]
        [string]
        $Device,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Attached image file",
            ParameterSetName = "Notification")]
        [Io.FileInfo]
        $Attachment,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Sound to play",
            ParameterSetName = "Notification")]
        [PushoverSound]
        $Sound,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Notification priority",
            ParameterSetName = "Notification")]
        [PushoverPriority]
        $Priority,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Timestamp for your message",
            ParameterSetName = "Notification")]
        [datetime]
        $Timestamp,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Retry interval is seconds for HighPriorityAndConfirmation notifications",
            ParameterSetName = "Notification")]
        [int]
        $Retry,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "How many seconds your notification will continue to be retried",
            ParameterSetName = "Notification")]
        [int]
        $Expire,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Notification confirmation callback URL",
            ParameterSetName = "Notification")]
        [uri]
        $Callback,

        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Glance")]
        [switch]
        $Glance = $false,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Glance")]
        [string]
        $Text,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Glance")]
        [string]
        $Subtext,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Glance")]
        [int]
        $Count,

        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Glance")]
        [int]
        $Percent



    )

    $attrs = $PSCmdlet.MyInvocation.BoundParameters

    if ( $User -and $ApiToken ) {
        $attrs.Add("User", $User)
        $attrs.Add("Token", $ApiToken)
        Write-Debug "Setting credentials from parameters"
    }
    elseif ( $CredentialsPath -and (Test-Path -PathType Leaf -Path $CredentialsPath) ) { 
        $cred = Import-Clixml -Path $CredentialsPath
        $attrs.Add("User", $cred.UserName)
        $attrs.Add("Token", ($cred.Password | ConvertFrom-SecureString -AsPlainText) )
        Write-Debug "Reading credentials from file $CredentialsPath"
    }
    elseif ( Test-Path -Path $PushoverCredentials ) {
        $cred = Import-Clixml -Path $PushoverCredentials
        $attrs.Add("User", $cred.UserName)
        $attrs.Add("Token", ($cred.Password | ConvertFrom-SecureString -AsPlainText) )
        Write-Debug "Reading credentials from file $PushoverCredentials"
    }
    else {
        Write-Error "User and/or ApiToken parameters are missing - add them as parameters or run Set-PushoverCredentials function to persistently store them."
        return
    }

    $body = [System.Net.Http.MultipartFormDataContent]::new()
    
    $url = $Glance ? 'https://api.pushover.net/1/glances.json' : 'http://api.pushover.net/1/messages.json'

    if ($Attachment) {
        $fileStream = [System.IO.FileStream]::new($Attachment.FullName, [System.IO.FileMode]::Open)
        $header = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
        $header.Name = "attachment"
        $header.FileName = $Attachment.Name
        $content = [System.Net.Http.StreamContent]::new($FileStream)
        $content.Headers.ContentDisposition = $header
        $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/jpeg")
        $body.Add($content)
    }

    $validParams = @{ 
        Message   = "message"
        Device    = "device"
        Title     = "title"
        Url       = "url"
        UrlTitle  = "url_title"
        Timestamp = "timestamp"
        Priority  = "priority"
        Sound     = "sound" 
        User      = "user"
        Token     = "token"
        Expire    = "expire"
        Retry     = "retry"
        Callback  = "callback"
        Text      = "text"
        Subtext   = "subtext"
        Count     = "count"
        Percent   = "percent"
    }



    if ($attrs.Priority) { $attrs.Priority = [int]$attrs.Priority }
    if ($attrs.Sound) { $attrs.Sound = ([string]$attrs.Sound).toLower() }
    if ($attrs.Timestamp) { 
        $date0 = Get-Date -Date '01/01/1970'
        $attrs.Timestamp = (New-TimeSpan -Start $date0 -End $attrs.Timestamp).TotalSeconds 
    }

    foreach ($param in $validParams.GetEnumerator()) {
        $val = $attrs[$param.Name] 
        if ( $null -ne $val) {
    
            $header = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
            $header.Name = $param.Value
            $content = [System.Net.Http.StringContent]::new($val)
            $content.Headers.ContentDisposition = $header
            $body.Add($content)
            Write-Debug "Send-PushoverNotification, param: $($param.Value) = $val"
        }

    } 

    if ($PSCmdlet.ShouldProcess($attrs.Message, "Sending notification using Pushover service")) {
        Invoke-RestMethod -Uri $url -Method Post -Body $body
    }
}

function Set-PushoverCredentials {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Pushover user name (30 chars) "u..."')]
        [ValidateNotNullOrEmpty()]
        [string]
        $User,

        [Parameter(Mandatory = $true,
            Position = 1,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Pushover API Token (30 chars) "a..."')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ApiToken,

        [Parameter(Mandatory = $false)]
        [switch]
        $Force = $false
    )

    if ( ( Test-Path -Path $PushoverCredentials) -and -not ($Force) ) {
        Write-Error "Pushover credentials file $PushoverCredentials alredy exists, use -Force if you want to re-create the file"
        return
    }

    $ApiTokenSecure = ConvertTo-SecureString -String $ApiToken -AsPlainText -Force
    
    New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $ApiTokenSecure | Export-Clixml -Path $PushoverCredentials
}
