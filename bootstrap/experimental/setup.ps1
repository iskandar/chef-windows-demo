<#

* Setup any PS Repositories
* Install required DSC modules
* Trigger any Callback URLs

This script runs *after* the server has WMF5 installed.

#>
$Dir = "C:\cloud-automation"
Start-Transcript -Path $Dir\setup.log -Append
Set-Location -Path $Dir

# Read our config.json
$ConfigFile = "$Dir\config.json"
$ConfigObject = (Get-Content $ConfigFile) -join "`n" | ConvertFrom-Json

$PSVersionTable

Get-InstalledModule
Get-Module

Get-DscConfiguration
Get-DscConfigurationStatus

Get-PackageSource
Get-PackageProvider
Get-PSRepository

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
    "xComputerManagement" = @{
        "Name" = "xComputerManagement"
        "Repository" = "PSGallery"
        "RequiredVersion" = "1.5.0.0"
    }
    "xNetworking" = @{
        "Name" = "xNetworking"
        "Repository" = "PSGallery"
        "RequiredVersion" = "2.8.0.0"
    }
    "xCertificate" = @{
        "Name" = "xCertificate"
        "Repository" = "PSGallery"
        "RequiredVersion" = "1.1.0.0"
    }
    "xPendingReboot" = @{
        "Name" = "xPendingReboot"
        "Repository" = "PSGallery"
        "RequiredVersion" = "0.3.0.0"
    }
    "xWinEventLog" = @{
        "Name" = "xWinEventLog"
        "Repository" = "PSGallery"
        "RequiredVersion" = "1.1.0.0"
    }
    "xWebAdministration" = @{
        "Name" = "xWebAdministration"
        "Repository" = "PSGallery"
        "RequiredVersion" = "1.10.0.0"
    }
    "xWebDeploy" = @{
        "Name" = "xWebDeploy"
        "Repository" = "PSGallery"
        "RequiredVersion" = "1.1.0.0"
    }
}
$ModuleManifest.GetEnumerator() | % {
    Write-Host "Installing $($_.value["Name"]) version $($_.value["RequiredVersion"]); Repo $($_.value["Repository"])"
    Install-Module -Verbose $_.value["Name"] `
        -Repository $_.value["Repository"] `
        -RequiredVersion $_.value["RequiredVersion"]
}

# Send data to callback URLs
$ConfigObject.CallbackURLs.GetEnumerator() | %{
    Write-Host "(disabled) Sending request to callback URL: $_"
    # Invoke-RestMethod -Uri $_
}

# Disable the on-boot task
Write-Host "(disabled) Disabling Boot task"
# Disable-ScheduledTask -TaskName rsBoot

# Do some configuration
$ConfigurationData = @{
    AllNodes = @();
    NonNodeData = ""
}

Configuration LCMConfig {
    LocalConfigurationManager {
        CertificateID = (Get-ChildItem Cert:\LocalMachine\My)[0].Thumbprint
        AllowModuleOverwrite = $true
        ConfigurationModeFrequencyMins = 30
        ConfigurationMode = 'ApplyAndAutoCorrect'
        RebootNodeIfNeeded = $true
        RefreshMode = 'PUSH'
        RefreshFrequencyMins = 30
    }
}

LCMConfig
Set-DscLocalConfigurationManager -Path .\LCMConfig

Configuration WebNode {
    Node localhost {
        WindowsFeature IIS {
            Ensure = 'Present'
            Name = 'Web-Server'
        }

        WindowsFeature AspNet45 {
            Ensure = 'Present'
            Name = 'Web-Asp-Net45'
        }

        WindowsFeature IISConsole {
            Ensure = 'Present'
            Name = 'Web-Mgmt-Console'
        }
    }
}

WebNode -ConfigurationData $ConfigurationData
Start-DscConfiguration -Path .\WebNode -Wait -Verbose -Force

Stop-Transcript