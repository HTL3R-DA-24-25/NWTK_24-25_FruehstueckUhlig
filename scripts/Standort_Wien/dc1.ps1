$stage = 1
$password = "ganzgeheim123!"
$domainName = "corp.FruUhl.at"
$computerName = "WinUhligS1"
$netbios = "CORP"
$localAdministratorUserName = "Administrator"
$ntpServer = "time.FruUhl.at"


$passwordSecure = $(ConvertTo-SecureString $password -AsPlainText -Force)


function Install-ActiveDirectory {
    Add-WindowsFeature AD-Domain-Services -IncludeManagementTools
    Install-ADDSForest `
        -InstallDns:$true `
        -DomainMode WinThreshold `
        -DomainName $domainName `
        -ForestMode WinThreshold `
        -SafeModeAdministratorPassword $passwordSecure `
        -DomainNetBiosName $netbios `
        -NoRebootOnCompletion:$true `
        -Force:$true
}
function Set-DefaultConfiguration {
    Set-WinUserLanguageList -LanguageList "de-DE" -Force
    Set-LocalUser -Name $localAdministratorUserName -Password $passwordSecure
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
    Set-HcsNtpClientServerAddress -Primary $ntpServer
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
        shutdown /r /t 0
    }
    2 {
        Install-ActiveDirectory
        shutdown /r /t 0
    }
}