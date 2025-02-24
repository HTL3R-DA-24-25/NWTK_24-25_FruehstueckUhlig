$stage = 5
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

$minPasswordLengthGpoName = "Minimum Password Length Policy"
$desktopWallpaperGpoName = "Desktop Wallpaper Policy"
$defaultBrowserHomepageGpoName = "Default Browser Homepage Policy"
$hidingLastUserGpoName = "Hiding Last User Policy"
$loginScreenGpoName = "Login Screen Policy"
$driveMountGpoName = "Drive Mount Policy"
$firewallGpoName = "Firewall Policy"
$vbsGpoName = "Virtualisation Based Security Policy"
$credentialGuardGpoName = "Credential Guard Policy"

$wallpaperPath = "\\$($domainName)\Shares\wallpapers\Background.png"
$homepageUrl = "https://www.htl.rennweg.at" 
$sharePath = "\\$($domainName)\Shares\Shared"
$loginScreenPath = "\\$($domainName)\Shares\wallpapers\LoginScreen.png"
$roamingProfilePath = "\\$($domainName)\Shares\RoamingProfiles"



$ous = @(
    @{
        Name = "Sales"
        Path = "OU=All,$distinguishedName"
    }, @{
        Name = "Marketing"
        Path = "OU=All,$distinguishedName"
    }, @{
        Name = "Operations"
        Path = "OU=All,$distinguishedName"
    }, @{
        Name = "Management"
        Path = "OU=All,$distinguishedName"
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
        Path         = "OU=Users,OU=Sales,OU=All,$distinguishedName"
    }, @{
        Name         = "Bastian Uhlig"
        UserName     = "bUhlig"
        GlobalGroups = @("G_Marketing")
        Path         = "OU=Users,OU=Marketing,OU=All,$distinguishedName"
    }, @{
        Name         = "Alfred Bauer"
        UserName     = "aBauer"
        GlobalGroups = @("G_Operations", "Protected Users")
        Path         = "OU=Users,OU=Operations,OU=All,$distinguishedName"
    }, @{
        Name         = "Christine Maier"
        UserName     = "cMaier"
        GlobalGroups = @("G_Management")
        Path         = "OU=Users,OU=Management,OU=All,$distinguishedName"
    }
)

$passwordSecure = $(ConvertTo-SecureString $password -AsPlainText -Force)

function Set-Sites {
    Rename-ADObject -Identity "CN=Default-First-Site-Name,CN=Sites,CN=Configuration,$distinguishedName" -NewName "Wien"
    New-ADReplicationSubnet -Name "192.168.0.0/24" -Site "Wien"
    New-ADReplicationSubnet -Name "192.168.10.0/24" -Site "Wien"
    New-ADReplicationSubnet -Name "192.168.100.0/24" -Site "Wien"
    New-ADReplicationSite -Name "Rennweg"
    New-ADReplicationSubnet -Name "172.16.100.0/24" -Site "Rennweg"
    New-ADReplicationSite -Name "Graz"
    New-ADReplicationSubnet -Name "172.16.0.0/24" -Site "Graz"
    New-ADReplicationSubnet -Name "172.16.10.0/24" -Site "Graz"
    New-ADReplicationSiteLink -Name "Wien-Rennweg" -SitesIncluded Wien, Rennweg -Cost 100 -ReplicationFrequencyInMinutes 15 -InterSiteTransportProtocol IP
    New-ADReplicationSiteLink -Name "Wien-Graz" -SitesIncluded Wien, Graz -Cost 100 -ReplicationFrequencyInMinutes 15 -InterSiteTransportProtocol IP
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
    New-ADOrganizationalUnit -Name "All" -Path $distinguishedName
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
        if (-not (Get-ADGroup -Filter "Name -eq 'DL_$($group)_M'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name "DL_$($group)_M" -Path "OU=Groups,$distinguishedName" -GroupScope DomainLocal -GroupCategory Security
            Write-Host "Domain-Local Gruppe wurde erfolgreich erstellt: DL_$($group)_M"
        }
        else {
            Write-Host "Domain-Local Gruppe existiert bereits: DL_$($group)_M"
        }
        if (-not (Get-ADGroup -Filter "Name -eq 'DL_$($group)_R'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name "DL_$($group)_R" -Path "OU=Groups,$($distinguishedName)" -GroupScope DomainLocal -GroupCategory Security
            Write-Host "Domain-Local Gruppe wurde erfolgreich erstellt: DL_$($group)_R"
        }
        else {
            Write-Host "Domain-Local Gruppe existiert bereits: DL_$($group)_R"
        }
    }
}

function Add-GPOs {

    # Minimum Password Length
    New-GPO -Name $minPasswordLengthGpoName | Out-Null
    Set-GPRegistryValue -Name $minPasswordLengthGpoName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Network" -ValueName "MinPwdLen" -Type DWORD -Value 8

    # Desktop Wallpaper
    New-GPO -Name $desktopWallpaperGpoName | Out-Null
    Set-GPRegistryValue -Name $desktopWallpaperGpoName -Key "HKCU\Control Panel\Desktop" -ValueName "WallPaper" -Type String -Value $wallpaperPath
    Set-GPRegistryValue -Name $desktopWallpaperGpoName -Key "HKCU\Control Panel\Desktop" -ValueName "TileWallpaper" -Type String -Value "0"
    Set-GPRegistryValue -Name $desktopWallpaperGpoName -Key "HKCU\Control Panel\Desktop" -ValueName "WallpaperStyle" -Type String -Value "10"
    Set-GPRegistryValue -Name $desktopWallpaperGpoName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "NoChangingWallPaper" -Type DWord -Value 1

    # Default Browser Homepage . halt nur in IE weil Edge fuck you
    New-GPO -Name $defaultBrowserHomepageGpoName | Out-Null
    Set-GPRegistryValue -Name $defaultBrowserHomepageGpoName -Key "HKCU\Software\Microsoft\Internet Explorer\Main" -ValueName "Start Page" -Type String -Value $homepageUrl
    Set-GPRegistryValue -Name $defaultBrowserHomepageGpoName -Key "HKCU\Software\Microsoft\Internet Explorer\Main" -ValueName "Default_Page_URL" -Type String -Value $homepageUrl

    # Hiding Last User
    New-GPO -Name $hidingLastUserGpoName | Out-Null
    Set-GPRegistryValue -Name $hidingLastUserGpoName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "dontdisplaylastusername" -Type DWORD -Value 1
    $gpo = Get-GPO -Name $hidingLastUserGpoName
    $gpo | Set-GPPermission -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group 

    # Login Screen
    New-GPO -Name $loginScreenGpoName | Out-Null
    Set-GPRegistryValue -Name $loginScreenGpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" -ValueName "LockScreenImage" -Type String -Value "$loginScreenPath"
    $gpo = Get-GPO -Name $loginScreenGpoName
    $gpo | Set-GPPermission -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group 

    # Drive Mount
    New-GPO -Name $driveMountGpoName | Out-Null
    $keyPath = "HKCU\Network\F:"
    Set-GPRegistryValue -Name $driveMountGpoName -Key $keyPath -ValueName "RemotePath" -Type String -Value "$sharePath"
    Set-GPRegistryValue -Name $driveMountGpoName -Key $keyPath -ValueName "DeferFlags" -Type DWord -Value 1
    Set-GPRegistryValue -Name $driveMountGpoName -Key $keyPath -ValueName "UserName" -Type String -Value ""
    Set-GPRegistryValue -Name $driveMountGpoName -Key $keyPath -ValueName "ProviderName" -Type String -Value "Share"

    # Firewall
    New-GPO -Name $firewallGpoName | Out-Null
    Set-GPRegistryValue -Name $firewallGpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile" -ValueName "EnableFirewall" -Type DWord -Value 1
    Set-GPRegistryValue -Name $firewallGpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\PrivateProfile" -ValueName "EnableFirewall" -Type DWord -Value 1
    Set-GPRegistryValue -Name $firewallGpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile" -ValueName "EnableFirewall" -Type DWord -Value 1
    $gpo = Get-GPO -Name $firewallGpoName
    $gpo | Set-GPPermission -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group 

    # Enable VBS
    New-GPO -Name "Device Hardening" | Out-Null
    Set-GPRegistryValue -Name $vbsGpoName -Key "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" -ValueName "EnableVirtualizationBasedSecurity" -Type DWord -Value 1

    # Enable Credential Guard
    New-GPO -Name $credentialGuardGpoName -Key "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LsaCfgFlags" -Type DWord -Value 2

    # Check if running: (Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard).SecurityServicesRunning


    # Linking GPOs to OUs
    New-GPLink -Name $minPasswordLengthGpoName -Target "OU=All,$distinguishedName" -LinkEnabled Yes
    New-GPLink -Name $desktopWallpaperGpoName -Target "OU=All,$distinguishedName" -LinkEnabled Yes
    New-GPLink -Name $defaultBrowserHomepageGpoName -Target "OU=All,$distinguishedName" -LinkEnabled Yes
    New-GPLink -Name $driveMountGpoName -Target "OU=All,$distinguishedName" -LinkEnabled Yes

    New-GPLink -Name $hidingLastUserGpoName -Target "$distinguishedName" -LinkEnabled Yes
    New-GPLink -Name $loginScreenGpoName -Target "$distinguishedName" -LinkEnabled Yes
    New-GPLink -Name $firewallGpoName -Target "$distinguishedName" -LinkEnabled Yes

    New-GPLink -Name $vbsGpoName -Target "CN=Client1,CN=Computers,$distinguishedName" -LinkEnabled Yes
    New-GPLink -Name $credentialGuardGpoName -Target "CN=Client1,CN=Computers,$distinguishedName" -LinkEnabled Yes
}

function Set-RoamingProfiles {
    $acl = Get-Acl $roamingProfilePath
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Domain Users", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($rule)
    Set-Acl -Path $roamingProfilePath -AclObject $acl
    
    foreach ($user in $users) {
        $userPath = Join-Path -Path $roamingProfilePath -ChildPath $user.UserName
        if (-not (Test-Path -Path $userPath)) {
            New-Item -Path $userPath -ItemType Directory
        }
        Set-ADUser -Identity $user.UserName -ProfilePath $userPath
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
        Set-Sites
        Add-GPOs
    }
}