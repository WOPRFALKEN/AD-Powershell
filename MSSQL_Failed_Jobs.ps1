#################################################################################### 
# Custom monitor POWERSHELL scripts will be provided with below input parameters from agent while invoking the script: 
# ./MSSQL_Failed_Jobs.ps1 "/metricName::MSSQL_Failed_Jobs /metric::MSSQL_Failed_Jobs /warn::0 /critical::1 /alert::1 /params::MSSQLServerName:mssqlservername,MSSQLUserName:mssqlusername,MSSQLPassword:mssqlpassword"
############################################################################ 
# Use the below block of code in all the POWERSHELL custom monitor scripts to parse the parameters: 
#########################################CachePercentageMonitor#########################
$ErrorActionPreference = "SilentlyContinue"

$filepath = split-path -parent $MyInvocation.MyCommand.Definition
$fileAccessPath = split-path -parent $filepath
$AbsoluteFilePath = $MyInvocation.MyCommand.Path
########################################################################################
Function SaveNewState
{
	param([string]$MetricNameState,[string]$InstanceState,[string]$Value)
	     
	$prevstatefolder = $fileAccessPath+"\log\prevstate"
	If (Test-Path $prevstatefolder)
	{
	}
	Else
	{ 
		New-Item -ItemType directory -Path $prevstatefolder
	}
		
	$ExePath = $fileAccessPath + "\log\prevstate\" + $MetricNameState + ".txt"
	        
        If (Test-Path $ExePath)
		{
			$monexists = 0
			$newdatafile = $null
			$fileReader = Get-Content $ExePath
			foreach($data in $fileReader)
			{
				if($data.StartsWith($MetricNameState +":"+ $InstanceState))
				{
					$monexists = 1
					$newdatafile = $newdatafile + $MetricNameState +":"+ $InstanceState + "--" + $Value  + "`r`n"
				}
				Else
				{
					$newdatafile = $newdatafile + $data + "`r`n"
				}
			}
			If($monexists -eq 0)
			{
				$newdatafile = $newdatafile + $MetricNameState +":"+ $InstanceState + "--" + $Value + "`r`n"
			}
			$newdatafile | Out-File $ExePath
		
		}
		Else
		{
			#Out-File $ExePath
			$MetricNameState +":"+ $InstanceState + "--" + $Value   | Out-File $ExePath
		}
}
###########################################################################################
Function CheckOldState
{
		
	param([string]$MetricNameState,[string]$InstanceState)
         
	$ExePath = $fileAccessPath + "\log\prevstate\" + $MetricNameState + ".txt"
	
	If (Test-Path $ExePath)
	{
		$oldstate = "Ok"
		$fileReader = Get-Content $ExePath             
		foreach($data in $fileReader)
		{
			if($data.StartsWith($MetricNameState +":"+ $InstanceState))
			{
				$oldstate = $data.Substring($data.IndexOf("--") + 2);
			}
		}
		$CheckOldState = $oldstate
	}
	else
	{
	 $CheckOldState = "Ok"	
	}
    
	return  $CheckOldState

}
############################################################################################
Function SendAlertToAB
{
		param([string]$MetricName,[string]$MetricInstance,[string]$OldState,[string]$NewState,[string]$Description) 
		#$Subject = "SQL_Failed_Jobs"
		$ServiceName = "MSSQL_Failed_Jobs"
		#$Description = "Used CacheMemory of Device is "+$Value+ " Percent"
		$currTime = [System.DateTime]::Now
		$timeStamp = [string]$currTime.Year + "-" + [String]$currTime.Month + "-" + [String]$currTime.Day + " " + [string]$currTime.Hour + ":" + [string]$currTime.Minute + ":" + [string]$currTime.Second
			
		$SocketXML = ""
		$SocketXML = $SocketXML + "<cm><id>AlertOutput</id><AlertOutput>"
		$SocketXML = $SocketXML + "<ServiceName>"+$ServiceName+"</ServiceName>"
		$SocketXML = $SocketXML + "<NewState>"+ $NewState+"</NewState>"
		$SocketXML = $SocketXML + "<OldState>"+ $OldState+"</OldState>"
		$SocketXML = $SocketXML + "<Description>"+ $Description +"</Description>"
		$SocketXML = $SocketXML + "<AlertTimeStamp>" + $timeStamp + "</AlertTimeStamp>"
		$SocketXML = $SocketXML + "<AlertType>Monitoring</AlertType>"
		#$SocketXML = $SocketXML + "<UuId>UuId</UuId>"
		$SocketXML = $SocketXML + "<UuId>"+ $MetricName+ "_" + $MetricInstance+"</UuId>"		
		$SocketXML = $SocketXML + "<Subject>" + $Description + "</Subject>"
		$SocketXML = $SocketXML + "</AlertOutput></cm>"
		
		if($fileAccessPath.contains("x86"))
        {
			& "$fileAccessPath\bin\AgentSockIPC.exe" $SocketXml
		}
		else
		{
			& "$fileAccessPath\bin\AgentSockIPC.exe" $SocketXml
		}
			
 }
########################################################################################
Function AlertLogic
{
  param([int]$index,[string]$MetricInstanceName,[int]$MetricValue,[string]$Description)
  
 			If ( [string]$Alert_Flag[$index] -eq 1 )
			{
				If ($MetricValue -eq 0)
				{
					$NewState = "Critical"
				}
				ElseIf ($MetricValue -eq 1)
				{
					$NewState = "Ok"
				}
					$MetricNametemp=[string]$MetricName[$index]
					$OldState = CheckOldState "$MetricNametemp" "$MetricInstanceName"
				
					If ($OldState -ne $NewState)
					{
						#Send Alert
						$Metrictemp = $Metric[$index] 
						SendAlertToAB "$Metrictemp" "$MetricInstanceName" "$OldState" "$NewState" "$Description"
						$check = $?
						if ( $check )
						{
							#Save New State
							$metrictemp = $MetricName[$index]
							SaveNewState "$metrictemp" "$MetricInstanceName" "$NewState"
						}							
					}				
			}
} 
########################################################################################
Function Utilization
{
	param([int]$index)
	
	[string]$InputString = $Params[$index]
	$input = $InputString -split ','
	$arr = $input -split ':'
	$SQLServer = $arr[1]
	$uid = $arr[3]
	$pwd = $arr[5].Trim("[0]'")
	

 	 $metrictemp = $MetricName[$index]
	
	 $perfdataOutput = "<Monitor name="+ $metrictemp + " output="
					
		$readconn = New-Object System.Data.OleDb.OleDbConnection
		[string]$connstr="Provider=SQLOLEDB.1;Integrated Security=SSPI;Initial Catalog=msdb;Persist Security Info=False;DataSource=$SQLServer;UserName=$uid;Password=$pwd"

			$readconn.connectionstring = $connstr
			$readconn.open()
			
			$readcmd = New-Object system.Data.OleDb.OleDbCommand
			$readcmd.connection=$readconn

			$readcmd.commandtext = "select distinct j.Name as 'Job Name', case j.enabled when 1 then 'Enable' when 0 then 'Disable' end as 'Job Status', jh.run_date as [Last_Run_Date(YY-MM-DD)] , case jh.run_status when 0 then 'Failed' when 1 then 'Successful' when 2 then 'Retry' when 3 then 'Cancelled' when 4 then 'In Progress' end as Job_Execution_Status from sysJobHistory jh, sysJobs j where j.job_id = jh.job_id and jh.run_date = (select max(hi.run_date) from sysJobHistory hi where jh.job_id = hi.job_id)"
			$reader = $readcmd.executereader()
			do
			{
			 while ($reader.read()) # -eq "True") 
			 {
			 #[Int]$Count = $reader.Item("RecordCount")
			 [string]$name = $reader.GetValue(0)
			 [string]$state_desc = $reader.GetValue(3)  #.ToString()
			 
			 If($state_desc -eq "Successful")
			 {
				#$status = "ONLINE"
				$status = "Successful"
				$Value = 1
			 }
			 ElseIf($state_desc -eq "Failed")
			 {
				#$status = "OFFLINE"
				$status = "Failed"
				$Value = 0
			 }
		  		
			   $MetricValue = [string]$Value
			   [string]$Description = "MSSQL_Failed_Jobs: " + $name + " job status is " + $status
			   $MetricInstanceName = ([string]$name).Trim()  #name of instance
			   AlertLogic "$index" "$MetricInstanceName" "$MetricValue" "$Description"
			   $perfdataOutput = $perfdataOutput + "'" + $MetricInstanceName + "'" + "=" + $MetricValue + "," 
	        
			}  #while loop closing
		   }	#do loop closing
		While ($reader.NextResult())
				
		$reader.close()
		$size = $perfdataOutput.length      #to remove last ","
		$perfdataOutput = $perfdataOutput.substring(0,$size-1)
		$perfdataOutput = $perfdataOutput + "></Monitor>"
		write-host $perfdataOutput
		#write-host "<Monitor name=" + [string]$MetricName[$index] + " output= " + $Metric[$index] + "=" + $MetricValue + "></Monitor>"
		
}
##########################################################################
Function abc
{
		write-host "<DataValues>"
	   
		for($i=0 ;$i -lt $MetricName.length ; $i++)
		{
			
		Utilization "$i"
		}
		write-host "</DataValues>"
}
	
#####################################################################
Function GetArgs()
{
	 if($args.count -gt 0)
	{
	   for($i=0 ;$i -le $args.count-1 ;$i++)
		{
			$strArgs = $strArgs + [string]($args[$i])
		       
		}
	}
	#write-host $strArgs	
	if($strArgs.Contains("/metricName::") -ne 0)
	{
		$MetricNameTokens1 = $strArgs -split "/metricName::", 2
                $MetricNameTokens= $MetricNameTokens1[1].Trim() 

		if($MetricNameTokens.Contains("/") -ne 0)
		 {
			$MetricNameTokens1 = $MetricNameTokens -split "/", 2
            $MetricNameTokens = $MetricNameTokens1[0].Trim()
            #write-host "metricName " + $MetricNameTokens	      
		 }
	}
	
	if($strArgs.Contains("/metric::") -ne 0)
	{
    	$MetricTokens1 = $strArgs -split "/metric::", 2     
	    $MetricTokens = $MetricTokens1[1].Trim()
            
	    if($MetricTokens.Contains("/") -ne 0)
	    {	    
		     $MetricTokens1 = $MetricTokens -split "/", 2
		     $MetricTokens = $MetricTokens1[0].Trim()
		     #write-host "Metric is " + $MetricTokens
	    }
         }

         if($strArgs.Contains("/warn::") -ne 0)
	 {
		   $Warning_ThresTokens1 = $strArgs -split "warn::", 2
		   
		   $Warning_ThresTokens = $Warning_ThresTokens1[1].Trim()
         
		   if($Warning_ThresTokens.Contains("/") -ne 0)
		   {
			   $Warning_ThresTokens1 = $Warning_ThresTokens  -split "/", 2
			  
			   $Warning_ThresTokens =  $Warning_ThresTokens1[0].Trim()
			     #write-host "warn is " + $Warning_ThresTokens

		   }

          }

          if($strArgs.Contains("/critical::") -ne 0)
	  {
		  $Critical_ThresTokens1 = $strArgs -split "/critical::", 2
		  
		  $Critical_ThresTokens = $Critical_ThresTokens1[1].Trim()
		  
		  if($Critical_ThresTokens.Contains("/") -ne 0)
		  {
	  
			$Critical_ThresTokens1 = $Critical_ThresTokens -split "/", 2

			$Critical_ThresTokens = $Critical_ThresTokens1[0].Trim()
           
			#write-host "critical is " + $Critical_ThresTokens
		  }
	  }
	
          if($strArgs.Contains("/alert::") -ne 0)
	  {

		   $Alert_FlagTokens1 =  $strArgs -split "/alert::", 2
		  
		   $Alert_FlagTokens = $Alert_FlagTokens1[1].Trim()
		   
		   if($Alert_FlagTokens.Contains("/") -ne 0)
		   {
			    $Alert_FlagTokens1= $Alert_FlagTokens -split "/", 2
			    
			    $Alert_FlagTokens=  $Alert_FlagTokens1[0].Trim()
		            #write-host "Alert_FlagTokens " + $Alert_FlagTokens
		   }
	    
	    }

        if($strArgs.Contains("/params::") -ne 0)
	    {	    
		 $ParamsTokens1 = $strArgs -split "/params::", 2
		 $ParamsTokens = $ParamsTokens1[1].Trim()
		      
		 if($ParamsTokens.Contains("/") -ne 0)
		 {
			$ParamsTokens1 = $ParamsTokens -split "/", 2
			$ParamsTokens = $ParamsTokens1[0].Trim()
			#write-host "params are " + $ParamsTokens
		 
		 }	      
	    }
	$MetricName = @()
	$Metric = @()
	$Warning_Thres = @()
    $Critical_Thres = @()
    $Alert_Flag = @()
    $Params = @() 

	$MetricName= $MetricNameTokens.split("|")
	
	$Metric=$MetricTokens.split("|")

    $Warning_Thres=$Warning_ThresTokens.split("|")
	$Critical_Thres=$Critical_ThresTokens.split("|")
	
	$Alert_Flag=$Alert_FlagTokens.split("|")
        
	$Params= $ParamsTokens.split("|")
	
	abc
 }       
#############################################################################
$psfiledir = split-path -parent $MyInvocation.MyCommand.Definition
# write-host "psfiledir:"$psfiledir
if($env:Processor_Architecture -eq 'x86')
{
	$varbyte=c:\windows\sysnative\windowspowershell\v1.0\powershell.exe {[intptr]::size}
	if ($varbyte -eq 8)
	{
	#write-host "64-bit machine"
	#c:\windows\sysnative\windowspowershell\v1.0\powershell.exe {set-executionpolicy "remotesigned"} # From agent release 5.97.0000 execution policy is defined in agent backend code. so we removing that.
	c:\windows\sysnative\windowspowershell\v1.0\powershell.exe -command "&'$AbsoluteFilePath'" "'$args'"	
	}
	else
	{
		#write-host "32-bit machine"
		#Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
		GetArgs "'$args'"
	}
}
else
{
	#Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
	GetArgs "'$args'"
}

