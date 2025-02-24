$stage = 3
$password = "ganzgeheim123!"
$computerName = "Jumphost"
$domainName = "wien.FruUhl.at"
$domainAdministratorUser = "Administrator"
$localAdministratorUser = "Administrator"

$networkAdapter = @{
    Name           = "E*"
    NewName        = "Server"
    IPAddress      = "172.16.100.100"
    PrefixLength   = "24"
    DefaultGateway = "172.16.100.254"
    DNS            = ("192.168.100.1", "192.168.10.1")
}

$passwordSecure = $(ConvertTo-SecureString $password -AsPlainText -Force)
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ("$domainAdministratorUser@$domainName", $passwordSecure)

function Join-ADDomain {
    Add-Computer -DomainName $domainName -Credential $credential -Restart:$false -Force 
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
        Join-ADDomain
        shutdown /r /t 0
    }
    3 { 
        Set-SConfig -AutoLaunch $false
        Set-WinUserLanguageList -LanguageList "de-DE" -Force
    }
}
