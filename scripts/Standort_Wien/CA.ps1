$stage = 3
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
    
$networkAdapter = @{
    Name           = "E*"
    NewName        = "DC"
    IPAddress      = "192.168.10.5"
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

function Install-ADCS {
    Add-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools
        Install-AdcsCertificationAuthority -CAType EnterpriseRootCa `
        -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
        -KeyLength 2048 `
        -HashAlgorithmName SHA256 `
        -CACommonName "FruUhl Root CA" `
        -CADistinguishedNameSuffix "$distinguishedName" `
        -ValidityPeriod Years `
        -ValidityPeriodUnits 10
    Certutil -setreg CA\CRLPeriodUnits 1
    Certutil -setreg CA\CRLPeriod "Weeks"
    Certutil -setreg CA\CRLDeltaPeriodUnits 1
    Certutil -setreg CA\CRLDeltaPeriod "Days"
    Certutil -setreg CA\CRLOverlapPeriodUnits 12
    Certutil -setreg CA\CRLOverlapPeriod "Hours"
    Certutil -setreg CA\ValidityPeriodUnits 5
    Certutil -setreg CA\ValidityPeriod "Years"
    Certutil -setreg CA\AuditFilter 127

    Certutil -setreg CA\CACertPublicationURLs "1:C:\Windows\system32\CertSrv\CertEnroll\%1_%3%4.crt\n2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n2:http://pki.wien.FruUhl.at/CertEnroll/%1_%3%4.crt"
    Certutil -setreg CA\CRLPublicationURLs "65:C:\Windows\system32\CertSrv\CertEnroll\%3%8%9.crl\n79:ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10\n6:http://pki.wien.FruUhl.at/CertEnroll/%3%8%9.crl\n65:file://\\WEB.wien.FruUhl.at\CertEnroll\%3%8%9.crl"

    Copy-Item -Path 'C:\Windows\System32\CertSrv\CertEnroll\CA.wien.FruUhl.at_FruUhl Root CA.crt' `
        -Destination '\\WEB.wien.FruUhl.at\C$\CertEnroll'
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
        Set-SConfig -AutoLaunch $false
        Set-WinUserLanguageList -LanguageList "de-DE" -Force
        Install-ADCS
    }
}