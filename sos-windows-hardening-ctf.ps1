#####Windows Hardening CTF#####
#Continue on error
$ErrorActionPreference= 'silentlycontinue'

#Require elivation for script run
Requires -RunAsAdministrator
Write-Output "Elevating priviledges for this process"
do {} until (Elevate-Privileges SeTakeOwnershipPrivilege)

#Set Directory to PSScriptRoot
if ((Get-Location).Path -NE $PSScriptRoot) { Set-Location $PSScriptRoot }

#Unblock all files required for script
Get-ChildItem ./ -recurse | Unblock-File

#Install PowerShell Modules
Copy-Item -Path .\Files\"PowerShell Modules"\* -Destination C:\Windows\System32\WindowsPowerShell\v1.0\Modules -Force -Recurse
#Unblock New PowerShell Modules
Get-ChildItem C:\Windows\System32\WindowsPowerShell\v1.0\Modules\PSWindowsUpdate\ -recurse | Unblock-File
#Install PSWindowsUpdate
Import-Module -Name PSWindowsUpdate -Force -Global

##Install Latest Windows Updates
start-job -ScriptBlock {Install-WindowsUpdate -MicrosoftUpdate -AcceptAll; Get-WuInstall -AcceptAll -IgnoreReboot; Get-WuInstall -AcceptAll -Install -IgnoreReboot}

#Disable CMD Interactive
#reg add HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Windows\System /v DisableCMD /t REG_DWORD /d 2 /f
#Disable CMD Interactive and CMD Inline 
reg add HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Windows\System /v DisableCMD /t REG_DWORD /d 1 /f

#Automatically exit CMD when opened
reg add "HKEY_CURRENT_USER\Software\Microsoft\Command Processor" /v AutoRun /t REG_EXPAND_SZ /d "exit"

#Disable Powershell v2
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root

#Enable PowerShell Logging
#https://www.digitalshadows.com/blog-and-research/powershell-security-best-practices/
#https://www.cyber.gov.au/acsc/view-all-content/publications/securing-powershell-enterprise
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "OutputDirectory" -Type "STRING" -Value "C:\PowershellLogs" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging\" -Name "EnableScriptBlockLogging" -Type "DWORD" -Value "1" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription\" -Name "EnableTranscripting" -Type "DWORD" -Value "1" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription\" -Name "EnableInvocationHeader" -Type "DWORD" -Value "1" -Force

#Windows 10 Kernel (DMA) Protections
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\Kernel DMA Protection" -Name "DeviceEnumerationPolicy" -Type "DWORD" -Value "0" -Force

#Disable LLMNR
#https://www.blackhillsinfosec.com/how-to-disable-llmnr-why-you-want-to/
New-Item -Path "HKLM:\Software\policies\Microsoft\Windows NT\" -Name "DNSClient"
Set-ItemProperty -Path "HKLM:\Software\policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Type "DWORD" -Value 0 -Force

#Enable DEP
BCDEDIT /set "{current}" nx OptOut
Set-Processmitigation -System -Enable DEP

#Remove WSMan listeners
Get-ChildItem WSMan:\Localhost\listener | Where-Object -Property Keys -eq "Transport=HTTP" | Remove-Item -Recurse
Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse
#Disable the WSMan Service
Set-Service -Name "WinRM" -StartupType Disabled -Status Stopped
#Disable Firewall Rule
Disable-NetFirewallRule -DisplayName “Windows Remote Management (HTTP-In)”

#Disable SMB Compression - CVE-2020-0796
#https://msrc.microsoft.com/update-guide/en-US/vulnerability/CVE-2020-0796
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" DisableCompression -Type DWORD -Value 1 -Force

#Disable SMB v1
#https://docs.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3
Disable-WindowsOptionalFeature -Online -FeatureName smb1protocol
Set-SmbServerConfiguration -EnableSMB1Protocol $false
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" SMB1 -Type DWORD -Value 0 –Force

#Disable SMB v2
#https://docs.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3
Set-SmbServerConfiguration -EnableSMB2Protocol $false
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" SMB2 -Type DWORD -Value 0 –Force

#Enable SMB Encryption
#https://docs.microsoft.com/en-us/windows-server/storage/file-server/smb-security
Set-SmbServerConfiguration –EncryptData $true
Set-SmbServerConfiguration –RejectUnencryptedAccess $false

#Diable SMB Direct 
#https://docs.microsoft.com/en-us/windows-server/storage/file-server/smb-direct
Set-NetOffloadGlobalSetting -NetworkDirect Disabled

#Bad Neighbor - CVE-2020-16898 
#https://blog.rapid7.com/2020/10/14/there-goes-the-neighborhood-dealing-with-cve-2020-16898-a-k-a-bad-neighbor/
netsh int ipv6 set int *INTERFACENUMBER* rabaseddnsconfig=disable

#####SPECTURE MELTDOWN#####
#https://support.microsoft.com/en-us/help/4073119/protect-against-speculative-execution-side-channel-vulnerabilities-in
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name FeatureSettingsOverride -Type DWORD -Value 72 -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name FeatureSettingsOverrideMask -Type DWORD -Value 3 -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization" -Name MinVmVersionForCpuBasedMitigations -Type String -Value "1.0" -Force

#Windows Defender Configuration Files
mkdir "C:\temp\Windows Defender"; Copy-Item -Path .\Files\"Windows Defender Configuration Files"\* -Destination C:\temp\"Windows Defender"\ -Force -Recurse -ErrorAction SilentlyContinue

#Disable Windows Defender (Do not use)
#Uninstall-WindowsFeature -Name Windows-Defender

#Enable Windows Defender Exploit Protection
Set-ProcessMitigation -PolicyFilePath "C:\temp\Windows Defender\DOD_EP_V3.xml"

#Enable Windows Defender Application Control
#https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/select-types-of-rules-to-create
Set-RuleOption -FilePath "C:\temp\Windows Defender\WDAC_V1_Enforced.xml" -Option 0

#Windows Defender Hardening
#https://www.powershellgallery.com/packages/WindowsDefender_InternalEvaluationSetting
#Enable real-time monitoring
Write-Host "Enable real-time monitoring"
Set-MpPreference -DisableRealtimeMonitoring 0
#Enable cloud-deliveredprotection
Write-Host "Enable cloud-deliveredprotection"
Set-MpPreference -MAPSReporting Advanced
#Enable sample submission
Write-Host "Enable sample submission"
Set-MpPreference -SubmitSamplesConsent Always
#Enable checking signatures before scanning
Write-Host "Enable checking signatures before scanning"
Set-MpPreference -CheckForSignaturesBeforeRunningScan 1
#Enable behavior monitoring
Write-Host "Enable behavior monitoring"
Set-MpPreference -DisableBehaviorMonitoring 0
#Enable IOAV protection
Write-Host "Enable IOAV protection"
Set-MpPreference -DisableIOAVProtection 0
#Enable script scanning
Write-Host "Enable script scanning"
Set-MpPreference -DisableScriptScanning 0
#Enable removable drive scanning
Write-Host "Enable removable drive scanning"
Set-MpPreference -DisableRemovableDriveScanning 0
#Enable Block at first sight
Write-Host "Enable Block at first sight"
Set-MpPreference -DisableBlockAtFirstSeen 0
#Enable potentially unwanted apps
Write-Host "Enable potentially unwanted apps"
Set-MpPreference -PUAProtection Enabled
#Schedule signature updates every 8 hours
Write-Host "Schedule signature updates every 8 hours"
Set-MpPreference -SignatureUpdateInterval 8
#Enable archive scanning
Write-Host "Enable archive scanning"
Set-MpPreference -DisableArchiveScanning 0
#Enable email scanning
Write-Host "Enable email scanning"
Set-MpPreference -DisableEmailScanning 0
#Enable File Hash Computation
Write-Host "Enable File Hash Computation"
Set-MpPreference -EnableFileHashComputation 1
#Enable Intrusion Prevention System
Write-Host "Enable Intrusion Prevention System"
Set-MpPreference -DisableIntrusionPreventionSystem $false

#Enable Windows Defender Exploit Protection
Write-Host "Enabling Exploit Protection"
Set-ProcessMitigation -PolicyFilePath C:\temp\"Windows Defender"\DOD_EP_V3.xml
#Set cloud block level to 'High'
Write-Host "Set cloud block level to 'High'"
Set-MpPreference -CloudBlockLevel High
#Set cloud block timeout to 1 minute
Write-Host "Set cloud block timeout to 1 minute"
Set-MpPreference -CloudExtendedTimeout 50
Write-Host "`nUpdating Windows Defender Exploit Guard settings`n" -ForegroundColor Green 
#Enabling Controlled Folder Access and setting to block mode
Write-Host "Enabling Controlled Folder Access and setting to block mode"
Set-MpPreference -EnableControlledFolderAccess Enabled 
#Enabling Network Protection and setting to block mode
Write-Host "Enabling Network Protection and setting to block mode"
Set-MpPreference -EnableNetworkProtection Enabled

#Enable Cloud-delivered Protections
Set-MpPreference -MAPSReporting Advanced
Set-MpPreference -SubmitSamplesConsent SendAllSamples

#Enable Windows Defender Attack Surface Reduction Rules
#https://docs.microsoft.com/en-us/windows/security/threat-protection/microsoft-defender-atp/enable-attack-surface-reduction
#https://docs.microsoft.com/en-us/windows/security/threat-protection/microsoft-defender-atp/attack-surface-reduction
#Block executable content from email client and webmail
Add-MpPreference -AttackSurfaceReductionRules_Ids BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550 -AttackSurfaceReductionRules_Actions Enabled
#Block all Office applications from creating child processes
Add-MpPreference -AttackSurfaceReductionRules_Ids D4F940AB-401B-4EFC-AADC-AD5F3C50688A -AttackSurfaceReductionRules_Actions Enabled
#Block Office applications from creating executable content
Add-MpPreference -AttackSurfaceReductionRules_Ids 3B576869-A4EC-4529-8536-B80A7769E899 -AttackSurfaceReductionRules_Actions Enabled
#Block Office applications from injecting code into other processes
Add-MpPreference -AttackSurfaceReductionRules_Ids 75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84 -AttackSurfaceReductionRules_Actions Enabled
#Block JavaScript or VBScript from launching downloaded executable content
Add-MpPreference -AttackSurfaceReductionRules_Ids D3E037E1-3EB8-44C8-A917-57927947596D -AttackSurfaceReductionRules_Actions Enabled
#Block execution of potentially obfuscated scripts
Add-MpPreference -AttackSurfaceReductionRules_Ids 5BEB7EFE-FD9A-4556-801D-275E5FFC04CC -AttackSurfaceReductionRules_Actions Enabled
#Block Win32 API calls from Office macros
Add-MpPreference -AttackSurfaceReductionRules_Ids 92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B -AttackSurfaceReductionRules_Actions Enabled
#Block executable files from running unless they meet a prevalence, age, or trusted list criterion
Add-MpPreference -AttackSurfaceReductionRules_Ids 01443614-cd74-433a-b99e-2ecdc07bfc25 -AttackSurfaceReductionRules_Actions Enabled
#Use advanced protection against ransomware
Add-MpPreference -AttackSurfaceReductionRules_Ids c1db55ab-c21a-4637-bb3f-a12568109d35 -AttackSurfaceReductionRules_Actions Enabled
#Block credential stealing from the Windows local security authority subsystem
Add-MpPreference -AttackSurfaceReductionRules_Ids 9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2 -AttackSurfaceReductionRules_Actions Enabled
#Block process creations originating from PSExec and WMI commands
Add-MpPreference -AttackSurfaceReductionRules_Ids d1e49aac-8f56-4280-b9ba-993a6d77406c -AttackSurfaceReductionRules_Actions Enabled
#Block untrusted and unsigned processes that run from USB
Add-MpPreference -AttackSurfaceReductionRules_Ids b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4 -AttackSurfaceReductionRules_Actions Enabled
#Block Office communication application from creating child processes
Add-MpPreference -AttackSurfaceReductionRules_Ids 26190899-1602-49e8-8b27-eb1d0a1ce869 -AttackSurfaceReductionRules_Actions Enabled
#Block Adobe Reader from creating child processes
Add-MpPreference -AttackSurfaceReductionRules_Ids 7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c -AttackSurfaceReductionRules_Actions Enabled
#Block persistence through WMI event subscription
Add-MpPreference -AttackSurfaceReductionRules_Ids e6db77e5-3df2-4cf1-b95a-636979351e5b -AttackSurfaceReductionRules_Actions Enabled

#Disable TCP Timestamps
netsh int tcp set global timestamps=disabled

#GPO Configurations
$gposdir = "$(Get-Location)\Files\GPOs"
Foreach ($gpocategory in Get-ChildItem "$(Get-Location)\Files\GPOs") {
    
    Write-Output "Importing $gpocategory GPOs"

    Foreach ($gpo in (Get-ChildItem "$(Get-Location)\Files\GPOs\$gpocategory")) {
        $gpopath = "$gposdir\$gpocategory\$gpo"
        Write-Output "Importing $gpo"
        .\Files\LGPO\LGPO.exe /g $gpopath
    }
}

#Set PowerShell Constrained Language Mode
#https://devblogs.microsoft.com/powershell/powershell-constrained-language-mode/
$ExecutionContext.SessionState.LanguageMode = "ConstrainedLanguage"
Set-Variable -Name "__PSLockdownPolicy" -Value "4"

#Reboot prompt
Add-Type -AssemblyName PresentationFramework
$Answer = [System.Windows.MessageBox]::Show("Reboot to make changes effective?", "Restart Computer", "YesNo", "Question")
Switch ($Answer)
{
    "Yes"   { Write-Warning "Restarting Computer in 15 Seconds"; Start-sleep -seconds 15; Restart-Computer -Force }
    "No"    { Write-Warning "A reboot is required for all changed to take effect" }
    Default { Write-Warning "A reboot is required for all changed to take effect" }
}
