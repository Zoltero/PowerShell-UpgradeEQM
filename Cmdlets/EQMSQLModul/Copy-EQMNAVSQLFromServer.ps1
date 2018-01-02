function Copy-EQMNAVSQLFromServer
{
    [CmdletBinding()]
    Param(
        [String]$fromSQLServer,
        [String]$backupToFile,
        [String]$WorkingDirectory,
        [String]$folderOnServer
    )
    Write-Verbose "Copying SQL backup file from $fromSQLServer..."
    Move-Item $backupToFile $WorkingDirectory

    Write-Verbose "Removing temporary files on $fromSQLServer..."
    Remove-Item -Path $folderOnServer -Recurse
}
Export-ModuleMember -Function Copy-EQMNAVSQLFromServer