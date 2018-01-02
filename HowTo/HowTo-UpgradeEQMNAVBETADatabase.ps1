Function HowTo-UpgradeEQMNAVBETADatabase
{
    [CmdletBinding()]
    param 
        ( 
            [parameter(Mandatory=$true)]
            [string]$FromSqlServer,
           
            [parameter(Mandatory=$true)]
            [string]$FromSqlServerInstance,

            [parameter(Mandatory=$true)]
            [string]$FromSqlDatabaseName,

            [parameter(Mandatory=$true)]
            [string]$DatabaseServer,

            [parameter(Mandatory=$false)]
            [string]$DatabaseInstance = "",
            
            [parameter(Mandatory=$true)]
            [string]$DatabaseName,  

            [parameter(Mandatory=$true)]
            [string]$NAVServerInstance,

            [parameter(Mandatory=$false)]
            [ValidateNotNullOrEmpty()]
            [string]$NAVServerServiceAccount = "NT AUTHORITY\NETWORK SERVICE",

            [parameter(Mandatory=$true)]
            [string]$WorkingDirectory,

            [parameter(Mandatory=$false)]
            [string]$LogDirectory = "",

            [parameter(Mandatory=$true)]
            [string]$RemovalPath
        )
    BEGIN
    {
        Write-Verbose "========================================================================================="
        Write-Verbose ("UpgradeEQMNAVDatabase script starting at " + (Get-Date).ToLongTimeString() + "...")
        Write-Verbose "========================================================================================="        
    }
    PROCESS
    {

        # Ensure the NAV Management Module is loaded
        Ensure-NAVManagementModuleLoaded
        
        # Ensure the SQLPS PowerShell module is loaded
        Import-SqlPsModule

        #   The NAV Server Instance is not multitenant
        #if((Get-NAVServerConfigurationValue -ServerInstance $NAVServerInstance -ConfigKeyName "Multitenant") -eq $true)
        #{
        #    Write-Error "The specified Microsoft Dynamics NAV Server instance $NAVServerInstance is configured to be multitenant. This script is not intended to work with multitenant setup."
        #    return
        #}

        #  The NAV Database exists on the Sql Server Instance
        if(!(Verify-NAVDatabaseOnSqlInstance -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -DatabaseName $DatabaseName))
        {
            Write-Error "Database '$DatabaseName' does not exist on SQL Server instance '$DatabaseServer\$DatabaseInstance'"
            return
        }

        # The Codeunit to run the removal routine must exist
        Ensure-RemovalCodeCanbeLoaded($RemovalPath)


        $randomFileName = ([System.IO.Path]::GetRandomFileName()) + '.bak'
        $randomFolderOnServer = Join-Path -Path ('\\' + $fromSQLServer + '\c$\') -ChildPath ([System.IO.Path]::GetRandomFileName())
        New-Item $randomFolderOnServer -ItemType Directory | Out-Null

        $backupToFile = Join-Path -Path $randomFolderOnServer -ChildPath $randomFileName
        $localBackupFile = Join-Path -Path $WorkingDirectory -ChildPath $randomFileName

        $localSQLName_Mdf = $DatabaseName + '.mdf'
        $localSQLName_Ldf = $DatabaseName + '.ldf'

        $localSQLFolder = Join-Path -Path ${env:ProgramFiles} -ChildPath '\Microsoft SQL Server\MSSQL13.SQL2016\MSSQL\DATA\'

        $DataFilesDestinationPath = Join-Path -Path $LocalSQLFolder -ChildPath $localSQLName_Mdf
        $LogFilesDestinationPath = Join-Path -Path $LocalSQLFolder -ChildPath $localSQLName_Ldf

        $timeOut = 300
        $navUidOffset = 15000600


        # Initilize an empty list that will be populated with all the tasks that are executed part of Microsoft Dynamics NAV Data Upgrade process.
        # The list will include statistics regarding execution time, status and the associated script block
        $UpgradeTasks = [ordered]@{}


        # Backup SQL on Server
        . Setup-UpgradeTask `
            -TaskName "Backup SQL Database from the server" `
            -ScriptBlock {

                    Backup-EQMNAVSqlServer `
                        -fromSQLServer $FromSQLServer `
                        -FromSQLServerInstance $fromSQLServerInstance `
                        -BackupToFile $backupToFile `
                        -fromSQLDatabaseName $fromsqldatabasename

                } | %{ $UpgradeTasks.Add($_.Statistics, $_.ScriptBlock) }

        # Copy SQL backup from server
        . Setup-UpgradeTask `
            -TaskName "Copy SQL Database from the server" `
            -ScriptBlock {

                    Copy-EQMNAVSQLFromServer `
                        -fromSQLServer $fromSQLServer `
                        -backupToFile $backupToFile `
                        -WorkingDirectory $WorkingDirectory `
                        -folderOnServer $randomFolderOnServer

                } | %{ $UpgradeTasks.Add($_.Statistics, $_.ScriptBlock) }

        # Remove existing service and SQL
        . Setup-UpgradeTask `
            -TaskName "Remove current local NAV Service Instance and local SQL Database" `
            -ScriptBlock {

                    Remove-EQMNAVLocalService -ServerInstance $NAVServerInstance
                    Remove-EQMNAVLocalSQL `
                        -SQLServerInstance $DatabaseInstance `
                        -SQLServerDatabaseName $DatabaseName

                } | %{ $UpgradeTasks.Add($_.Statistics, $_.ScriptBlock) }



        # Create NAV SQL Database
        . Setup-UpgradeTask `
            -TaskName "Add EQM Database to local SQL" `
            -ScriptBlock {

                    Add-EQMNAVSQLDatabase `
                        -toSQLServerInstance $DatabaseInstance `
                        -toSQLServer $DatabaseServer `
                        -toServiceAccount $NAVServerServiceAccount `
                        -toBackupFile $localBackupFile `
                        -toSQLServerDatabaseName $DatabaseName `
                        -toDataFilesDestinationPath $DataFilesDestinationPath `
                        -toLogFilesDestinationPath $LogFilesDestinationPath `
                        -totimeOut $timeOut

                } | %{ $UpgradeTasks.Add($_.Statistics, $_.ScriptBlock) }


        $DatabaseSQLServerInstance = Get-SqlServerInstance -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance
        $NavServerInfo = New-Object PSObject
        #Add-Member -InputObject $NavServerInfo -MemberType NoteProperty -Name NavServerName -Value "Localhost"
        #Add-Member -InputObject $NavServerInfo -MemberType NoteProperty -Name NavServerInstance -Value (Get-NAVServerConfigurationValue -ServerInstance $NAVServerInstance -ConfigKeyName "ServerInstance")
        #Add-Member -InputObject $NavServerInfo -MemberType NoteProperty -Name NavServerManagementPort -Value (Get-NAVServerConfigurationValue -ServerInstance $NAVServerInstance -ConfigKeyName "ManagementServicesPort")


        # Perform technical upgrade of the NAV database                                                          
        . Setup-UpgradeTask `
            -TaskName "Technical upgrade to NAV 2017" `
            -ScriptBlock {
                
                   Invoke-NAVDatabaseConversion `
                        -DatabaseName $DatabaseName `
                        -DatabaseServer $DatabaseSQLServerInstance `
                        -LogPath $UpgradeLogsDirectory\"Database Conversion"                                          
                 } | %{ $UpgradeTasks.Add($_.Statistics, $_.ScriptBlock) }


        # Create NAV Service
        . Setup-UpgradeTask `
            -TaskName "Add EQM NAV Service" `
            -ScriptBlock {

                    $ServerInstance_LocalMSO = 'Local_EQM2017W1_Alfa'
                    $ServerInstanceExists = Get-NAVServerInstance -ServerInstance $ServerInstance_LocalMSO
                    if ($ServerInstanceExists) {
                        Set-NAVServerInstance -ServerInstance $ServerInstance_LocalMSO -Stop
                    }

                    $ServerInstanceExists = Get-NAVServerInstance -ServerInstance $NAVServerInstance
                    if ($ServerInstanceExists) {
                        Remove-EQMNAVLocalService -ServerInstance $NAVServerInstance
                    }

                    Add-EQMNAVService `
                        -NAVServerInstance $NAVServerInstance `
                        -ServiceAccount $NAVServerServiceAccount `
                        -SQLServerInstance $DatabaseInstance `
                        -SQLServer $DatabaseServer `
                        -SQLServerDatabaseName $DatabaseName

                } | %{ $UpgradeTasks.Add($_.Statistics, $_.ScriptBlock) }


        # Start NAV Service
        . Setup-UpgradeTask `
            -TaskName "Connect the EQM NAV Server" `
            -ScriptBlock {

                    Start-EQMNAVService -NAVServerInstance $NAVServerInstance

                } | %{ $UpgradeTasks.Add($_.Statistics, $_.ScriptBlock) }


        # Synchronize the NAV database
        . Setup-UpgradeTask `
            -TaskName "Synchronize the EQM NAV Database" `
            -ScriptBlock {

                    Sync-NAVTenant -ServerInstance $NAVServerInstance -Mode Sync -Force
                    #Synchronize-EQMNAVService -NAVServerInstance $NAVServerInstance

                } | %{ $UpgradeTasks.Add($_.Statistics, $_.ScriptBlock) }


        # Set UidOffset
        #. Setup-UpgradeTask `
        #    -TaskName "Set the UidOffset in the Database" `
        #    -ScriptBlock {
        #            Set-EQMNAVStartUidOffset -NAVServerInstance $NAVServerInstance -navUidOffset $navUidOffset
        #        } | %{ $UpgradeTasks.Add($_.Statistics, $_.ScriptBlock) }

        # Start Routine to clean up comments in EQM objects
        . Setup-UpgradeTask `
            -TaskName "Run Clean up Comments in EQM Objects" `
            -ScriptBlock {

                    Start-CleanUpEQMComments `
                        -LocalNAVServerInstance $NAVServerInstance `
                        -RemovalPath $RemovalPath `
                        -WorkingDirectory $WorkingDirectory

                } | %{ $UpgradeTasks.Add($_.Statistics, $_.ScriptBlock) }


        # Synchronize the metadata changes to SQL         
        . Setup-UpgradeTask `
            -TaskName "Synchronize the metadata changes to SQL" `
            -ScriptBlock {
                    
                    Sync-NAVTenant -ServerInstance $NAVServerInstance -Mode Sync -Force
                                                                               
                 } | %{ $UpgradeTasks.Add($_.Statistics, $_.ScriptBlock) }


        # Run the upgrade tasks and stop if an error has occurred         
        foreach($UpgradeTask in $UpgradeTasks.GetEnumerator())
        {
            Execute-UpgradeTask -currentTask ([ref]$UpgradeTask.Name) -scriptBlock $UpgradeTask.Value

            if($UpgradeTask.Name.Status -eq 'Failed')
            {
                Write-Host -ForegroundColor Red "-----------------------------------------------------------------------------------------"
                Write-Host -ForegroundColor Red "The data upgrade to Microsoft Dynamics NAV 2017 EQM completed with errors."
                Write-Host -ForegroundColor Red "-----------------------------------------------------------------------------------------"
           
                return $UpgradeTasks.Keys   
            }
        }

        Write-Host -ForegroundColor Green "-----------------------------------------------------------------------------------------"
        Write-Host -ForegroundColor Green "The data upgrade to Microsoft Dynamics NAV 2017 EQM completed successfully."
        Write-Host -ForegroundColor Green "You can start the Microsoft Dynamics NAV Windows client on the upgraded database using $NavServerInstance."
        Write-Host -ForegroundColor Green "-----------------------------------------------------------------------------------------"
                        
        return $UpgradeTasks.Keys                
    }
    END
    {
        Write-Verbose "=========================================================================================" 
        Write-Verbose ("Job script finished at " + (Get-Date).ToLongTimeString() + ".")
        Write-Verbose "========================================================================================="
    }   
}

Export-ModuleMember -Function HowTo-UpgradeEQMNAVBETADatabase


function Ensure-RemovalCodeCanbeLoaded([String]$RemovalPath)
{
    $pathExist = Test-Path $removalPath -PathType leaf
    IF ($pathExist -ne $true) {
        write-Error "Error - The file $removalPath does not exist."
        return
    }
}

function Ensure-NAVManagementModuleLoaded
{
    $loadedNavMngCommands = Get-Command * -Module Microsoft.Dynamics.NAV.Management -ErrorAction SilentlyContinue -ErrorVariable errVar
    if($errVar -ne $null)
    {
        Write-Error "Error when trying to get the commands provided by module `'Microsoft.Dynamics.NAV.Management`': $errVar"
        return
    }
    if($loadedNavMngCommands -eq $null)
    {
        Import-NAVManagementModule
    }
}

function Setup-UpgradeTask([string]$TaskName,[scriptblock]$ScriptBlock)
{
    $initTaskStatistics = New-Object PSObject
    Add-Member -InputObject $initTaskStatistics -MemberType NoteProperty -Name "Upgrade Task" -Value $TaskName                                                                                              
    
    Add-Member -InputObject $initTaskStatistics -MemberType NoteProperty -Name "Start Time" -Value ""
    Add-Member -InputObject $initTaskStatistics -MemberType NoteProperty -Name "Duration (hh:mm:sec,msec)" -Value ""

    Add-Member -InputObject $initTaskStatistics -MemberType NoteProperty -Name "Status" -Value 'NotStarted'     
    Add-Member -InputObject $initTaskStatistics -MemberType NoteProperty -Name "Error" -Value ""        

    $taskContent = New-Object PSObject
    Add-Member -InputObject $taskContent -MemberType NoteProperty -Name "Statistics" -Value $initTaskStatistics                                                                                              
    Add-Member -InputObject $taskContent -MemberType NoteProperty -name "ScriptBlock" -Value $ScriptBlock 
    
    return $taskContent
}


function Execute-UpgradeTask([PSObject][ref]$currentTask,[scriptblock]$scriptBlock)
{
        Write-Verbose "Running Upgrade Task `"$($currentTask.'Upgrade Task')`"..."

        $startTime = Get-Date
        $currentTask.'Start Time' = $startTime.ToLongTimeString()      
       
        try
        {
            . $scriptBlock | Out-Null   
            
            $currentTask."Status" = 'Completed'                             
        }
        catch [Exception]
        {
            $currentTask."Status" = 'Failed'                                       
            $currentTask."Error" = $_.Exception.Message + [Environment]::NewLine + "Script stack trace: " + [Environment]::NewLine + $_.ScriptStackTrace                                    
        }
        finally
        {    
            $duration = NEW-TIMESPAN -Start $startTime             
            $durationFormat = '{0:00}:{1:00}:{2:00}.{3:000}' -f  $duration.Hours,$duration.Minutes,$duration.Seconds,$duration.Milliseconds
            
            $currentTask.'Duration (hh:mm:sec,msec)' = $durationFormat                
        }
}
