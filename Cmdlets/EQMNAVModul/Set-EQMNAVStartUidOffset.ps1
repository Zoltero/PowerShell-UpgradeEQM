function Set-EQMNAVStartUidOffset
{
    [CmdletBinding()]
    Param(
        [String]$NAVServerInstance,
        [Int]$navUidOffset
    )

    $ServerInstanceExists = Get-NAVServerInstance -ServerInstance $NAVServerInstance
    if ($ServerInstanceExists) {
        Write-Verbose "Setting Start ID (UidOffset) to $navUidOffset..."
        Set-NAVUidOffset -ServerInstance $NAVServerInstance -UidOffSet $navUidOffset
    }
}
Export-ModuleMember -Function Set-EQMNAVStartUidOffset