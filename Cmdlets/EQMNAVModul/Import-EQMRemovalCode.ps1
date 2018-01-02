function Import-EQMRemovalCode
{
    [CmdletBinding()]
    param
        (
            [Parameter(Mandatory=$false)]
            [String]$WrkNavServerInstance,
    
            [Parameter(Mandatory=$false)]
            [String]$RemovalPath,
    
            [Parameter(Mandatory=$false)]
            [String]$WrkLogPath
        )
    BEGIN
    {
    }
    PROCESS
    {
        # Import Removal code
        $navFilter = 'Version List=REMOVE DOC'

        Import-NAVApplicationObject2 `
            -Path $removalPath `
            -ServerInstance $wrkNAVServerInstance `
            -LogPath $wrkLogPath

        Compile-NAVApplicationObject2 `
            -ServerInstance $wrkNAVServerInstance `
            -LogPath $wrkLogPath `
            -Filter $navFilter

        Synchronize-EQMNAVService -NAVServerInstance $wrkNAVServerInstance
    }
}
Export-ModuleMember -Function Import-EQMRemovalCode