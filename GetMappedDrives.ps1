# Created by Mark Banks on 2/22/2019
# Description:
##  This script is meant to be a logoff script for windows.  It will collect the HCKU\Network registries.
##  These registries store the mapped network drives for a user.
##  It also uses these registries to create a .csv containing a list of the user's drive letters and drive locations.
##  The reg files can be used as a backup for your user's mapped drives, making it easy to restore their drives if they get a new computer.
#
# Setup:
## 1) Network Folder for Reg & csv storage:
##    i) Create a hidden folder on your network fileshare server.  Maybe give it an obscure name too so people won't stumble into it by accident.
##      -All users that you will be running this script for need to have read/write/modify rights.  Otherwise reg files & csv files won't be created or updated.
##    ii) Create 2 subfolders: one named "CSVFiles" and the other called "REGFiles"
##    iii) Change the "$FolderPath" variable below to the folder location you created in step 1-i.  for instance $Folderpath= "\\fileshare\obscuredfolder$\"
## 2) If you want to run this script as a logoff script, you have to get around ExecutionPolicy 
##    a) Recommended: Self sign the script using a code-signing certificate.
##      -This is not difficult to do. Follow the steps in the two links below (its a 2 part article): 
##      https://devblogs.microsoft.com/scripting/hey-scripting-guy-how-can-i-sign-windows-powershell-scripts-with-an-enterprise-windows-pki-part-1-of-2/
##      https://devblogs.microsoft.com/scripting/hey-scripting-guy-how-can-i-sign-windows-powershell-scripts-with-an-enterprise-windows-pki-part-2-of-2/
##    b) I DO NOT recommend this: If you are feeling lazy or you don't see the issue with it you can:
##      -Set execution policy to UnRestricted via group policy.  Again, do this at your own risk... execution policy defaults to AllSigned for a reason.


$user = $env:UserName
$drives = Get-ChildItem 'HKCU:\Network'

## fill in the below variable with the main network folder.
$FolderPath = #### define your path here in quotes

$CsvPath = $FolderPath + "CsvFiles\"+$user + ".csv"
$RegPath = $FolderPath + "RegFiles\" + $user + ".reg"
$finalDrives=@()
$date = Get-Date
#logs go to C:\users\username\usernameGMD.log (where username is the user's username)
$SCRIPT:Logfile = "C:\Users\"+$user+"\"+$user+"GMD.log"
#the following line overwrites the previous log file.
"Log for Get-MappedDrives logon script, ran on: "+$date |out-file $logfile

Function Write-Log{
  #Function from post by user @JNK.  Posted as an answer on StackOverflow: https://stackoverflow.com/questions/7834656/create-log-file-in-powershell
   Param ([string]$logstring)
   Add-content $Logfile -value $logstring
}
Write-Log "Initiating  HKCU:\NETWORK  Registry Export."

if (test-path $FolderPath){
  if ($drives){
    #export the mapped drives from the registries in HKCU\Network.
    $error.clear()
    try{
      reg export HKCU\Network $RegPath /y
      $RegSuccess = "Success"
    }catch{
      Write-Log "There was an issue exporting the registry keys."
      Write-Log "Aborting script.  See Error below for more information."
      Write-Log "Error message:"
      Write-Log "---------------"
      Write-Log "$error"
      $RegSuccess = "Fail"
    }
    if($RegSuccess -like "Success")
    {
      Write-log "Completed Registry Export Successfully."
    }
    #now parse the keys and create a CSV for human readable in case we need to manually set up mapped drives.
    foreach($drive in $drives){
      $driveProps = @{
        DriveName = $drive.PSChildName
        DrivePath = get-itemproperty -path $drive.pspath -name RemotePath | select -expand RemotePath
      }
      $DriveObj = New-Object psobject -property $driveProps
      $FinalDrives += $DriveObj | select DriveName,DrivePath
    }
    if ($finalDrives.count -gt 0){
      $finalDrives | export-csv $CsvPath -noTypeInformation
      Write-Log "Completed Registry Parsing and CSV Upload."
    }
  }
  else{
    Write-Log "There are currently no Mapped Drives listed in the registries HKCU:\Network on this computer."
    Write-Log "Or the script was unable to access the mapped drives."
    Write-Log "Aborting script."
  }
}
else{
  Write-Log "Unable to access. Aborting script."
  Write-Log "Please make sure you are either connected directly to the network via ethernet or wifi, or that you are connected via VPN."
}
