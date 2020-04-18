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

        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Message to be sent")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Message,

        [Parameter(Mandatory = $false,
            Position = 1,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Title for your message")]
        [string]
        $Title,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Url which will be sent with the message")]
        [ValidateNotNullOrEmpty()]
        [uri]
        $Url,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Title for your message")]
        [string]
        $UrlTitle,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Device to deliver your notification to")]
        [string]
        $Device,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Attached image file")]
        [Io.FileInfo]
        $Attachment,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Sound to play")]
        [PushoverSound]
        $Sound,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Notification priority")]
        [PushoverPriority]
        $Priority,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Timestamp for your message")]
        [datetime]
        $Timestamp,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Retry interval is seconds for HighPriorityAndConfirmation notifications")]
        [int]
        $Retry,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "How many seconds your notification will continue to be retried")]
        [int]
        $Expire,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Notification confirmation callback URL")]
        [uri]
        $Callback

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
        Write-Error "User and ApiToken parameters are missing - add then as parameters or run Set-PushoverCredentials cmdlet to persistently store them."
        return
    }

    $body = [System.Net.Http.MultipartFormDataContent]::new()
    $url = "http://api.pushover.net/1/messages.json"

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
        Invoke-WebRequest -Uri $url -Method Post -Body $body
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
