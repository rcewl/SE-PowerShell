<#
Server script

just run and it will do
- backup map files to rar every hour
- at 6am wil restart server (shutdown,Updateserver,backup,clean,restart)
- check every 5 minutes if server is running, ifnot (Updateserver,backup,clean,restart)

updating and restart 6am not tested yet looking will need to check logs this weekend

#>


param (
    [string]$mapPath = "$env:APPDATA\SpaceEngineersDedicated",
    [string]$steamCMD = "C:\SESM-Game-Files\SteamCMD", # you can download steamCMD from steam https://developer.valvesoftware.com/wiki/SteamCMD
	[string]$SEInstallPath = "C:\SESM-Game-Files", 
    [string]$startArgs = @("-console"),
   # old setting that where used for Extender [string]$startArgs = @("autosave=10", "autostart", "nowcf"), 
    [switch]$cantStopTheMagic = $false, #set to $true if you want to let it run
    
	[string]$backupsPath = "$env:APPDATA\SpaceEngineersDedicated\saves\",
    
	[int]$serverPort = 27016, #Set to 0 to skip connection test, or to the port your server is running on
    [int64]$memTest = 3221225472, #Set to 0 to skip memtest, or to the value the server proccess can not exceed
    [int]$launchDelay = 240, # Script delay after launch to allow server to come online properly
    [string]$Winrar =  "C:\Program Files\WinRAR\rar.exe", #you can use 7-zip if you like, parameters are ok. 7-zip is somewhat slower though.
    [string]$logfilepath = "$backupsPath", #make sure this path exists
    [string]$MapInstance ='\Saves\"Gypsy Space Migration"' ,#when using spaces in the packupfile path use extra quotes
	[boolean]$cleanfile = "$false" #when using the cleaning script, set it true
)

#filepath checks needed
#filepath checks needed

if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
    $ServerPath = "$SEInstallPath\DedicatedServer64"
} else {
    $ServerPath = "$SEInstallPath\DedicatedServer"
}

function timeStamp {
    return ((Get-Date).ToString("yyyy-MM-dd hh:mm:ss"))
}

function startSE {
    $ServerActive = Get-Process spaceengineersdedicated -ErrorAction SilentlyContinue
    if ($ServerActive -eq $null) {
        CleanSaveFile
	    Write-Output "$(timeStamp) Starting Server.."
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = "$ServerPath\spaceengineersdedicated.exe"
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
    } else {
	    Write-Output "$(timeStamp) Server is already started.."
    }        
}

function stopSE {
   $ServerActive = Get-Process spaceengineersdedicated -ErrorAction SilentlyContinue
    if ($ServerActive -ne $null) {
	    Write-Output "$(timeStamp) Stopping Server.."
        while ($ServerActive -ne $null) {
	        Taskkill /IM spaceengineersdedicated.exe
            Start-Sleep -Seconds 2
            $ServerActive = Get-Process spaceengineersdedicated -ErrorAction SilentlyContinue
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
}

function backupSE {
    $MaptoZip = "$mapPath" + "$MapInstance" 
    if ($($args[0]) -eq "daily") {
        Write-Output "$(timeStamp) Server performing daily backup.."
        Start-Process -FilePath $Winrar -ArgumentList @("a", "$backupsPath\GSM_Daily_$(Get-Date -f yyyy-MM-dd).rar", "$MaptoZip") -RedirectStandardOutput "$backupsPath\LatestDailyRar.log" -NoNewWindow -Wait
    } else {
        Write-Output "$(timeStamp) Server performing snapshot backup.."
        Start-Process -FilePath $Winrar -ArgumentList @("a", "$backupsPath\GSM_$(Get-Date -f yyyy-MM-dd@HHmmss).rar", "$MaptoZip") -RedirectStandardOutput "$backupsPath\LatestRar.log" -NoNewWindow -Wait
    }
}

function CleanSaveFile {
    if ($cleanfile){
		$ServerCleaning = $true
		While ($ServerCleaning) {
			$ServerActive = Get-Process spaceengineersdedicated -ErrorAction SilentlyContinue
			if ($ServerActive -ne $null){ #server needs to be down to correctly clean save file.
				stopSE
				Start-Sleep -Seconds 10
			}else{
				Write-Output "$(timeStamp) Server cleaning savefile.."
				$logfilename = "GSM_Clean_$(Get-Date -f yyyy-MM-dd@HHmmss).log"
				$logfile = "$logfilepath\$logfilename"
#path and file check needed here
				& ((Split-Path $MyInvocation.PSCommandPath) + "\cleanSavefile.ps1") | Out-file -encoding utf8 $logfile
				Write-Output "$(timeStamp) Server cleaned .."
				$ServerCleaning = $false
			} 
		}
	}else{
		Write-Output "$(timeStamp) Server cleaning not active in script.."
	}
}

$count = 0
Clear-Host
while ($cantStopTheMagic) {
    $ServerActive = Get-Process spaceengineersdedicated -ErrorAction SilentlyContinue
    if($ServerActive -eq $null) {
        Write-Output "$(timeStamp) Server not running.."
        updateSE
        startSE
    } else {
        Write-Output "$(timeStamp) Server running.."
	    Write-Output "$(timeStamp) Checking memory usage.."
        if ($memTest -gt 0) { #do server memory test
	        if ($ServerActive.WorkingSet64 -gt $memTest) { #Check for excessive memory usage
	            Write-Output "$(timeStamp) Server over 3GB of memory usage."
                stopSE
                updateSE
	            startSE
	        } else {
	            Write-Output "$(timeStamp) Server memory usage passed tests. Usage is $([int]$($ServerActive.WorkingSet64 /1024/1024))MB."
            }
        }
        if ($serverPort -gt 0) { #do connection test

            $udpobject = new-Object system.Net.Sockets.Udpclient #Create object for connecting to port
            $udpobject.client.ReceiveTimeout = 100 #Set a timeout on receiving message, as it's localhost this can be quite low.
            $udpobject.Connect("localhost",$serverPort) #Connect to servers machine's port
            $a = new-object system.text.asciiencoding
            $byte = $a.GetBytes("$(Get-Date)") 
            [void]$udpobject.Send($byte,$byte.length)  #Sends the date to the SE server. 
            #We're not expecting a response from sending the date to the SE Server, but we have to handle it if it happens
            $remoteendpoint = New-Object system.net.ipendpoint([system.net.ipaddress]::Any,0) 

            Try { 
                #Blocks until a message returns on this socket from a remote host or timeout occurs.
                $receivebytes = $udpobject.Receive([ref]$remoteendpoint) 
                [string]$returndata = $a.GetString($receivebytes)
                If ($returndata) {
                    Write-Output "$(timeStamp) Server is online, UDP port $serverPort responded" 
                    $udpobject.close()   
                }                       
            } Catch { 
                If ($Error[0].ToString() -match "\bRespond after a period of time\b") { 
                    $udpobject.Close()
                    #We won't get false positives as this is being run from the localhost, so if we haven't 'forcibly closed' by now the port is up. Read up on UDP if this doesn't make sense :)
                    Write-Output "$(timeStamp) Server is online, UDP port $serverPort not closed" 
                } ElseIf ($Error[0].ToString() -match "forcibly closed by the remote host" ) { 
                    $udpobject.Close()
                    #Well, the server shut the port on us, that mean's it's online but there is no Space Engineers listening :(
                    Write-Output "$(timeStamp) Server is offline! UDP port $serverPort closed."
                    stopSE #attempt to kill process as it's probably crashed
                    startSE #no update, this was a crash, lets get back up and running ASAP
                } Else {
                    #We should never get here...      
                    $udpobject.close() 
                } 
            }
            
        }
        if ((Get-date).Hour -eq 6 -and ((Get-Date).Minute -lt 10 -and (Get-Date).Minute -gt 0)) { # 6am Maintenance
            stopSE
            backupSE daily
            updateSE
            startSE
        }
    }
    $count++
    if ($count -eq 12) { # Snapshot every 60 mins
        backupSE
        $count = 0
    }
    Start-Sleep -Seconds 300 #Wait 5 minutes
}

Write-Output "Script ended"