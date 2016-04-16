
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
    Import-DscResource -ModuleName rsWPI
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
        WindowsFeature WebManagementService {
            Ensure = "Present"
            Name = "Web-Mgmt-Service"
        }
        WindowsFeature MSMQ {
            Name = "MSMQ"
            Ensure = "Present"
        }
        rsWPI WebDeploysPS {
            Product = "WDeployPS"
        }
    }
}

WebNode -ConfigurationData $ConfigurationData
Start-DscConfiguration -Path .\WebNode -Wait -Verbose -Force