# Moduł obsługi hostingu home.pl.
# Funkcje publiczne (buildery + wykonanie) eksportowane domyślnie.
# Konfiguracja: ~/.home-pl/config.json (patrz skill home-pl-setup).

Set-StrictMode -Version Latest

function Get-HomePlConfig {
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $HOME '.home-pl/config.json'),
        [switch]$RequireMail
    )
    if (-not (Test-Path -Path $Path)) {
        throw "Brak konfiguracji home.pl ($Path). Uruchom skill home-pl-setup, aby ja utworzyc."
    }
    $cfg = Get-Content -Raw -Path $Path | ConvertFrom-Json
    $required = 'host','port','user','passwordEnc'
    if ($RequireMail) {
        $required += 'imapHost','imapPort','smtpHost','smtpPort','mailUser','mailPasswordEnc'
    }
    $missing = foreach ($f in $required) {
        $has = $cfg.PSObject.Properties.Name -contains $f
        if (-not $has -or [string]::IsNullOrWhiteSpace([string]$cfg.$f)) { $f }
    }
    if ($missing) {
        throw "Konfiguracja home.pl niekompletna ($Path). Brakuje pol: $($missing -join ', '). Uruchom home-pl-setup."
    }
    return $cfg
}

function Protect-HomePlSecret {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PlainText)
    $secure = ConvertTo-SecureString -String $PlainText -AsPlainText -Force
    return (ConvertFrom-SecureString -SecureString $secure)
}

function Unprotect-HomePlSecret {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Encrypted)
    return (ConvertTo-SecureString -String $Encrypted)
}

function Get-HomePlCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][ValidateSet('ssh','mail')][string]$Scope
    )
    if ($Scope -eq 'ssh') {
        $user = $Config.user
        $secure = Unprotect-HomePlSecret -Encrypted $Config.passwordEnc
    } else {
        $user = $Config.mailUser
        $secure = Unprotect-HomePlSecret -Encrypted $Config.mailPasswordEnc
    }
    return [System.Management.Automation.PSCredential]::new($user, $secure)
}

function Assert-HomePlModule {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        throw "Brak modulu $Name. Uruchom skill home-pl-setup lub: Install-Module $Name -Scope CurrentUser."
    }
    Import-Module $Name -ErrorAction Stop
}

function New-HomePlSSHInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][string]$Command
    )
    return [pscustomobject]@{
        Tool    = 'ssh'
        Host    = $Config.host
        Port    = [int]$Config.port
        User    = $Config.user
        Command = $Command
    }
}

function Invoke-HomePlSSH {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        $Config,
        [switch]$DryRun
    )
    if (-not $Config) { $Config = Get-HomePlConfig }
    $info = New-HomePlSSHInfo -Config $Config -Command $Command
    if ($DryRun) { return $info }
    Assert-HomePlModule -Name 'Posh-SSH'
    $cred = Get-HomePlCredential -Config $Config -Scope ssh
    $session = $null
    try {
        $session = New-SSHSession -ComputerName $info.Host -Port $info.Port -Credential $cred -AcceptKey -ErrorAction Stop
        $res = Invoke-SSHCommand -SSHSession $session -Command $Command
        return [pscustomobject]@{ Output = $res.Output; ExitCode = $res.ExitStatus }
    } finally {
        if ($session) { Remove-SSHSession -SSHSession $session | Out-Null }
    }
}

function New-HomePlSFTPInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][ValidateSet('up','down')][string]$Direction,
        [Parameter(Mandatory)][string]$Local,
        [Parameter(Mandatory)][string]$Remote
    )
    return [pscustomobject]@{
        Tool      = 'sftp'
        Direction = $Direction
        Host      = $Config.host
        Port      = [int]$Config.port
        User      = $Config.user
        Local     = $Local
        Remote    = $Remote
    }
}

function Send-HomePlFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Local,
        [Parameter(Mandatory)][string]$Remote,
        $Config,
        [switch]$DryRun
    )
    if (-not $Config) { $Config = Get-HomePlConfig }
    $info = New-HomePlSFTPInfo -Config $Config -Direction up -Local $Local -Remote $Remote
    if ($DryRun) { return $info }
    Assert-HomePlModule -Name 'Posh-SSH'
    $cred = Get-HomePlCredential -Config $Config -Scope ssh
    $session = $null
    try {
        $session = New-SFTPSession -ComputerName $info.Host -Port $info.Port -Credential $cred -AcceptKey -ErrorAction Stop
        Set-SFTPItem -SFTPSession $session -Path $Local -Destination $Remote -Force -ErrorAction Stop
        return [pscustomobject]@{ Output = "Wyslano $Local -> $Remote"; ExitCode = 0 }
    } finally {
        if ($session) { Remove-SFTPSession -SFTPSession $session | Out-Null }
    }
}

function Get-HomePlFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Remote,
        [Parameter(Mandatory)][string]$Local,
        $Config,
        [switch]$DryRun
    )
    if (-not $Config) { $Config = Get-HomePlConfig }
    $info = New-HomePlSFTPInfo -Config $Config -Direction down -Local $Local -Remote $Remote
    if ($DryRun) { return $info }
    Assert-HomePlModule -Name 'Posh-SSH'
    $cred = Get-HomePlCredential -Config $Config -Scope ssh
    $session = $null
    try {
        $session = New-SFTPSession -ComputerName $info.Host -Port $info.Port -Credential $cred -AcceptKey -ErrorAction Stop
        Get-SFTPItem -SFTPSession $session -Path $Remote -Destination $Local -Force -ErrorAction Stop
        return [pscustomobject]@{ Output = "Pobrano $Remote -> $Local"; ExitCode = 0 }
    } finally {
        if ($session) { Remove-SFTPSession -SFTPSession $session | Out-Null }
    }
}

function New-HomePlMailInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][string]$To,
        [Parameter(Mandatory)][string]$Subject
    )
    return [pscustomobject]@{
        Tool    = 'smtp'
        Server  = $Config.smtpHost
        Port    = [int]$Config.smtpPort
        From    = $Config.mailUser
        To      = $To
        Subject = $Subject
    }
}

function Send-HomePlMail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$To,
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$Body,
        [switch]$Html,
        [string[]]$Attachment,
        $Config,
        [switch]$DryRun
    )
    if (-not $Config) { $Config = Get-HomePlConfig -RequireMail }
    $info = New-HomePlMailInfo -Config $Config -To $To -Subject $Subject
    if ($DryRun) { return $info }
    Assert-HomePlModule -Name 'Mailozaurr'
    $cred = Get-HomePlCredential -Config $Config -Scope mail
    # Send-EmailMessage: -Credential trafia do zestawow OAuth/Graph; dla zwyklego SMTP
    # uzywamy zestawu SecureString (-Username/-Password jako stringi).
    $params = @{
        From                = $Config.mailUser
        To                  = $To
        Subject             = $Subject
        Server              = $Config.smtpHost
        Port                = [int]$Config.smtpPort
        Username            = $cred.UserName
        Password            = $cred.GetNetworkCredential().Password
        SecureSocketOptions = 'SslOnConnect'
    }
    if ($Html) { $params['HTML'] = $Body } else { $params['Text'] = $Body }
    if ($Attachment) { $params['Attachment'] = $Attachment }
    Send-EmailMessage @params | Out-Null
    return [pscustomobject]@{ Output = "Wyslano do $To"; ExitCode = 0 }
}

function Select-HomePlMail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Messages,
        [string]$From,
        [string]$Subject
    )
    $result = $Messages
    if ($From)    { $result = $result | Where-Object { "$($_.From)"    -like "*$From*" } }
    if ($Subject) { $result = $result | Where-Object { "$($_.Subject)" -like "*$Subject*" } }
    return @($result)
}

function Get-HomePlMail {
    [CmdletBinding()]
    param(
        [string]$Folder = 'INBOX',
        [int]$Limit = 10,
        [switch]$Unread,
        [string]$From,
        [string]$Subject,
        $Config,
        [switch]$DryRun
    )
    if (-not $Config) { $Config = Get-HomePlConfig -RequireMail }
    $info = [pscustomobject]@{
        Tool    = 'imap'
        Server  = $Config.imapHost
        Port    = [int]$Config.imapPort
        User    = $Config.mailUser
        Folder  = $Folder
        Limit   = $Limit
        Unread  = [bool]$Unread
        From    = $From
        Subject = $Subject
    }
    if ($DryRun) { return $info }
    Assert-HomePlModule -Name 'Mailozaurr'
    $cred = Get-HomePlCredential -Config $Config -Scope mail
    $imap = $null
    try {
        # Connect-IMAP: -Credential jest dwuznaczne (zestawy OAuth2/Credential bez domyslnego);
        # uzywamy zestawu ClearText (-UserName/-Password jako stringi).
        $imap = Connect-IMAP -Server $Config.imapHost -Port ([int]$Config.imapPort) -UserName $cred.UserName -Password $cred.GetNetworkCredential().Password -Options Auto
        # Mailozaurr 2.x: Search-IMAPMailbox obsługuje wybór folderu i filtry po stronie serwera.
        $search = @{ Client = $imap; Folder = $Folder }
        if ($From)    { $search['FromContains'] = $From }
        if ($Subject) { $search['Subject'] = $Subject }
        if ($Unread)  { $search['SearchQuery'] = (New-IMAPSearchQuery -Unseen) }
        $raw = Search-IMAPMailbox @search
        # ImapEmailMessage opakowuje treść w .Message (MimeKit.MimeMessage).
        $messages = foreach ($m in $raw) {
            if (-not $m.Message) { continue }   # pomiń wiadomość, której MimeKit nie sparsował
            [pscustomobject]@{
                From    = "$($m.Message.From)"
                Subject = $m.Message.Subject
                Date    = $m.Message.Date
                Body    = $m.Message.TextBody
            }
        }
        # Klientowy filtr (przetestowany, gwarantuje AND + brak rozróżniania wielkości liter).
        $filtered = Select-HomePlMail -Messages @($messages) -From $From -Subject $Subject
        # Najnowsze pierwsze — "ostatnie N wiadomości".
        return ($filtered | Sort-Object Date -Descending | Select-Object -First $Limit)
    } finally {
        if ($imap) { Disconnect-IMAP -Client $imap | Out-Null }
    }
}