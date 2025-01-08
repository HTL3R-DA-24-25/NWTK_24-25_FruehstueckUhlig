$stage = 1
$password = "ganzgeheim123!"
$domainName = "wien.FruUhl.at"
$computerName = "DC1"
$netbios = "WIEN"
$localAdministratorUserName = "Administrator"
$ntpServer = "time.FruUhl.at"

$networkAdapter = @{
    Name           = "E*"
    NewName        = "DC"
    IPAddress      = "192.168.10.1"
    PrefixLength   = "24"
    DefaultGateway = "192.168.10.254"
    DNS            = ("192.168.10.1", "1.1.1.1")
}

$distinguishedName = ""
foreach ($part in $domainName.Split(".")) {
    $distinguishedName += "DC=$part,"
}
$distinguishedName = $distinguishedName.TrimEnd(",")


$ous = @(
    @{
        Name = "Sales"
        Path = "$distinguishedName"
    }, @{
        Name = "Marketing"
        Path = "$distinguishedName"
    }, @{
        Name = "Operations"
        Path = "$distinguishedName"
    }, @{
        Name = "Management"
        Path = "$distinguishedName"
    }
)

$globalGroups = @(
    @{
        Name     = "Sales"
        MemberOf = @("Sales_M", "Marketing_R", "Management_R", "Templates_R")
    }, @{
        Name     = "Marketing"
        MemberOf = @("Marketing_M", "Operations_R", "Templates_R")
    }, @{
        Name     = "Operations"
        MemberOf = @("Operations_M", "Templates_R")
    }, @{
        Name     = "Management"
        MemberOf = @("Sales_R", "Operations_R", "Management_M", "Templates_M")
    }
)
$domainLocalGroups = @("Wien_Templates", "Wien_Sales", "Wien_Marketing", "Wien_Operations", "Wien_Management")
$universialGroups = @("Templates", "Sales", "Marketing", "Operations", "Management")

$users = @(
    @{
        Name         = "Linus Frühstück"
        UserName     = "lFreuhstueck"
        GlobalGroups = @("G_Sales")
        Path         = "OU=Sales,$distinguishedName"
    }, @{
        Name         = "Bastian Uhlig"
        UserName     = "bUhlig"
        GlobalGroups = @("G_Marketing")
        Path         = "OU=Marketing,$distinguishedName"
    }, @{
        Name         = "Alfred Bauer"
        UserName     = "aBauer"
        GlobalGroups = @("G_Operations")
        Path         = "OU=Operations,$distinguishedName"
    }, @{
        Name         = "Christine Maier"
        UserName     = "cMaier"
        GlobalGroups = @("G_Management")
        Path         = "OU=Management,$distinguishedName"
    }
)

$passwordSecure = $(ConvertTo-SecureString $password -AsPlainText -Force)

function Set-Sites {
    Rename-ADObject -Identity "CN=Default-First-Site-Name,CN=Sites,CN=Configuration,$distinguishedName" -NewName "Wien"
    New-ADReplicationSubnet -Name "192.168.10.0/24" -Site "Wien"
    New-ADReplicationSubnet -Name "192.168.100.0/24" -Site "Wien"
}

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
    w32tm /config /manualpeerlist:"$ntpServer" /syncfromflags:manual /reliable:yes /update 
    Restart-Service w32time
}

function Install-SSH {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Start-Service sshd
    Set-Service -Name sshd -StartupType 'Automatic'
}

function Set-OUs {
    foreach ($ou in $ous) {
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq 'OU=$($ou.Name),$($ou.Path)'" -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $ou.Name -Path $ou.Path
            New-ADOrganizationalUnit -Name "Computers" -Path "OU=$($ou.Name),$($ou.Path)"
            New-ADOrganizationalUnit -Name "Users" -Path "OU=$($ou.Name),$($ou.Path)"
            New-ADOrganizationalUnit -Name "Special Accounts" -Path "OU=$($ou.Name),$($ou.Path)"
            Write-Host "OU wurde erfolgreich erstellt: $($ou.Name)"
        }
        else {
            Write-Host "OU existiert bereits: $($ou.Name)"
        }
    } 
}

function Add-GlobalGroups {
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq 'OU=Groups, $($distinguishedName)'")) {
        New-ADOrganizationalUnit -Name "Groups" -Path $distinguishedName
    }
    foreach ($group in $globalGroups) {
        if (-not (Get-ADGroup -Filter "Name -eq 'G_$($group.Name)'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name "G_$($group.Name)" -Path "OU=Groups,$distinguishedName" -GroupScope Global -GroupCategory Security
            foreach ($parent in $group.MemberOf) {
                Add-ADGroupMember -Identity "U_$parent" -Members "G_$($group.Name)"
            }
            Write-Host "Globale Gruppe wurde erfolgreich erstellt: G_$($group.Name)"
        }
        else {
            Write-Host "Globale Gruppe existiert bereits: G_$($group.Name)"
        }
    }
}

function Add-Users {
    foreach ($user in $users) {
        if (-not (Get-ADUser -Filter "Name -eq '$($user.UserName)'" -ErrorAction SilentlyContinue)) {
            New-ADUser -Name $user.UserName -Path $user.Path -AccountPassword $passwordSecure -ChangePasswordAtLogon $false -Enabled $true -GivenName $user.FullName -DisplayName $user.FullName -UserPrincipalName "$($user.UserName)@$domainName"
            Write-Host "Benutzer wurde erfolgreich erstellt: $($user.UserName)"
        }
        else {
            Write-Host "Benutzer existiert bereits: $($user.UserName)"
        }
        foreach ($group in $user.GlobalGroups) {
            Add-ADGroupMember -Identity "$($group)" -Members $user.UserName
        }
    }
}
function Add-UniversalGroups {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Groups'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name "Groups" -Path $distinguishedName
    }
    foreach ($group in $universialGroups) {
        if (-not (Get-ADGroup -Filter "Name -eq 'U_$($group)_M'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name "U_$($group)_M" -Path "OU=Groups,$distinguishedName" -GroupScope Universal -GroupCategory Security
            Add-ADGroupMember -Identity "DL_Wien_$($group)_M" -Members "U_$($group)_M"
            Write-Host "Universal Gruppe wurde erfolgreich erstellt: U_$($group)_M"
        }
        else {
            Write-Host "Universal Gruppe existiert bereits: U_$($group)_M"
        }
        if (-not (Get-ADGroup -Filter "Name -eq 'U_$($group)_R'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name "U_$($group)_R" -Path "OU=Groups,$distinguishedName" -GroupScope Universal -GroupCategory Security
            Add-ADGroupMember -Identity "DL_Wien_$($group)_R" -Members "U_$($group)_R"
            Write-Host "Universal Gruppe wurde erfolgreich erstellt: U_$($group)_R"
        }
        else {
            Write-Host "Universal Gruppe existiert bereits: U_$($group)_R"
        }
    }
}

function Add-DomainLocalGroups {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Groups'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name "Groups" -Path $distinguishedName
    }
    foreach ($group in $domainLocalGroups) {
        if (-not (Get-ADGroup -Filter "Name -eq 'DL_Wien_$($group)_M'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name "DL_Wien_$($group)_M" -Path "OU=Groups,$distinguishedName" -GroupScope DomainLocal -GroupCategory Security
            Write-Host "Domain-Local Gruppe wurde erfolgreich erstellt: DL_$($group)_M"
        }
        else {
            Write-Host "Domain-Local Gruppe existiert bereits: DL_$($group)_M"
        }
        if (-not (Get-ADGroup -Filter "Name -eq 'DL_Wien_$($group)_R'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name "DL_Wien_$($group)_R" -Path "OU=Groups,$($distinguishedName)" -GroupScope DomainLocal -GroupCategory Security
            Write-Host "Domain-Local Gruppe wurde erfolgreich erstellt: DL_$($group)_R"
        }
        else {
            Write-Host "Domain-Local Gruppe existiert bereits: DL_$($group)_R"
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
        Install-ActiveDirectory
        shutdown /r /t 0
    }
    3 {
        Set-OUs
        Add-DomainLocalGroups
        Add-UniversalGroups
        Add-GlobalGroups
        Add-Users
    }
}