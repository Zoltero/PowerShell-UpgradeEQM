function Backup-EQMNavSqlServer
{
  <#
    .SYNOPSIS
    Short Description
    .DESCRIPTION
    Detailed Description
    .EXAMPLE
    Backup-EQMNavSqlServer
    explains how to use the command
    can be multiple lines
    .EXAMPLE
    Backup-EQMNavSqlServer
    another example
    can have as many examples as you like
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$true, Position=0)]
    [System.String]
    $fromSQLServer,
    
    [Parameter(Mandatory=$true, Position=1)]
    [System.String]
    $fromSQLServerInstance,
    
    [Parameter(Mandatory=$true, Position=2)]
    [System.String]
    $fromSQLDatabaseName,
    
    [Parameter(Mandatory=$true, Position=3)]
    [System.String]
    $backupToFile
  )
  
  Write-Verbose "Creating SQL backup file on $fromSQLServer..."
  SQLPS\Backup-SqlDatabase -ServerInstance $fromSQLServerInstance -Database $fromSQLDatabaseName -BackupFile $backupToFile
}
Export-ModuleMember -Function Backup-EQMNavSqlServer