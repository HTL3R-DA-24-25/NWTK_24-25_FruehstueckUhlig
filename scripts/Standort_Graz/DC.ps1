$stage = 2
$password = "ganzgeheim123!"
$computerName = "DC"
$netbios = "GRAZ"
$domainAdministratorUser = "Administrator"
$localAdministratorUser = "Administrator"
$parentDomainName = "wien.FruUhl.at"
$domainName = "graz"

$networkAdapter = @{
    Name            = "E*"
    NewName         = "AD"
    IPAddress       = "172.16.0.1"
    PrefixLength    = "24"
    DefaultGateway  = "172.16.0.254"
    DNSBeforeDomain = ("192.168.10.1", "192.168.10.2")
    DNS             = ("172.16.0.1", "192.168.10.1")
}

$fullDomainName = "$domainName.$parentDomainName"

$distinguishedName = ""
foreach ($part in $fullDomainName.Split(".")) {
    $distinguishedName += "DC=$part,"
}
$distinguishedName = $distinguishedName.TrimEnd(",")

$passwordSecure = $(ConvertTo-SecureString $password -AsPlainText -Force)
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ("$domainAdministratorUser@$parentDomainName", $passwordSecure)

function Install-ActiveDirectory {
    Add-WindowsFeature AD-Domain-Services -IncludeManagementTools
    Install-ADDSDomain `
        -ParentDomainName $parentDomainName `
        -NewDomainName $domainName `
        -InstallDNS:$true `
        -CreateDnsDelegation `
        -DomainMode WinThreshold `
        -SafeModeAdministratorPassword $passwordSecure `
        -Credential $credential `
        -NewDomainNetbiosName $netbios `
        -NoRebootOnCompletion:$true `
        -SiteName "Graz" `
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
    Set-DnsClientServerAddress -InterfaceAlias $networkAdapter.NewName -ServerAddresses $networkAdapter.DNSBeforeDomain
}


function Install-SSH {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Start-Service sshd
    Set-Service -Name sshd -StartupType 'Automatic'
}

function Set-DNSAfterDomain {
    Set-DnsClientServerAddress -InterfaceAlias $networkAdapter.NewName -ServerAddresses $networkAdapter.DNS
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
        #shutdown /r /t 0
    }
    3 { 
        Set-SConfig -AutoLaunch $false
        Set-DNSAfterDomain
    }
}
