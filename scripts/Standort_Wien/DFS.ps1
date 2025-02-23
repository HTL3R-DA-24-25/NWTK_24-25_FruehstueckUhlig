$stage = 3
$password = "ganzgeheim123!"
$domainName = "wien.FruUhl.at"
$computerName = "DFS"
$domainAdministratorUser = "Administrator"
$localAdministratorUser = "Administrator"
$ntpServer = "time.FruUhl.at"
$FolderName = "DFS"

$NamespaceName = "Shares"

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

    if ( -not (Test-Path -Path "C:\DFSRoot") ) {
        New-Item -Path "C:\DFSRoot" -ItemType Directory
    }
    if ( -not (Test-Path -Path "C:\DFSRoot\Shares") ) {
        New-Item -Path "C:\DFSRoot\Shares" -ItemType Directory
    }
    New-SmbShare -Name "Shares" -Path "C:\DFSRoot\Shares" -FullAccess "Everyone"
    New-DfsnRoot -Path "\\$($domainName)\Shares" -TargetPath "\\$($computerName).$($domainName)\Shares" -Type DomainV2 -EnableRootScalability $true


    # Define the folders and their properties
    $folders = @(
        @{
            Name        = "RoamingProfiles"
            ShareName   = "RoamingProfiles$"  # Hidden share (optional)
            Description = "Folder for Roaming User Profiles"
            Permissions = "Read"  # Set permissions for the share
        },
        @{
            Name        = "Wallpapers"
            ShareName   = "Wallpapers"
            Description = "Read-only folder for Wallpapers"
            Permissions = "Read"  # Set permissions for the share
        },
        @{
            Name        = "Shared"
            ShareName   = "Shared"
            Description = "Shared folder with write access for anyone"
            Permissions = "Write"  # Set permissions for the share
        }
    )

    $basePath = "C:\DFSRoot\Shares"
    $server = "$computerName.$domainName"

    # Create each shared folder and add it to the DFS namespace
    foreach ($folder in $folders) {
        $folderName = $folder.Name
        $shareName = $folder.ShareName
        $folderPath = Join-Path -Path $basePath -ChildPath $folderName
        $sharePath = "\\$server\$shareName"
        $description = $folder.Description
        $permissions = $folder.Permissions

        # Create the folder if it doesn't exist
        if (-not (Test-Path -Path $folderPath)) {
            New-Item -Path $folderPath -ItemType Directory
        }

        # Share the folder
        New-SmbShare -Name $shareName -Path $folderPath -Description $description

        # Set share permissions
        if ($permissions -eq "Read") {
            Grant-SmbShareAccess -Name $shareName -AccountName "Everyone" -AccessRight Read -Force
        }
        elseif ($permissions -eq "Write") {
            Grant-SmbShareAccess -Name $shareName -AccountName "Everyone" -AccessRight Change -Force
        }
        elseif ($permissions -eq "Full") {
            Grant-SmbShareAccess -Name $shareName -AccountName "Everyone" -AccessRight Full -Force
        }

        # Add the folder to the DFS namespace
        $dfsFolderPath = "\\$($domainName)\Shares\$folderName"
        New-DfsnFolder -Path $dfsFolderPath -TargetPath $sharePath -Description $description

        Write-Host "Created and shared folder: $dfsFolderPath -> $sharePath"
    }

    Write-Host "DFS namespace setup complete!"
        
        
    
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
        Install-DFS
    }
}