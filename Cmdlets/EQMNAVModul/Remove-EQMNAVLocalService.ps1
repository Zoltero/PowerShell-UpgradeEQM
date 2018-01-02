function Remove-EQMNAVLocalService
{
    [CmdletBinding()]
    Param(
        [String]$ServerInstance
    )
    
    Write-Verbose "Search for NAV server instance $ServerInstance..."
    $ServerInstanceExists = Get-NAVServerInstance -ServerInstance $ServerInstance
    if ($ServerInstanceExists) {
        Write-Verbose " - Removing NAV server instance $ServerInstance..."
        Remove-NAVServerInstance -ServerInstance $ServerInstance -Force
    }
    else
    {
        write-Verbose " - NAV server instance does not exist."
    }
}
Export-ModuleMember -Function Remove-EQMNAVLocalService