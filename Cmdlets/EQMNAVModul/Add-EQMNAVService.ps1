function Add-EQMNAVService
{
    [CmdletBinding()]
    Param(
        [String]$NAVServerInstance,
        [String]$ServiceAccount,
        [String]$SQLServerInstance,
        [String]$SQLServer,
        [String]$SQLServerDatabaseName
    )

    $mgtServicesPort = 7065
    $clientServicesPort = 7066
    $soapServicesPort = 7067
    $odataServicesPost = 7068

    $localServiceAccountPW = ConvertTo-SecureString 'Oscar2481' -AsPlainText -Force
    $localServiceAccountCredentials = New-Object System.Management.Automation.PSCredential($ServiceAccount, $localServiceAccountPW)


    Write-Verbose "Creating new NAV server instance on $SQLServer..."
    New-NAVServerInstance `
        -ManagementServicesPort $mgtServicesPort `
        -ServerInstance $NAVServerInstance `
        -ClientServicesPort $clientServicesPort `
        -SOAPServicesPort $soapServicesPort `
        -ODataServicesPort $odataServicesPost `
        -ServiceAccount User `
        -ServiceAccountCredential $localServiceAccountCredentials `
        -DatabaseName $SQLServerDatabaseName `
        -DatabaseInstance $SQLServerInstance `
        -DatabaseServer $SQLServer `
        -Force
}
Export-ModuleMember -Function Add-EQMNAVService