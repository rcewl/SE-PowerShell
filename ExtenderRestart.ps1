   <#
Server script

just run and it will do
- backup map files to rar every hour
- at 6am wil restart server (shutdown,Updateserver,backup,clean,restart)
- check every 5 minutes if server is running, ifnot (Updateserver,backup,clean,restart)

updating and restart 6am not tested yet looking will need to check logs this weekend


#########stuff i want to keep EekAMouse #######
       Backup both run great!!
       "C:\Program Files\WinRAR\rar.exe"
       "C:\Program Files\7-Zip\7Z.exe"
#> 


param (
    ### World save location
    [string]$mapPath = "$env:APPDATA\SpaceEngineersDedicated",
    [string]$MapInstance = "\Saves\'Gypsy Space Migration'",
    ### SteamCMD
    [string]$steamCMD = "C:\SESM-Game-Files\SteamCMD",
    ### Server File location
    [string]$SEInstallPath2 = "C:\SESM-Game-Files",
    [string]$NoExtenderArguments = @("-console"),
    [string]$ExtenderArguments2 = @("nowcf" , "autostart"), #, "nowcf""autosave=10" ,
    ### Backup and script log path
    [string]$backupsPath = "$env:APPDATA\SpaceEngineersDedicated\saves\",
    [string]$logfilepath = "$backupsPath",
    ### script settings
    [switch]$cantStopTheMagic = $false,  # enables the automatic checking if the server is running
    [switch]$ServerExtender = $true ,   #$false will run server without Extenders
    [switch]$ServerExtenderUpdate = $true ,#$true to enable autoupdate, still mem leaks in Invoke-webrequest (only on win7 machine)
    [switch]$CleanMapbyScript2 = $false ,#$run the cleanup by script before server start
    [int]   $serverPort = 27016,        #Set to 0 to skip connection test, or to the port your server is running on
    [int64] $memTest = 3221225472,      #Set to 0 to skip memtest, or to the value the server proccess can not exceed
    [int]   $launchDelay = 240,         #Script delay after launch to allow server to come online properly
    ### winrar (or 7-zip) location, both work
    [string]$Winrar2 =  "C:\Program Files\7-Zip\7z.exe"  
)
#filepath checks needed
#filepath checks needed


if ($true){
$DebugPreference = "Continue"
}else{
$DebugPreference = "SilentlyContinue"
}

function timeStamp {
    return ((Get-Date).ToString("yyyy-MM-dd hh:mm:ss"))
}

Function ServerActive {
    $ServerActive = Get-Process $ApplicationCheck -ErrorAction SilentlyContinue
    if ($ServerActive -ne $null ) {
        return $true
    }else{
        if ($ServerExtender) {CheckCmd} #check if serverextender is restarted in cmd.exe, if so kill it
        return $false
    }
    
}

Function CheckCmd(){
    $cmd = Get-Process cmd -erroraction SilentlyContinue 
    if (($cmd -ne $null))
    {
        taskkill $cmd
    }   
}
 



function startSE {
    if (!(ServerActive)) {
        if (Test-Path "$ServerPath\$Application")
        {
            if ($CleanMapbyScript){CleanSaveFile}
	        Write-Output "$(timeStamp) Starting Server.."
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = "$ServerPath\$Application"
            $pinfo.Arguments = $startArgs
            $pinfo.WorkingDirectory = $ServerPath
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $pinfo
            $p.Start() #| Out-Null
            #$p.ProcessorAffinity=0x2
            $ProcessID = $p.Id
	        Write-Output "$(timeStamp) Server process launched, PID: $ProcessID.. Starting Launch Delay."
            Start-Sleep -Seconds $launchDelay
	        Write-Output "$(timeStamp) Launch Delay completed."
        }else{
            Write-Output "$(timeStamp) Executable not found, check paths.."
            exit
        }
    } else {
	    Write-Output "$(timeStamp) Server is already started.."
    }        
}

function stopSE {
   if (ServerActive) {
	    Write-Output "$(timeStamp) Stopping Server.."
        while (ServerActive) {
	        Taskkill /IM $Application
            Start-Sleep -Seconds 2
        }
	    Write-Output "$(timeStamp) Server stopped.."
    } else {
	    Write-Output "$(timeStamp) Server is already stopped.."
    }         
}


function updateSE {
    $computer = gc env:computername
    if ($computer -eq "SFP-SPEN"){ #a check if the script is running on server, if not it does not update and persumes it s ran locally
	    Write-Output "$(timeStamp) Updating Server.."
        $updateArgs = @("+login anonymous", "+force_install_dir $SEInstallPath", "+app_update 298740", "+quit")
        Start-Process -FilePath "$steamCMD\steamcmd.exe" -WorkingDirectory $steamCMD -ArgumentList $updateArgs -Wait
    }else{
        Write-Output "$(timeStamp) Updating Server not needed locally.."
    }
    if ($ServerExtenderUpdate)
    {
        UpdateExtender 
    }
}

function backupSE {
    [string]$MaptoZip = "'C:\Users\psycore\AppData\Roaming\SpaceEngineersDedicated\saves\Gypsy Space Migration'"
    if ($($args[0]) -eq "daily") {
        [string]$Destination = $backupsPath+"GSM_Daily_$(Get-Date -f yyyy-MM-dd@HHmmss).rar"
        Write-Output "$(timeStamp) Server performing daily backup.."
        Start-Process -FilePath $Winrar -ArgumentList @("a", "$Destination" , "$MaptoZip") -RedirectStandardOutput "$backupsPath\LatestRar.log" -NoNewWindow -Wait
    } else {
        [string]$Destination = $backupsPath+"GSM_$(Get-Date -f yyyy-MM-dd@HHmmss).rar"
        Write-Output "$(timeStamp) Server performing snapshot backup.."
        Start-Process -FilePath $Winrar -ArgumentList @("a", "$Destination" , "$MaptoZip") -RedirectStandardOutput "$backupsPath\LatestRar.log" -NoNewWindow -Wait
    }
}

function CleanSaveFile {
    $ServerCleaning = $true
    While ($ServerCleaning) {
        if (ServerActive){ #server needs to be down to correctly clean save file.
            stopSE
            Start-Sleep -Seconds 10
        }else{
            Write-Output "$(timeStamp) Server cleaning savefile.."
            $logfilename = "GSM_Clean_$(Get-Date -f yyyy-MM-dd@HHmmss).log"
            $logfile = $(Join-Path $logfilepath $logfilename)
#path and file check needed here
            & ((Split-Path $MyInvocation.PSCommandPath) + "\shutdown.ps1") | Out-file -encoding utf8 $logfile
            Write-Output "$(timeStamp) Server cleaned .."
            $ServerCleaning = $false
        } 
    }
}

Function UpdateExtender () {
    $UpdateExtender = $true
    While ($UpdateExtender) {
       # if (ServerActive){ #server needs to be down to correctly clean save file.
       #     stopSE
       #     Start-Sleep -Seconds 10
       # }else{
            Write-Output "$(timeStamp) Calling ExtenderUpdateScript.."
            $logfilename = "GSM_UpdateExtender_$(Get-Date -f yyyy-MM-dd@HHmmss).log"
            $logfile = $(Join-Path $logfilepath $logfilename)
#path and file check needed here
            & ((Split-Path $MyInvocation.PSCommandPath) + "\_UpdateExtenderFiles.ps1") | Out-file -encoding utf8 $logfile
            Write-Output "$(timeStamp) Extender updatescript done .."
            $UpdateExtender = $false
       # } 
    }
}

#########################################################End of Functions################################
#this all runs ones on startup script
Clear-Host
if ($(gc env:computername) -eq "SFP-SPEN")
{ 
    #a check if the script is running on server, if not it persumes it s ran locally
    [string]$SEInstallPath =  $SEInstallPath2
    [string]$winrar = $winrar2
    [switch]$CleanMapbyScript = $CleanMapbyScript2
    [string]$ExtenderArguments = $ExtenderArguments2
#    [string]$ExtenderArguments +=  @('instance="C:\Users\psycore\AppData\Roaming\SpaceEngineersDedicated\Saves\Gypsy Space Migration"' )
    [string]$ExtenderArguments +=  @('path="C:\Users\psycore\AppData\Roaming\SpaceEngineersDedicated"')



}else{
    Write-Output "$(timeStamp) Running at EekAMouse.."
    [string]$SEInstallPath =  "D:\steam\SteamApps\common\SpaceEngineers"
    [string]$winrar = "C:\Program Files\7-Zip\7z.exe"
    [switch]$CleanMapbyScript = $false
    [string]$ExtenderArguments = $ExtenderArguments2
   # [string]$ExtenderArguments +=  @(' path="C:\Users\psycore\AppData\Roaming\SpaceEngineersDedicated"')
    # instance="C:\Users\psycore\AppData\Roaming\SpaceEngineersDedicated\Saves\Gypsy Space Migration"',

}

if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
    $ServerPath = "$SEInstallPath\DedicatedServer64"
} else {
    $ServerPath = "$SEInstallPath\DedicatedServer"
}

if ($ServerExtender){
    [string]$startArgs = $ExtenderArguments
    [string]$Application = "SEServerExtender.exe"
    [string]$ApplicationCheck = "SEServerExtender"
}else{
    [string]$startArgs = $NoExtenderArguments
    [string]$Application = "spaceengineersdedicated.exe"
    [string]$ApplicationCheck = "spaceengineersdedicated"
} 

$count = 0
$test=$true
#backupSE daily
updateSE
CleanSaveFile