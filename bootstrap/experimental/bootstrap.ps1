
Start-Transcript -Path C:\cloud-automation\bootstrap.log -Append

# Install WMF5 without rebooting
function Install-WMF5 {
    $WMF5FileName = "Win8.1AndW2K12R2-KB3134758-x64.msu"
    $WMF5BaseURL = "https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB"
    $WMF5TempDir = "${Env:WinDir}\Temp"

    (New-Object -TypeName System.Net.webclient).DownloadFile("${WMF5BaseURL}/${WMF5FileName}", "${WMF5TempDir}\${WMF5FileName}")
    Start-Process -Wait -FilePath "${WMF5TempDir}\${WMF5FileName}" -ArgumentList '/quiet /norestart' -Verbose
}

# Set up a boot task
function Create-BootTask {
    if (Get-ScheduledTask -TaskName 'rsBoot' -ErrorAction SilentlyContinue) {
        return
    }
    $A = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -file C:\cloud-automation\setup.ps1"
    $T = New-ScheduledTaskTrigger -AtStartup
    $P = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
    $S = New-ScheduledTaskSettingsSet
    $D = New-ScheduledTask -Action $A -Principal $P -Trigger $T -Settings $S
    Register-ScheduledTask rsBoot -InputObject $D
}

# Write a setup script using a here-doc string
@'
Start-Transcript -Path C:\cloud-automation\setup.log -Append

# Read our config.json

$ConfigFile = "C:\cloud-automation\config.json"
$ConfigObject = (Get-Content $ConfigFile) -join "`n" | ConvertFrom-Json

$PSVersionTable

Get-InstalledModule
Get-Module

Get-DscConfiguration
Get-DscConfigurationStatus

Get-PackageSource
Get-PackageProvider
Get-PSRepository

# Get-DscResource

# Install the NuGet package provider
Install-PackageProvider -Name NuGet -Force
Get-PackageProvider

# Let's trust the PSGallery source
Set-PackageSource -Trusted -Name PSGallery -ProviderName PowerShellGet
Get-PackageSource
Get-PSRepository

<#
Our Module manifest contains an explicit RequiredVersion that MUST be set
to avoid any surprises.
#>
$ModuleManifest = @{
    "xTimeZone" = @{
        "Name" = "xTimeZone"
        "Repository" = "PSGallery"
        "RequiredVersion" = "1.3.0.0"
    }
    "xWebAdministration" = @{
        "Name" = "xWebAdministration"
        "Repository" = "PSGallery"
        "RequiredVersion" = "1.10.0.0"
    }
    "xNetworking" = @{
        "Name" = "xNetworking"
        "Repository" = "PSGallery"
        "RequiredVersion" = "2.8.0.0"
    }
}
$ModuleManifest.GetEnumerator() | % {
    Write-Host "Installing $($_.value["Name"]) version $($_.value["RequiredVersion"])"
    Install-Module -Verbose $_.value["Name"] -RequiredVersion $_.value["RequiredVersion"]
}

$Hostname = $env:COMPUTERNAME
$PublicIP = ((Get-NetIPConfiguration).IPv4Address | Where-Object {$_.InterfaceAlias -eq "public0"}).IpAddress

$ConfigObject.CallbackURLs.GetEnumerator() | %{
    Write-Host "Sending request to callback URL: $_"
    Invoke-RestMethod -Uri $_
}

Stop-Transcript
'@ | Out-File c:\cloud-automation\setup.ps1

Create-BootTask
Install-WMF5
Stop-Transcript
Restart-Computer