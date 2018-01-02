<#
    .SYNOPSIS
        Exports the license from the specified Microsoft Dynamics NAV database. 		
    .DESCRIPTION        
        Exports the license from the specified Microsoft Dynamics NAV database. 
		The license is stored in the $ndo$tenantproperty table in the database. 
		The conversion from a BLOB to a binary file is handled by the bcp tool, which is part of the SQL Server Management Tools. 
		For more information, see http://msdn.microsoft.com/en-us/library/ms162802.aspx
    .PARAMETER DatabaseServer
        Specifies the SQL Server database server.
    .PARAMETER DatabaseInstance
        Specifies the SQL Server instance.
    .PARAMETER LicenseFilePath
        Specifies the location where the license information must be exported to.
	.PARAMETER DatabaseName
        Specifies the database containing the table with the license information that must be exported.
#>

function Export-NAVLicenseFromApplicationDatabase
{
   [CmdletBinding()]
    param
        (
            [parameter(Mandatory=$true)]
            [string]$DatabaseServer,
            
            [parameter(Mandatory=$false)]            
            [string]$DatabaseInstance = "",

            [parameter(Mandatory=$true)]
            [string]$LicenseFilePath,

            [parameter(Mandatory=$true)]
            [string]$DatabaseName            
        )
    PROCESS
    {
        Write-Verbose "Export license from the application database of $DatabaseName"
        Export-NAVLicense -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -LicenseFilePath $LicenseFilePath -DatabaseName $DatabaseName -TableName '$ndo$dbproperty'
    }
}

function Export-NAVLicenseFromTenantDatabase
{
   [CmdletBinding()]
    param
        (
            [parameter(Mandatory=$true)]
            [string]$DatabaseServer,
            
            [parameter(Mandatory=$false)]            
            [string]$DatabaseInstance = "",

            [parameter(Mandatory=$true)]
            [string]$LicenseFilePath,

            [parameter(Mandatory=$true)]
            [string]$DatabaseName            
        )
    PROCESS
    {
        Write-Verbose "Export license from the tenant database of $DatabaseName"
        Export-NAVLicense -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -LicenseFilePath $LicenseFilePath -DatabaseName $DatabaseName -TableName '$ndo$tenantproperty'
    }
}

function Export-NAVLicenseFromMaster
{
   [CmdletBinding()]
    param
        (
            [parameter(Mandatory=$true)]
            [string]$DatabaseServer,
            
            [parameter(Mandatory=$false)]            
            [string]$DatabaseInstance = "",

            [parameter(Mandatory=$true)]
            [string]$LicenseFilePath         
        )
    PROCESS
    {
        Write-Verbose "Export license from the master database of $DatabaseServer\$DatabaseInstance"
        Export-NAVLicense -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -LicenseFilePath $LicenseFilePath -DatabaseName 'master' -TableName '$ndo$srvproperty'
    }
}

function Export-NAVLicense
{
    [CmdletBinding()]
    param
        (
            [parameter(Mandatory=$true)]
            [string]$DatabaseServer,
            
            [parameter(Mandatory=$false)]            
            [string]$DatabaseInstance = "",

            [parameter(Mandatory=$true)]
            [string]$LicenseFilePath,

            [parameter(Mandatory=$true)]
            [string]$DatabaseName,
            
            [parameter(Mandatory=$true)]
            [string]$TableName
        )
    BEGIN
    {
        if(!(Test-Path -Path $LicenseFilePath -IsValid))
        {
            Write-Error "Destination license file path $LicenseFilePath is not valid"
            return
        }

        $licenseDirectory = [System.IO.Path]::GetDirectoryName($LicenseFilePath)
        if(!(Test-Path $licenseDirectory -PathType Container))
        {
            New-Item -Path $licenseDirectory -ItemType Container | Out-Null
        }

        if(!(Test-Path -Path $LicenseFilePath -PathType Leaf))
        {
            New-Item -Path $LicenseFilePath -ItemType File | Out-Null
        }

        $SqlServerInstance = Get-SqlServerInstance $DatabaseServer $DatabaseInstance                
        
        if(!(Test-LicenseExistsInTable -SqlServerInstance $SqlServerInstance -DatabaseName $DatabaseName -TableName $TableName))
        {            
            return
        }               

        # Generate a format file for the license column content to be exported later on
        $FormatFilePath = (Join-Path $licenseDirectory "licenseFormat.fmt")
        if(Get-Item $FormatFilePath -ErrorAction SilentlyContinue)
        {
            Remove-Item -Path $FormatFilePath | Out-Null
        }
        
        # Try extract the format from the master table
        $ExtractFormatArguments = "`"`[`$ndo`$srvproperty`"`]  format nul -T -n -f `"$FormatFilePath`" -T -S $SqlServerInstance -d master"
        Start-ProcessWithErrorHandling -FilePath "bcp" -ArgumentList $ExtractFormatArguments

        # If there are errors (the SQL Server instance does not have the master table), create the exported format
        if(!(Test-Path -Path $FormatFilePath))
        {
            # Create the format to extract the license file, since it could not be extracted from the master table
            $sqlVersion = Invoke-Sqlcmd "select left(cast(serverproperty('productversion') as varchar), 4)" -ServerInstance $SqlServerInstance          
                 
            $stream = [System.IO.StreamWriter] $FormatFilePath
            
            $stream.WriteLine($sqlVersion.Column1)
            $stream.WriteLine("1")
            $stream.WriteLine("1       SQLIMAGE            0       0       ""   1     license            """);
            $stream.close()
        }

        # Modify the file to have 0 for prefix length, instead of 4
        (Get-Content $FormatFilePath) `
            | Foreach { $_ -Replace "1       SQLIMAGE            4", "1       SQLIMAGE            0" } `
            | Set-Content $FormatFilePath;
 
        # Extract the license
        $ArgumentList = "`"SELECT license FROM [$TableName`]`" queryout ""$LicenseFilePath"" -T -S $SqlServerInstance -d `"$DatabaseName`" -f `"$FormatFilePath`""            
        Start-ProcessWithErrorHandling -FilePath "bcp" -ArgumentList "$ArgumentList"        

        if(Get-Item $FormatFilePath -ErrorAction SilentlyContinue)
        {
            Remove-Item -Path $FormatFilePath | Out-Null
        }

        return $LicenseFilePath
    }
}

function Test-LicenseExistsInTable
{
    [CmdletBinding()]
    param
        (
            [parameter(Mandatory=$true)]
            [string]$SqlServerInstance,

            [parameter(Mandatory=$true)]
            [string]$DatabaseName,
            
            [parameter(Mandatory=$true)]
            [string]$TableName
        )
    PROCESS
    {
        $CurrentLocation = Get-Location

        try
        {
            if(!(Test-TableExistsInSQL -SqlServerInstance $SqlServerInstance -DatabaseName $DatabaseName -TableName $TableName))
            {
                return $false;
            }

            # Check the license column exists
            $licenseColumnExists = Invoke-Sqlcmd "IF EXISTS(SELECT * from sys.columns where Name = N'license' and Object_ID = Object_ID(N'$TableName')) SELECT 1 as res else select 0 as res" -ServerInstance $SqlServerInstance -Database $DatabaseName     
            if($licenseColumnExists.res -eq 0)
            {
                Write-Verbose "Table [$DatabaseName].[$TableName] does not contain column 'license'."
                return $false
            }

            # Check the license column is not empty
            $licenseFieldIsNull = Invoke-Sqlcmd "IF EXISTS (SELECT license from [$DatabaseName].[dbo].[$TableName] WHERE license is NULL) SELECT 1 as res else select 0 as res" -ServerInstance $SqlServerInstance -Database $DatabaseName     
            if($licenseFieldIsNull.res -eq 1)
            {
                Write-Verbose "Table [$DatabaseName].[$TableName] does not contain license information."
                return $false
            }

            return $true
        }
        finally
        {
            Set-Location $CurrentLocation   
        }
    }
}

function Test-TableExistsInSQL
{
    [CmdletBinding()]
    param
        (
            [parameter(Mandatory=$true)]
            [string]$SqlServerInstance,

            [parameter(Mandatory=$true)]
            [string]$DatabaseName,
            
            [parameter(Mandatory=$true)]
            [string]$TableName
        )
    PROCESS
    {    
        $tableExists = Invoke-Sqlcmd "IF EXISTS (SELECT 1 
        FROM [$DatabaseName].INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_NAME='$TableName') 
        SELECT 1 AS res ELSE SELECT 0 AS res;" -ServerInstance $SqlServerInstance -Database $DatabaseName         
 
        if($tableExists.res -eq 0)
        {
            Write-Verbose "Table [$DatabaseName].[dbo].$TableName was not found in SQL Server $SqlServerInstance"
            return $false
        }
        
        return $true
    }
}

Export-ModuleMember -Function Export-NAVLicense, Export-NAVLicenseFromApplicationDatabase, Export-NAVLicenseFromTenantDatabase, Export-NAVLicenseFromMaster, Test-LicenseExistsInTable
# SIG # Begin signature block
# MIIkBQYJKoZIhvcNAQcCoIIj9jCCI/ICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA1MTeVJwLG8r3R
# Eb1oONT0K5ALv/8/+s6Y35aoEg8NKqCCDYIwggYAMIID6KADAgECAhMzAAAAww6b
# p9iy3PcsAAAAAADDMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTcwODExMjAyMDI0WhcNMTgwODExMjAyMDI0WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC7V9c40bEGf0ktqW2zY596urY6IVu0mK6N1KSBoMV1xSzvgkAqt4FTd/NjAQq8
# zjeEA0BDV4JLzu0ftv2AbcnCkV0Fx9xWWQDhDOtX3v3xuJAnv3VK/HWycli2xUib
# M2IF0ZWUpb85Iq2NEk1GYtoyGc6qIlxWSLFvRclndmJdMIijLyjFH1Aq2YbbGhEl
# gcL09Wcu53kd9eIcdfROzMf8578LgEcp/8/NabEMC2DrZ+aEG5tN/W1HOsfZwWFh
# 8pUSoQ0HrmMh2PSZHP94VYHupXnoIIJfCtq1UxlUAVcNh5GNwnzxVIaA4WLbgnM+
# Jl7wQBLSOdUmAw2FiDFfCguLAgMBAAGjggF/MIIBezAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUpxNdHyGJVegD7p4XNuryVIg1Ga8w
# UQYDVR0RBEowSKRGMEQxDDAKBgNVBAsTA0FPQzE0MDIGA1UEBRMrMjMwMDEyK2M4
# MDRiNWVhLTQ5YjQtNDIzOC04MzYyLWQ4NTFmYTIyNTRmYzAfBgNVHSMEGDAWgBRI
# bmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEt
# MDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAE2X
# TzR+8XCTnOPVGkucEX5rJsSlJPTfRNQkurNqCImZmssx53Cb/xQdsAc5f+QwOxMi
# 3g7IlWe7bn74fJWkkII3k6aD00kCwaytWe+Rt6dmAA6iTCXU3OddBwLKKDRlOzmD
# rZUqjsqg6Ag6HP4+e0BJlE2OVCUK5bHHCu5xN8abXjb1p0JE+7yHsA3ANdkmh1//
# Z+8odPeKMAQRimfMSzVgaiHnw40Hg16bq51xHykmCRHU9YLT0jYHKa7okm2QfwDJ
# qFvu0ARl+6EOV1PM8piJ858Vk8gGxGNSYQJPV0gc9ft1Esq1+fTCaV+7oZ0NaYMn
# 64M+HWsxw+4O8cSEQ4fuMZwGADJ8tyCKuQgj6lawGNSyvRXsN+1k02sVAiPGijOH
# OtGbtsCWWSygAVOEAV/ye8F6sOzU2FL2X3WBRFkWOCdTu1DzXnHf99dR3DHVGmM1
# Kpd+n2Y3X89VM++yyrwsI6pEHu77Z0i06ELDD4pRWKJGAmEmWhm/XJTpqEBw51sw
# THyA1FBnoqXuDus9tfHleR7h9VgZb7uJbXjiIFgl/+RIs+av8bJABBdGUNQMbJEU
# fe7K4vYm3hs7BGdRLg+kF/dC/z+RiTH4p7yz5TpS3Cozf0pkkWXYZRG222q3tGxS
# /L+LcRbELM5zmqDpXQjBRUWlKYbsATFtXnTGVjELMIIHejCCBWKgAwIBAgIKYQ6Q
# 0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNh
# dGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5
# WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQD
# Ex9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0B
# AQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4
# BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe
# 0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato
# 88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v
# ++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDst
# rjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN
# 91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4ji
# JV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmh
# D+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbi
# wZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8Hh
# hUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaI
# jAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTl
# UAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNV
# HQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQF
# TuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29m
# dC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNf
# MjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNf
# MjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcC
# ARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnlj
# cHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5
# AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oal
# mOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0ep
# o/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1
# HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtY
# SWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInW
# H8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZ
# iWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMd
# YzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7f
# QccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKf
# enoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOpp
# O6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZO
# SEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCFdkwghXVAgEBMIGVMH4xCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAADDDpun2LLc9ywAAAAAAMMw
# DQYJYIZIAWUDBAIBBQCggcgwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPJy87Bd
# dNAFIUrqHsdRq9eZ8tbIwEQGH5UlSAZZhq+JMFwGCisGAQQBgjcCAQwxTjBMoC6A
# LABNAGkAYwByAG8AcwBvAGYAdAAgAEQAeQBuAGEAbQBpAGMAcwAgAE4AQQBWoRqA
# GGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTANBgkqhkiG9w0BAQEFAASCAQCiucKv
# OkflTwHmRrYkJZldowKqHMChplvlilv47ed0lcQmIW/OPMwE0HjNW7I3Tn04Y2Io
# /u2zuTSbuacsDGm+tuYThpogsslTo1JrpIbIuKwAFAso+FRNTCof0mlNUNYiihCe
# Hd8TBCnJuKzzy1TY5XDdPAmFXFrq01sohshKzl5UAv6FCIyTwwkhoc2q8vUZLGMn
# UKjyHAhEDU7YPJv37oK/aulp8tEXQqQkovi1u/Z43Wy/jCsbdqAmVbbtkTp6i6FH
# tStNHSm79xhzl06gRiSR3U6W0FEcmxDm2YOS/qOFixAZvicyjXKXV0XwMrrwssHs
# Mn8YVFYsKK5dfPoxoYITSTCCE0UGCisGAQQBgjcDAwExghM1MIITMQYJKoZIhvcN
# AQcCoIITIjCCEx4CAQMxDzANBglghkgBZQMEAgEFADCCATwGCyqGSIb3DQEJEAEE
# oIIBKwSCAScwggEjAgEBBgorBgEEAYRZCgMBMDEwDQYJYIZIAWUDBAIBBQAEIL8z
# jSzjKTl2X67TrruDMNP0Wxug3MreTCqbLaTa3kp5AgZZ2t9sbjIYEzIwMTcxMTIy
# MjA1NDQzLjA2M1owBwIBAYACAfSggbikgbUwgbIxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xDDAKBgNVBAsTA0FPQzEnMCUGA1UECxMebkNpcGhl
# ciBEU0UgRVNOOkQyMzYtMzdEQS05NzYxMSUwIwYDVQQDExxNaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBTZXJ2aWNloIIOzTCCBnEwggRZoAMCAQICCmEJgSoAAAAAAAIwDQYJ
# KoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0
# eSAyMDEwMB4XDTEwMDcwMTIxMzY1NVoXDTI1MDcwMTIxNDY1NVowfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQCpHQ28dxGKOiDs/BOX9fp/aZRrdFQQ1aUKAIKF++18aEssX8XD5WHCdrc+
# Zitb8BVTJwQxH0EbGpUdzgkTjnxhMFmxMEQP8WCIhFRDDNdNuDgIs0Ldk6zWczBX
# JoKjRQ3Q6vVHgc2/JGAyWGBG8lhHhjKEHnRhZ5FfgVSxz5NMksHEpl3RYRNuKMYa
# +YaAu99h/EbBJx0kZxJyGiGKr0tkiVBisV39dx898Fd1rL2KQk1AUdEPnAY+Z3/1
# ZsADlkR+79BL/W7lmsqxqPJ6Kgox8NpOBpG2iAg16HgcsOmZzTznL0S6p/TcZL2k
# AcEgCZN4zfy8wMlEXV4WnAEFTyJNAgMBAAGjggHmMIIB4jAQBgkrBgEEAYI3FQEE
# AwIBADAdBgNVHQ4EFgQU1WM6XIoxkPNDe3xGG8UzaFqFbVUwGQYJKwYBBAGCNxQC
# BAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYD
# VR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZF
# aHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9v
# Q2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcw
# AoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJB
# dXRfMjAxMC0wNi0yMy5jcnQwgaAGA1UdIAEB/wSBlTCBkjCBjwYJKwYBBAGCNy4D
# MIGBMD0GCCsGAQUFBwIBFjFodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vUEtJL2Rv
# Y3MvQ1BTL2RlZmF1bHQuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABf
# AFAAbwBsAGkAYwB5AF8AUwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEB
# CwUAA4ICAQAH5ohRDeLG4Jg/gXEDPZ2joSFvs+umzPUxvs8F4qn++ldtGTCzwsVm
# yWrf9efweL3HqJ4l4/m87WtUVwgrUYJEEvu5U4zM9GASinbMQEBBm9xcF/9c+V4X
# NZgkVkt070IQyK+/f8Z/8jd9Wj8c8pl5SpFSAK84Dxf1L3mBZdmptWvkx872ynoA
# b0swRCQiPM/tA6WWj1kpvLb9BOFwnzJKJ/1Vry/+tuWOM7tiX5rbV0Dp8c6ZZpCM
# /2pif93FSguRJuI57BlKcWOdeyFtw5yjojz6f32WapB4pm3S4Zz5Hfw42JT0xqUK
# loakvZ4argRCg7i1gJsiOCC1JeVk7Pf0v35jWSUPei45V3aicaoGig+JFrphpxHL
# mtgOR5qAxdDNp9DvfYPw4TtxCd9ddJgiCGHasFAeb73x4QDf5zEHpJM692VHeOj4
# qEir995yfmFrb3epgcunCaw5u+zGy9iCtHLNHfS4hQEegPsbiSpUObJb2sgNVZl6
# h3M7COaYLeqN4DMuEin1wC9UJyH3yKxO2ii4sanblrKnQqLJzxlBTeCG+SqaoxFm
# MNO7dDJL32N79ZmKLxvHIa9Zta7cRDyXUHHXodLFVeNp3lfB0d4wwP3M5k37Db9d
# T+mdHhk4L7zPWAUu7w2gUDXa7wknHNWzfjUeCLraNtvTX4/edIhJEjCCBNkwggPB
# oAMCAQICEzMAAACuDtZOlonbAPUAAAAAAK4wDQYJKoZIhvcNAQELBQAwfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMTYwOTA3MTc1NjU1WhcNMTgwOTA3
# MTc1NjU1WjCBsjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEM
# MAoGA1UECxMDQU9DMScwJQYDVQQLEx5uQ2lwaGVyIERTRSBFU046RDIzNi0zN0RB
# LTk3NjExJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDeki/DpJVy9T4NZmTD+uboIg90
# jE3Bnse2VLjxj059H/tGML58y3ue28RnWJIv+lSABp+jPp8XIf2p//DKYb0o/QSO
# J8kGUoFYesNTPtqyf/qohLW1rcLijiFoMLABH/GDnDbgRZHxVFxHUG+KNwffdC0B
# YC3Vfq3+2uOO8czRlj10gRHU2BK8moSz53Vo2ZwF3TMZyVgvAvlg5sarNgRwAYwb
# wWW5wEqpeODFX1VA/nAeLkjirCmg875M1XiEyPtrXDAFLng5/y5MlAcUMYJ6dHuS
# BDqLLXipjjYakQopB3H1+9s8iyDoBM07JqP9u55VP5a2n/IZFNNwJHeCTSvLAgMB
# AAGjggEbMIIBFzAdBgNVHQ4EFgQUfo/lNDREi/J5QLjGoNGcQx4hJbEwHwYDVR0j
# BBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0
# cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljVGltU3Rh
# UENBXzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNUaW1TdGFQQ0Ff
# MjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcD
# CDANBgkqhkiG9w0BAQsFAAOCAQEAPVlNePD0XDQI0bVBYANTDPmMpk3lIh6gPIil
# g0hKQpZNMADLbmj+kav0GZcxtWnwrBoR+fpBsuaowWgwxExCHBo6mix7RLeJvNyN
# YlCk2JQT/Ga80SRVzOAL5Nxls1PqvDbgFghDcRTmpZMvADfqwdu5R6FNyIgecYNo
# yb7A4AqCLfV1Wx3PrPyaXbatskk5mT8NqWLYLshBzt2Ca0bhJJZf6qQwg6r2gz1p
# G15ue6nDq/mjYpTmCDhYz46b8rxrIn0sQxnFTmtntvz2Z1jCGs99n1rr2ZFrGXOJ
# S4Bhn1tyKEFwGJjrfQ4Gb2pyA9aKRwUyK9BHLKWC5ZLD0hAaIKGCA3cwggJfAgEB
# MIHioYG4pIG1MIGyMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MQwwCgYDVQQLEwNBT0MxJzAlBgNVBAsTHm5DaXBoZXIgRFNFIEVTTjpEMjM2LTM3
# REEtOTc2MTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIl
# CgEBMAkGBSsOAwIaBQADFQDHwb0we6UYnmReZ3Q2+rvjmbxo+6CBwTCBvqSBuzCB
# uDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEMMAoGA1UECxMD
# QU9DMScwJQYDVQQLEx5uQ2lwaGVyIE5UUyBFU046MjY2NS00QzNGLUM1REUxKzAp
# BgNVBAMTIk1pY3Jvc29mdCBUaW1lIFNvdXJjZSBNYXN0ZXIgQ2xvY2swDQYJKoZI
# hvcNAQEFBQACBQDdv8QdMCIYDzIwMTcxMTIyMDkzODM3WhgPMjAxNzExMjMwOTM4
# MzdaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAN2/xB0CAQAwCgIBAAICGhcCAf8w
# BwIBAAICGbMwCgIFAN3BFZ0CAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGE
# WQoDAaAKMAgCAQACAxbjYKEKMAgCAQACAx6EgDANBgkqhkiG9w0BAQUFAAOCAQEA
# UzN29vokRanES9+bNH3Dz6+pACau/qILw/PhXC7l+1ahXt5+SJEOj9Ngwmz/We1z
# ingiltqgiRf3FJFlPhiM210s7Vkg2ki8P7vdLLQ8xKCEMcWs4gN1OpRv9MsqohNz
# //5IOi88j7e2S9jEVHGkjVvyjk3WgTk/+9FXgM3HxBkECTmTAKFXo6cRYYljJ0XV
# nwAEDJkIq68cOItuPvhvaPYg0//lri7oqQZ9CPTAiibb2O3GMz60AoXhFUDK5zA8
# O0hu7ewHqE+lXhXq9hTDWpIfCzf3XyeZRYpD0sK8XWySdyppv7HoD7cpkkDBUPoG
# dGnkQPFyjskBP2HiIvKT9zGCAvUwggLxAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwAhMzAAAArg7WTpaJ2wD1AAAAAACuMA0GCWCGSAFlAwQCAQUA
# oIIBMjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIE
# IMET+NeWTi9fnAoh8D1CwC/AipjjreuCF37IghrdZEa+MIHiBgsqhkiG9w0BCRAC
# DDGB0jCBzzCBzDCBsQQUx8G9MHulGJ5kXmd0Nvq745m8aPswgZgwgYCkfjB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAK4O1k6WidsA9QAAAAAArjAW
# BBQPs7Zu1uY9rnLtBPCl5cgFwKtLDDANBgkqhkiG9w0BAQsFAASCAQAX07McAQuF
# hzx6DsXUQbYq75VCm9f1qCLv538AZjoUNqswBXl4P7zya5YRAbkhm8tkWJ29vn2X
# t9iMhvDibCtYSxRx/pX2pt4AmeYv1TuV0whuKgcQp9+t6X0a8vPVISaSDfS9gOO6
# nw2ExDxRBEaCEdg6fMxhS+s9OP+6DipA/iE24aA8l1mO3Nuf1y9GT/BUSjnMbaj/
# sfgmqnslg8W1vuRcXob+a1fmTFBwonaNnEMaam9rSkW9NixOwSh5wRE/7L3xi+G3
# vukepg0wPf5TzbhtfOxDLtj6L/k17+QCOrDA+vohFaHdV7l4kRvUg4ImdY0IYk11
# 12lTvDyXhq+y
# SIG # End signature block
