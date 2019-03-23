<#
VERSION      DATE          AUTHOR
0.1A      22/03/2019       op7ic
#> # Revision History


<#
  .SYNOPSIS
    Deploys SYSMON across the domain. WARNING: This script needs to run with Domain Admin privilages
  .EXAMPLE
    SYSMONFENCER.ps1
  .HELP 
    Add -remove parameter to remove installed SYSMON globally
#>

# Run commands against remote system using WMI or Invoke-Command method. Ugly block of code
function runcmdRemove ($SYSTEM){
# Simple test to see if invoke-command works
$invokePSCMD = Invoke-Command -ComputerName $SYSTEM -ScriptBlock {1+1}

if ($invokePSCMD -ne "2"){
  Write-Output "[+] Invoke-Command is not allowed against $SYSTEM, attempting WMI trigger"
  $wmicCMD = wmic /node:$SYSTEM process call create "C:\SYSMONx730185\manualSysmonRemoval.bat"
  if ($wmicCMD -like "*successful*"){
    write-output "[+] WMIC execution was successful against $SYSTEM"
  }else{
    # WMI failed, we can try SCHTASKS instead
    Write-Output "[+] WMI is not allowed against $SYSTEM, attempting SCHTASKS trigger"
	$today=Get-Date -Format dd/MM/yyyy
	$timetrigger = (get-date).AddMinutes(3).ToString("HH:mm")
	schtasks /create /s $SYSTEM /sc once /tn "MONINSTx45" /sd $today /st $timetrigger /tr C:\SYSMONx730185\manualSysmonRemoval.bat /ru "SYSTEM"
  }
}else{ #Invoke-Command can be used
  Invoke-Command -ComputerName $SYSTEM -ScriptBlock {C:\SYSMONx730185\manualSysmonRemoval.bat}
  }
}# EOF

# Run commands against remote system using WMI or Invoke-Command method. Ugly block of code
function runcmdInstall ($SYSTEM){
# Simple test to see if invoke-command works
$invokePSCMD = Invoke-Command -ComputerName $SYSTEM -ScriptBlock {1+1}

if ($invokePSCMD -ne "2"){
  Write-Output "[+] Invoke-Command is not allowed against $SYSTEM, attempting WMI trigger"
  $wmicCMD = wmic /node:$SYSTEM process call create "C:\SYSMONx730185\manualSysmon.bat"
  if ($wmicCMD -like "*successful*"){
    write-output "[+] WMIC execution was successful against $SYSTEM"
  }else{
    # WMI failed, we can try SCHTASKS instead
    Write-Output "[+] WMI is not allowed against $SYSTEM, attempting SCHTASKS trigger"
	$today=Get-Date -Format dd/MM/yyyy
	$timetrigger = (get-date).AddMinutes(3).ToString("HH:mm")
	schtasks /create /s $SYSTEM /sc once /tn "MONINSTx45" /sd $today /st $timetrigger /tr C:\SYSMONx730185\manualSysmon.bat /ru "SYSTEM"
  }
}else{ #Invoke-Command can be used
  Invoke-Command -ComputerName $SYSTEM -ScriptBlock {C:\SYSMONx730185\manualSysmon.bat}
  }
}# EOF


function deploySYSMONGLOBAL($remove){


write-host "-=[ SYSMONFENCER v0.1 ]=-"
write-host "      by op7ic        "

$strFilter = "computer";
$objDomain = New-Object System.DirectoryServices.DirectoryEntry
$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
$objSearcher.SearchRoot = $objDomain
$objSearcher.SearchScope = "Subtree"
$objSearcher.PageSize = 999999
$objSearcher.Filter = "(objectCategory=$strFilter)";
$colResults = $objSearcher.FindAll()
$deployerRandomName = "SYSMONx730185"# this gets hardcoded into many parts of this script

foreach ($i in $colResults)
{
        $objComputer = $i.GetDirectoryEntry()
        $remoteBOX = $objComputer.Name
         
        #Step 1 - Create remote folder in C$ which we can use for deployment: 
        $folerLocation = "\\$remoteBOX\`C$\$deployerRandomName"
        Write-Output "[+] Creating Folder For Deployment : $folerLocation"
        mkdir $folerLocation
		#Step 2 - Deploy binaries to specified (hardcoded folder) on each host: 
        Write-Output "[+] Deploing sysmon config and binaries to : $remoteBOX"
		if ($remove){
		try{
		xcopy /y .\tools\Sysmon.exe $folerLocation
        xcopy /y .\tools\Sysmon64.exe $folerLocation
		xcopy /y .\tools\manualSysmonRemoval.bat $folerLocation
		}catch{
		Write-Output "[-] Unable to remove binaries to : $remoteBOX, perform removal manually" 
		}
		
		}else{
		try{
		  xcopy /y .\tools\Sysmon.exe $folerLocation
          xcopy /y .\tools\Sysmon64.exe $folerLocation
          xcopy /y .\tools\sysmonconfig-export.xml $folerLocation
          xcopy /y .\tools\manualSysmon.bat $folerLocation
		  runcmdInstall($remoteBOX)
		}catch{
		Write-Output "[-] Unable to deploy binaries to : $remoteBOX" 
		}
		}
		#Final step - remove folder from each host (SYSMON runs in background). Will reupload data to remove sysmon
		sleep 60
        del $folerLocation

}

}

param (
    [switch]$remove
);


if ($remove){
 deploySYSMONGLOBAL($remove)
}else{
 deploySYSMONGLOBAL
}