function Start-EQMNAVService
{
    [CmdletBinding()]
    Param(
        [String]$NAVServerInstance
    )

    $ServerInstanceExists = Get-NAVServerInstance -ServerInstance $NAVServerInstance
    if ($ServerInstanceExists) {
        Write-Verbose "Starting new NAV server instance $NAVServerInstance..."
        Set-NAVServerInstance -ServerInstance $NAVServerInstance -Start -Force
    }
    else
    {
        Write-Verbose "Nav server instance $NAVServerInstance does not exist."
    }
}
Export-ModuleMember -Function Start-EQMNAVService