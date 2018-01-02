Function Remove-EQMNAVLocalSQL
{
    [CmdletBinding()]
    Param(
        [String]$SQLServerInstance,
        [String]$SQLServerDatabaseName
    )

    Write-Verbose "Dropping SQL server database $SQLServerDatabaseName..."
    Drop-SQLDatabaseIfExists -SQLServer $SQLServerInstance -Databasename $SQLServerDatabaseName
}
Export-ModuleMember -Function Remove-EQMNAVLocalSQL