
# Define variables
$domainName = "corp.fenrir-ot.at"

$minPasswordLengthGpoName = "Minimum Password Length Policy"
$desktopWallpaperGpoName = "Desktop Wallpaper Policy"
$defaultBrowserHomepageGpoName = "Default Browser Homepage Policy"
$hidingLastUserGpoName = "Hiding Last User Policy"
$loginScreenGpoName = "Login Screen Policy"
$driveMountGpoName = "Drive Mount Policy"
$firewallGpoName = "Firewall Policy"



$wallpaperPath = "\\nfs\wallpapers\wallpaper.jpg"
$homepageUrl = "https://www.fenrir-ot.at" 
$sharePath = "\\nfs\share"
$loginScreenPath = "\\nfs\wallpapers\loginscreen.jpg"

$distinguishedName = ""
foreach ($part in $domainName.Split(".")) {
    $distinguishedName += "DC=$part,"
}
$distinguishedName = $distinguishedName.TrimEnd(",")

# Minimum Password Length
Write-Host "Creating GPO for Minimum Password Length..."
New-GPO -Name $minPasswordLengthGpoName | Out-Null
Set-GPRegistryValue -Name $minPasswordLengthGpoName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Network" -ValueName "MinPwdLen" -Type DWORD -Value 8

# Desktop Wallpaper
Write-Host "Creating GPO for Desktop Wallpaper..."
New-GPO -Name $desktopWallpaperGpoName | Out-Null
Set-GPRegistryValue -Name $desktopWallpaperGpoName -Key "HKCU\Control Panel\Desktop" -ValueName "WallPaper" -Type String -Value $wallpaperPath
Set-GPRegistryValue -Name $desktopWallpaperGpoName -Key "HKCU\Control Panel\Desktop" -ValueName "TileWallpaper" -Type String -Value "0"
Set-GPRegistryValue -Name $desktopWallpaperGpoName -Key "HKCU\Control Panel\Desktop" -ValueName "WallpaperStyle" -Type String -Value "10"
Set-GPRegistryValue -Name $desktopWallpaperGpoName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "NoChangingWallPaper" -Type DWord -Value 1

# Default Browser Homepage . halt nur in IE weil Edge fuck you
Write-Host "Creating GPO for Default Browser Homepage..."
New-GPO -Name $defaultBrowserHomepageGpoName | Out-Null
Set-GPRegistryValue -Name $defaultBrowserHomepageGpoName -Key "HKCU\Software\Microsoft\Internet Explorer\Main" -ValueName "Start Page" -Type String -Value $homepageUrl
Set-GPRegistryValue -Name $defaultBrowserHomepageGpoName -Key "HKCU\Software\Microsoft\Internet Explorer\Main" -ValueName "Default_Page_URL" -Type String -Value $homepageUrl

# Hiding Last User
Write-Host "Creating GPO for Hiding Last User..."
New-GPO -Name $hidingLastUserGpoName | Out-Null
Set-GPRegistryValue -Name $hidingLastUserGpoName -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "dontdisplaylastusername" -Type DWORD -Value 1
$gpo = Get-GPO -Name $hidingLastUserGpoName
$gpo | Set-GPPermission -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group 

# Login Screen
Write-Host "Creating GPO for Login Screen..."
New-GPO -Name $loginScreenGpoName | Out-Null
Set-GPRegistryValue -Name $loginScreenGpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" -ValueName "LockScreenImage" -Type String -Value "$loginScreenPath"
$gpo = Get-GPO -Name $loginScreenGpoName
$gpo | Set-GPPermission -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group 

# Drive Mount
Write-Host "Creating GPO for Drive Mount..."
New-GPO -Name $driveMountGpoName | Out-Null
$keyPath = "HKCU\Network\F:"
Set-GPRegistryValue -Name $driveMountGpoName -Key $keyPath -ValueName "RemotePath" -Type String -Value "$sharePath"
Set-GPRegistryValue -Name $driveMountGpoName -Key $keyPath -ValueName "DeferFlags" -Type DWord -Value 1
Set-GPRegistryValue -Name $driveMountGpoName -Key $keyPath -ValueName "UserName" -Type String -Value ""
Set-GPRegistryValue -Name $driveMountGpoName -Key $keyPath -ValueName "ProviderName" -Type String -Value "Share"

# Firewall
Write-Host "Creating GPO for Firewall..."
New-GPO -Name $firewallGpoName | Out-Null
Set-GPRegistryValue -Name $firewallGpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile" -ValueName "EnableFirewall" -Type DWord -Value 1
Set-GPRegistryValue -Name $firewallGpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\PrivateProfile" -ValueName "EnableFirewall" -Type DWord -Value 1
Set-GPRegistryValue -Name $firewallGpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile" -ValueName "EnableFirewall" -Type DWord -Value 1
$gpo = Get-GPO -Name $firewallGpoName
$gpo | Set-GPPermission -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group 



# TODO - Specify OU to link GPOs to
New-GPLink -Name $minPasswordLengthGpoName -Target "OU=Accounts,$distinguishedName" -LinkEnabled Yes
New-GPLink -Name $desktopWallpaperGpoName -Target "OU=Accounts,$distinguishedName" -LinkEnabled Yes
New-GPLink -Name $defaultBrowserHomepageGpoName -Target "OU=Accounts,$distinguishedName" -LinkEnabled Yes
New-GPLink -Name $driveMountGpoName -Target "OU=Accounts,$distinguishedName" -LinkEnabled Yes

New-GPLink -Name $hidingLastUserGpoName -Target "$distinguishedName" -LinkEnabled Yes
New-GPLink -Name $loginScreenGpoName -Target "$distinguishedName" -LinkEnabled Yes
New-GPLink -Name $firewallGpoName -Target "$distinguishedName" -LinkEnabled Yes
