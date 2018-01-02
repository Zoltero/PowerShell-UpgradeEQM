function Start-EQMNAVIdeClient
{
  <#
    .SYNOPSIS
    Short Description
    .DESCRIPTION
    Detailed Description
    .EXAMPLE
    Start-EQMNAVIdeClient
    explains how to use the command
    can be multiple lines
    .EXAMPLE
    Start-EQMNAVIdeClient
    another example
    can have as many examples as you like
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$true, Position=0)]
    [System.String]
    $NAVServerInstance,
    [Parameter(Mandatory=$true, Position=1)]
    [System.String]
    $EQMNavDatabase
  )
  
  #Start-NAVIdeClient -ServerInstance $NAVServerInstance
  Cloud.Ready.Software.NAV\Start-NAVIdeClient -ServerInstance $NavServerInstance -Database $EQMNavDatabase
}
Export-ModuleMember -Function Start-EQMNAVIdeClient