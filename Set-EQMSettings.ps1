# This file contains the parameter settings that are used by the example scripts for deploying Microsoft Dynamics NAV EQM.
# By default, the parameters are preceded by "# TODO". To set a parameter, remove "# TODO" and provide a value.
[CmdletBinding()] Param()
# Specifies the Microsoft Dynaimcs NAV 2016 Server Instance that is going to be used during upgrade
# TODO: $NAVUpgrade_NAVServerInstance = 'DynamicsNAV90'

# Specifies the Microsoft Dynaimcs NAV 2016 Server Service Account
# TODO: $NAVUpgrade_NAVServerServiceAccount = 'NT AUTHORITY\NETWORK SERVICE'

# Specifies the path to the finsql.exe executable. The default location is at the equivalent of \Microsoft Dynamics NAV\110\RoleTailored Client.
# TODO: $NAVUpgrade_FinSqlExeFile = 'C:\Program Files (x86)\Microsoft Dynamics NAV\110\RoleTailored Client\finsql.exe'

# Specifies the custom path to the Microsoft.Dynamics.NAV.Ide.psm1 module. If the module cannot be found at the provided location, the default installation path is used.
# If this parameter is provided, then a valid $FinSqlExe file is required
# TODO: $NAVUpgrade_IDEModulePath = ""

# Specifies the SQL Server where the database that you want to upgrade is to be restored to
# TODO: $NAVUpgrade_DatabaseServer = 'localhost'

# Specifies the SQL Server instance where the database that you want to upgrade is to be restored to
# TODO: $NAVUpgrade_DatabaseInstance = ''

# Specifies the name of the database that is upgraded
# TODO: $NAVUpgrade_DatabaseName = 'DynamicsNAV70'

# Specifies the path to the backup file taken from the database to be upgraded, before the upgrade process starts.
# The specified directory needs to exist and the SQL Server needs to have access to it.
# TODO: $NAVUpgrade_DatabaseToUpgradeBakFile = 'C:\Temp\Backup\DynamicsNAV70_BeforeUpgrade.bak'

# Specifies the .FOB file containing the application objects in the Microsoft Dynamics NAV 2016 version
# TODO: $NAVUpgrade_NewVersionObjectsFobFilePath = "C:\Temp\Upgrade\NewObjects.fob"

# Specifies the .FOB file containing the upgrade objects
# TODO: $NAVUpgrade_UpgradeToolkitObjectsFobFilePath = "C:\Temp\Upgrade\Upgrade710800.FOB"

# Specifies the filter that identifies the upgrade objects in the Microsoft Dynamics NAV 2016 database.
# TODO: $NAVUpgrade_UpgradeObjectsFilter = "Version List=UPGTK8.00.00"

# Specifies the path where the logs from the upgrade process will be put.
# TODO: $NAVUpgrade_UpgradeLogsDirectory = 'C:\Temp\Upgrade\ProcessLogs'

# Specifies the path to the RapidStart package that will be imported after the companies have been initialized in the upgraded applications.
# TODO: $NAVUpgrade_RapidStartPackageFile = 'C:\Temp\Upgrade\PackageSTCODES.rapidstart'

# Specifies the path to the Microsoft Dynamics NAV 2016 license
# TODO: $NAVUpgrade_CurrentVersionLicenseFile = 'C:\Temp\Upgrade\license.flf'

# ---------------------------------------------------------------------------------------------------------------------------

# Specifies the use of a custom settings file instead of the Set-PartnerSettings.ps1 file.
# Typically used for internal testing, where testers can have their own custom settings file.
# Custom setting files are modified copies of the Set-PartnerSettings.ps1 file with a name such as Set-PartnerSettings-Custom.ps1.
# Store custom setting files in the same location as the Set-PartnerSettings.ps1 file.
# If a custom settings file exists, it is loaded instead of the Set-PartnerSettings.ps1 file.
$customSettingsFile = $MyInvocation.MyCommand.path -replace ".ps1","-custom.ps1"

if (Test-Path $customSettingsFile -PathType Leaf) { . $customSettingsFile }

# ---------------------------------------------------------------------------------------------------------------------------
Write-Verbose "Using the following settings as input for the script:"
$MandatoryVariables = @(
    'NAVUpgrade_DatabaseServer' ,
    'NAVUpgrade_DatabaseName' ,
    'NAVUpgrade_NewVersionObjectsFobFilePath',
    'NAVUpgrade_UpgradeLogsDirectory' ,
    'NAVUpgrade_CurrentVersionLicenseFile'
)

$FobFileVariables = @(
    'NAVUpgrade_NewVersionObjectsFobFilePath',
    'NAVUpgrade_UpgradeToolkitObjectsFobFilePath'
)


# Check for variables: Check that values exist and that specified files exist.
function Check-ValidDefinedVariables
{
    param
    (
        [string[]]$List,
        [switch]$IsMandatory
    )
    PROCESS
    {
        foreach ($variableName in $list)
        {
            $var = Get-Variable -Name $variableName -ErrorAction SilentlyContinue -ErrorVariable errorVar

            if($errorVar)
            {
                if($isMandatory)
                {
                    Write-Host "Mandatory script variable '$variableName' has not been defined."
                    throw
                }

                Continue
            }

            if ($variableName -like "*File*")
            {
                if (!(Test-Path $var.Value -PathType Leaf))
                {
                    Write-Error ("   File does not exist: " + $var.Name + " = " + $var.Value) -ErrorAction Stop
                }
            }

            if ($variableName -like "*FobFile*")
            {
                if (!([System.IO.Path]::GetExtension($var.Value) -eq ".fob"))
                {
                    Write-Error ("   File: " + $var.Name + " = " + $var.Value + " does not have extension .fob") -ErrorAction Stop
                }
            }

            if($isMandatory)
            {
                Write-Verbose ("   " + $var.Name + " = " + $var.Value)
            }
        }
    }
}

#Check-ValidDefinedVariables -List $MandatoryVariables -IsMandatory
#Check-ValidDefinedVariables -List $FobFileVariables
