function Add-EQMNAVSQLDatabase
{
    [CmdletBinding()]
    Param(
        [String]$toSQLServerInstance,
        [String]$toSQLServer,
        [String]$toServiceAccount,
        [String]$toBackupFile,
        [String]$toSQLServerDatabaseName,
        [String]$toDataFilesDestinationPath,
        [String]$toLogFilesDestinationPath,
        [Int]$toTimeOut
    )

    Write-Verbose "Creating local SQL database on $ToSQLServer..."
    New-NAVDatabase `
        -FilePath $toBackupFile `
        -DatabaseName $toSQLServerDatabaseName `
        -DataFilesDestinationPath $toDataFilesDestinationPath `
        -LogFilesDestinationPath $toLogFilesDestinationPath `
        -DatabaseInstance $toSQLServerInstance `
        -DatabaseServer $toSQLServer `
        -ServiceAccount $toServiceAccount `
        -TimeOut $toTimeOut `
        -Force | Out-Null

    Write-Verbose "Removing SQL backup file on $ToSQLServer..."
    Remove-Item -Path $toBackupFile
}
Export-ModuleMember -Function Add-EQMNAVSQLDatabase