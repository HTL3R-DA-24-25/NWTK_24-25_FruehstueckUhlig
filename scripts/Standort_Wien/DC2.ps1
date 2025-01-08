$stage = 3
$password = "ganzgeheim123!"
$computerName = "DC2"
$domainAdministratorUser = "Administrator"
$localAdministratorUser = "Administrator"
$domainName = "wien.FruUhl.at"
$ntpServer = "time.FruUhl.at"

$networkAdapter = @{
    Name           = "E*"
    NewName        = "DC"
    IPAddress      = "192.168.10.2"
    PrefixLength   = "24"
    DefaultGateway = "192.168.10.254"
    DNS            = ("192.168.10.1", "192.168.10.2")
}

$distinguishedName = ""
foreach ($part in $domainName.Split(".")) {
    $distinguishedName += "DC=$part,"
}
$distinguishedName = $distinguishedName.TrimEnd(",")

$passwordSecure = $(ConvertTo-SecureString $password -AsPlainText -Force)
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ("$domainAdministratorUser@$domainName", $passwordSecure)

function Install-ActiveDirectory {
    Add-WindowsFeature AD-Domain-Services -IncludeManagementTools
    Install-ADDSDomainController `
        -Credential $credential `
        -InstallDns:$true `
        -DomainName $domainName `
        -SafeModeAdministratorPassword $passwordSecure `
        -NoRebootOnCompletion:$true `
        -SiteName "Wien" `
        -Force:$true 
}

function Set-DefaultConfiguration {
    Set-WinUserLanguageList -LanguageList "de-DE" -Force
    Set-LocalUser -Name $localAdministratorUser -Password $passwordSecure
    Rename-Computer -NewName $computerName
    Set-SConfig -AutoLaunch $false
}
function Set-NetworkConfiguration {
    Rename-NetAdapter -Name $networkAdapter.Name -NewName $networkAdapter.NewName
    New-NetIPAddress `
        -InterfaceAlias $networkAdapter.NewName `
        -IPAddress $networkAdapter.IPAddress `
        -PrefixLength $networkAdapter.PrefixLength `
        -DefaultGateway $networkAdapter.DefaultGateway  | Out-Null
    Set-DnsClientServerAddress -InterfaceAlias $networkAdapter.NewName -ServerAddresses $networkAdapter.DNS
    w32tm /config /manualpeerlist:"$ntpServer" /syncfromflags:manual /reliable:yes /update 
    Restart-Service w32time
}

function Install-SSH {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Start-Service sshd
    Set-Service -Name sshd -StartupType 'Automatic'
}

switch ($stage) {
    1 { 
        Set-DefaultConfiguration
        Set-NetworkConfiguration
        Install-SSH
        #shutdown /r /t 0
    }
    2 { 
        Install-ActiveDirectory
        shutdown /r /t 0
    }
    3 { 
        Set-SConfig -AutoLaunch $false
        Set-WinUserLanguageList -LanguageList "de-DE" -Force
    }
}
