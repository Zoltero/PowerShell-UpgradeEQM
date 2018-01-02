function Import-EQMUpgradeToolKit
{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$false, Position=0)]
    [System.String]
    $wrkNavServerInstance,
    
    [Parameter(Mandatory=$false, Position=1)]
    [System.String]
    $upgradePath,
    
    [Parameter(Mandatory=$false, Position=2)]
    [System.String]
    $wrkLogPath
  )
  
  # Import upgrade toolkit
  $navFilter = 'Version List=*@EQMUPGTK10.00.00*'
  Import-NAVApplicationObject2 -Path $removalPath -ServerInstance $wrkNAVServerInstance -LogPath $wrkLogPath
  Compile-NAVApplicationObject2 -ServerInstance $wrkNAVServerInstance -LogPath $wrkLogPath -Filter $navFilter
}
Export-ModuleMember -Function Import-EQMUpgradeToolKit