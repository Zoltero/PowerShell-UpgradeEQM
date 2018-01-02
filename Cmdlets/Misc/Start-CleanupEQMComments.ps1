Function Start-CleanUpEQMComments 
{
    [CmdletBinding()]
    param 
        ( 
            [parameter(Mandatory=$true)]
            [string]$LocalNAVServerInstance,

            [parameter(Mandatory=$true)]
            [string]$RemovalPath,

            [parameter(Mandatory=$true)]
            [string]$WorkingDirectory
        )
    BEGIN
    {
    }
    PROCESS
    {
        # Import Removal code
        $pathExist = Test-Path $RemovalPath -PathType leaf
        IF ($pathExist -ne $true) {
            write-Error "Error - The file $RemovalPath does not exist."
            return
        }

        Import-EQMRemovalCode `
            -wrkNavServerInstance $localNAVServerInstance `
            -removalPath $RemovalPath `
            -wrkLogPath $WorkingDirectory


        # Removes the comments from EQM objects
        Remove-EQMRemoveComments `
            -wrkNavServerInstance $localNAVServerInstance `
            -WorkingDirectory $WorkingDirectory

        $navFilter = 'Version List=*@EQM*'
        Write-Verbose "Compiling EQM objectgs in $localNAVServerInstance"
        Compile-NAVApplicationObject2 `
            -ServerInstance $localNAVServerInstance `
            -LogPath $WorkingDirectory `
            -Filter $navFilter
    }
}

Export-ModuleMember -Function Start-CleanupEQMComments

