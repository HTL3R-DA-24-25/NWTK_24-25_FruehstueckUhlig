$stage = 2
$password = "ganzgeheim123!"
$domainName = "wien.FruUhl.at"
$computerName = "DFS"
$domainAdministratorUser = "Administrator"
$localAdministratorUser = "Administrator"
$ntpServer = "time.FruUhl.at"
$NamespaceName = "DFSFruUhl"
$FolderName = "DFS"

$distinguishedName = ""
foreach ($part in $domainName.Split(".")) {
    $distinguishedName += "DC=$part,"
}
$distinguishedName = $distinguishedName.TrimEnd(",")
    
$networkAdapter = @{
    Name           = "E*"
    NewName        = "DC"
    IPAddress      = "192.168.10.10"
    PrefixLength   = "24"
    DefaultGateway = "192.168.10.254"
    DNS            = ("192.168.10.1", "192.168.10.2")
}

$folders = @("Templates", "Sales", "Marketing", "Operations", "Management")

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

function Install-DFS {
    Add-WindowsFeature FS-DFS-Namespace, FS-DFS-Replication -IncludeManagementTools

    New-DfsnRoot -Path "\\$($domainName)\$NamespaceName" -Type DomainV2
    

    foreach ($folder in $folders) {
        if (-not (Test-Path "C:\$FolderName\$folder")) {
            New-DfsnFolder -Path "\\$($domainName)\$NamespaceName" -TargetPath "C:\$FolderName\$folder"
            $acl = New-Object System.Security.AccessControl.DirectorySecurity
            $readRule = New-Object System.Security.AccessControl.FileSystemAccessRule("DL_Wien_$($folder)_M", "ReadAndExecute", "Allow")
            $modifyRule = New-Object System.Security.AccessControl.FileSystemAccessRule("DL_Wien_$($folder)_M", "Modify", "Allow")
            $acl.AddAccessRule($readRule)
            $acl.AddAccessRule($modifyRule)
            Set-Acl -Path "C:\$FolderName\$folder" -AclObject $acl
        }
    }
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
        Install-DFS
    }
}