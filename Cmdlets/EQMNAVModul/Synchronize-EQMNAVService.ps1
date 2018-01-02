function Synchronize-EQMNAVService
{
    [CmdletBinding()]
    Param
        (
            [String]$NAVServerInstance
        )
    BEGIN
    {
    }
    PROCESS
    {
        $ServerInstanceExists = Get-NAVServerInstance -ServerInstance $NAVServerInstance
        if ($ServerInstanceExists) {
            Write-Verbose "Synchronizing new NAV server instance $NAVServerInstance..."
            Sync-NAVTenant -ServerInstance $NAVServerInstance -Force
        }
    }
}
Export-ModuleMember -Function Synchronize-EQMNAVService