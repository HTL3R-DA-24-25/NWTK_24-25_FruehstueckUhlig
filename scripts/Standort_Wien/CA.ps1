$stage = 1
$password = "ganzgeheim123!"
$domainName = "wien.FruUhl.at"
$computerName = "CA"
$domainAdministratorUser = "Administrator"
$localAdministratorUser = "Administrator"
$ntpServer = "time.FruUhl.at"

$distinguishedName = ""
foreach ($part in $domainName.Split(".")) {
    $distinguishedName += "DC=$part,"
}
$distinguishedName = $distinguishedName.TrimEnd(",")

$CAName = "RootCA"  # Name of the Certification Authority
$CRLDistributionPoints = @(
    "file:///C:/Windows/System32/CertSrv/CertEnroll/$CAName.crl",
    "http://pki.yourdomain.com/pki/$CAName.crl",
    "ldap:///CN=$CAName,CN=CDP,CN=Public Key Services,CN=Services,CN=Configuration,$distinguishedName"
)
$CAParams = @{
    CAType              = 'EnterpriseRootCA'
    CACommonName        = $CAName
    KeyLength           = 4096
    HashAlgorithm       = 'SHA256'
    ValidityPeriod      = 'Years'
    ValidityPeriodUnits = 10
    DatabaseDirectory   = 'C:\Windows\System32\CertSrv'
    LogDirectory        = 'C:\Windows\System32\CertSrv'
}
    
$networkAdapter = @{
    Name           = "E*"
    NewName        = "DC"
    IPAddress      = "192.168.10.3"
    PrefixLength   = "24"
    DefaultGateway = "192.168.10.254"
    DNS            = ("192.168.10.1", "192.168.10.2")
}

$passwordSecure = $(ConvertTo-SecureString $password -AsPlainText -Force)
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ("$domainAdministratorUser@$domainName", $passwordSecure)

function Set-DefaultConfiguration {
    Set-WinUserLanguageList -LanguageList "de-DE" -Force
    Set-LocalUser -Name $localAdministratorUser -Password $passwordSecure
    Rename-Computer -NewName $computerName
    Set-SConfig -AutoLaunch $false
}

function Join-ADDomain {
    Add-Computer -DomainName $domainName -Credential $credential -Restart:$false -Force 
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

function Install-CertificateAuthority {
    Install-WindowsFeature AD-Certificate -IncludeManagementTools 
    Install-AdcsCertificationAuthority @CAParams
    foreach ($Path in $CRLDistributionPoints) {
        Add-CACRLDistributionPoint -Uri $Path -Force
    }
    certutil -crl

    $AIAPaths = @(
        "http://pki.$domainName/pki/$CAName.crt",
        "ldap:///CN=$CAName,CN=AIA,CN=Public Key Services,CN=Services,CN=Configuration,$distinguishedName"
    )
    foreach ($Path in $AIAPaths) {
        Add-CAAuthorityInformationAccess -Uri $Path -Force
    }
}

switch ($stage) {
    1 { 
        Set-DefaultConfiguration
        Set-NetworkConfiguration
        Install-SSH
        # shutdown /r /t 0
    }
    2 {
        Join-ADDomain
        # shutdown /r /t 0
    }
    3 {
        Install-CertificateAuthority
    }
}