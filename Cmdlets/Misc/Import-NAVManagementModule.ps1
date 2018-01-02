<#
    .SYNOPSIS
        Imports NAV Management PowerShell module.
    .DESCRIPTION
        Imports NAV Management PowerShell module.
#>
function Import-NAVManagementModule
{
    [CmdletBinding()]
    param
        (
        )
    PROCESS
    {
        #$ModuleFileName = "Microsoft.Dynamics.Nav.Management.psd1"
        $ModuleFileName = "Microsoft.Dynamics.Nav.Management.dll"

        # First try to import the management module based on the registry information. This is needed for the case when there are
        # multiple versions of Dynamics NAV installed on the machine. In this case, we want to import the version specific to the
        # currently executing script.
        Write-Verbose "Attempting to import the Microsoft Dynamics NAV Management module from the NAV Server assembly path"
        if (ImportNavManagementModuleFromComponentRegistryKey -NavComponent "Service" -ModuleFileName $ModuleFileName -IsPathEnvironmentVariable $true)
        {
            return
        }

        # If the import from the Server path failed, attempt to import from the Web Server path
        Write-Verbose "Failed importing from the NAV Server path."
        Write-Verbose "Attempting to import the Microsoft Dynamics NAV Management module from the NAV Web Server assembly path"
        if (ImportNavManagementModuleFromComponentRegistryKey -NavComponent "Web Client" -ModuleFileName $ModuleFileName)
        {
            return
        }

        # If the Management module import failed from the Web Server assembly location as well, fallback to add the snap-in.
        # This occurs highly likely when there are multiple versions of NAV installed and the current version is incomplete / broken.
        Write-Verbose "Module import failed."
        Write-Verbose "Trying to add the snapin instead."
        Write-Warning "The NAV Management snapin might belong to an older version of Dynamics NAV installed on this machine."
        $mgmtAssemblyName = "Microsoft.Dynamics.Nav.Management"
        if (!(Get-PSSnapin -Name $mgmtAssemblyName -ErrorAction SilentlyContinue))
        {
            if (!(Get-PSSnapin -Registered $mgmtAssemblyName -ErrorAction SilentlyContinue))
            {
                Write-Error "The $mgmtAssemblyName snapin is not registered. The cmdlets exposed by this snapin will not be available."
                return
            }
            else
            {
                Add-PSSnapin $mgmtAssemblyName
                Write-Verbose "The $mgmtAssemblyName snapin was successfully added."
                return
            }
        }
        Write-Verbose "The $mgmtAssemblyName snapin is already added."
    }
}
Export-ModuleMember -Function Import-NAVManagementModule

<#
    .SYNOPSIS
        Imports NAV Apps Management PowerShell module.
    .DESCRIPTION
        Imports NAV Apps Management PowerShell module.
#>
function Import-NAVAppsManagementModule
{
    [CmdletBinding()]
    param
        (
        )
    PROCESS
    {
        $ModuleName = "Microsoft.Dynamics.Nav.Apps.Management"
        $ModuleFileName = "$ModuleName.dll"

        # If the module is already loaded, there is no need to continue
        if(Get-Module $ModuleName)
        {
            return
        }

        # First try to import the management module based on the registry information. This is needed for the case when there are
        # multiple versions of Dynamics NAV installed on the machine. In this case, we want to import the version specific to the
        # currently executing script.
        Write-Verbose "Attempting to import the Microsoft Dynamics NAV Apps Management module from the NAV Server assembly path"
        if (ImportNavManagementModuleFromComponentRegistryKey -NavComponent "Service" -ModuleFileName $ModuleFileName -IsPathEnvironmentVariable $true)
        {
            return
        }

        # If the import from the Server path failed, attempt to import from the Web Server path.
        Write-Verbose "Failed importing from the NAV Server path."
        Write-Verbose "Attempting to import the Microsoft Dynamics NAV Apps Management module from the NAV Web Server assembly path"
        if (ImportNavManagementModuleFromComponentRegistryKey -NavComponent "Web Client" -ModuleFileName $ModuleFileName)
        {
            return
        }

        # If the Management module import failed from the Web Server assembly location as well, as a final attempt we'll see if
        # the NAV Management module is loaded and check its path for the Nav Apps management dll.
        $managementModule = Get-Module "NavManagement"
        if($managementModule)
        {
            $modulePath = Join-Path ([System.IO.Path]::GetDirectoryName($managementModule.Path)) $ModuleFileName -ErrorAction SilentlyContinue
            if(ImportModuleFromPath -ModulePath $modulePath)
            {
                return
            }
        }
        $managementSnapin = Get-PSSnapin -Name "Microsoft.Dynamics.Nav.Management" -ErrorAction SilentlyContinue
        if($managementSnapin)
        {
            $modulePath = Join-Path $managementSnapin.ApplicationBase $ModuleFileName -ErrorAction SilentlyContinue
            if(ImportModuleFromPath -ModulePath $modulePath)
            {
                return
            }
        }

        # Out of options.
        Write-Error "The Nav Apps Management dll cannot be found. The cmdlets exposed by this module will not be available."
    }
}
Export-ModuleMember -Function Import-NAVAppsManagementModule

function ImportNavManagementModuleFromComponentRegistryKey([string] $NavComponent, [string] $ModuleFileName, [bool] $IsPathEnvironmentVariable = $false)
{
    #$registryKeyPath = "HKLM:\SOFTWARE\Microsoft\Microsoft Dynamics NAV\110\$NavComponent"
    $registryKeyPath = "HKLM:\SOFTWARE\Microsoft\Microsoft Dynamics NAV\100\$NavComponent"

    $registryKey = Get-ItemProperty -Path $registryKeyPath -ErrorAction SilentlyContinue
    if ($registryKey)
    {
        $modulePath = $registryKey.Path
        if ($IsPathEnvironmentVariable)
        {
            $modulePath = [System.Environment]::ExpandEnvironmentVariables($modulePath)
        }

        $modulePath = Join-Path $modulePath $ModuleFileName -ErrorAction SilentlyContinue
        $alternativeModulePath = Join-Path (Split-Path $modulePath) "bin\$ModuleFileName" -ErrorAction SilentlyContinue

        if ((ImportModuleFromPath -ModulePath $modulePath) -or (ImportModuleFromPath -ModulePath $alternativeModulePath))
        {
            return $true
        }
    }

    Write-Verbose "Module could not be imported from the registry key path $RegistryKeyPath."
    return $false
}

function ImportModuleFromPath([string] $ModulePath)
{
    Import-Module $ModulePath -Global -ErrorVariable errorVariable -ErrorAction SilentlyContinue
    if (!$errorVariable)
    {
        Write-Verbose "Module successfully imported from $ModulePath."
        return $true
    }
}
# SIG # Begin signature block
# MIIkBQYJKoZIhvcNAQcCoIIj9jCCI/ICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDig/wPuuOhdrtr
# hNyP4mV9FCK82FqZ0zCL3iJyj2c7oqCCDYIwggYAMIID6KADAgECAhMzAAAAww6b
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEILw2wggi
# jSgGUtSa1UECK7Q9dalOZ2iIUzjvMQcdYHj/MFwGCisGAQQBgjcCAQwxTjBMoC6A
# LABNAGkAYwByAG8AcwBvAGYAdAAgAEQAeQBuAGEAbQBpAGMAcwAgAE4AQQBWoRqA
# GGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTANBgkqhkiG9w0BAQEFAASCAQAm45NT
# HSN/lxY15ndNJbhPE3z6yUjPOxW/LrcHHY4EBjbm5+cLkzMHqxpLDdLu7Xxtm/S4
# 4U9V7gosRjGSiYY6La0aJXufDoVoP8NcuxLQV0Dfmi9XUfJJYmA8FIIYR+YpVnCq
# IGeefxXTrctFvdkOV4JxMXj4kqKnYa9aRTbPJZNoB+VGoMVCu92JUHmVVAe4GcF/
# W4lkrA7aogdY4Pst1dFgcW22tIQpOrmPhlNf83TCHIifgpxdBubjlXvzrwrikFHR
# zi1p+Nkmgtu/FsCuuUlKAe3mfrk5Dfpfqboq7jSgB9+ti9YgBJ2YKgYZrm48jHfI
# KVdyQJCKLUGTx8NSoYITSTCCE0UGCisGAQQBgjcDAwExghM1MIITMQYJKoZIhvcN
# AQcCoIITIjCCEx4CAQMxDzANBglghkgBZQMEAgEFADCCATwGCyqGSIb3DQEJEAEE
# oIIBKwSCAScwggEjAgEBBgorBgEEAYRZCgMBMDEwDQYJYIZIAWUDBAIBBQAEIDJW
# 1bbJbp9ZPwTbhapwHsMC6b1v9OEztsyvm54svhNCAgZZ2bpUs9kYEzIwMTcxMTIy
# MjA1NDMyLjc3NlowBwIBAYACAfSggbikgbUwgbIxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xDDAKBgNVBAsTA0FPQzEnMCUGA1UECxMebkNpcGhl
# ciBEU0UgRVNOOjBERTgtMkRDNS0zQ0E5MSUwIwYDVQQDExxNaWNyb3NvZnQgVGlt
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
# oAMCAQICEzMAAACm/VLgixYnPwAAAAAAAKYwDQYJKoZIhvcNAQELBQAwfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMTYwOTA3MTc1NjUxWhcNMTgwOTA3
# MTc1NjUxWjCBsjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEM
# MAoGA1UECxMDQU9DMScwJQYDVQQLEx5uQ2lwaGVyIERTRSBFU046MERFOC0yREM1
# LTNDQTkxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDBuM2eCSe0cIuF/x1aSNHA5udh
# cPU9qlRbwN3VssAQ665EmlyhiamvYcVT9AJs/b9sy9HzkpoSoBFthTc+cd3RoO+a
# Id3YWyaDkA8mf40eHuPjJBstMtG077fAzQpH2OBPNce7BDhFJmtvqOKFJrON9Pez
# vFnwIhiY/1c0GBtO0bTv2O4qiG39/h8VXSmBa3Y5MMX/fSOiRHQYswg0ybnI182M
# 71FN4PMP7zq0LdKzJfm/ZJMXVC/vyFFjlSWxLKNIcchnqnGH2NevyucbnaA5MsWm
# b2ob1Rh1lKmqeVms39uO0spJnHdBqtgwOWbkkXjU7Sfpl8N+WUT6LblqcQPdAgMB
# AAGjggEbMIIBFzAdBgNVHQ4EFgQUDuHFQ8kmG9zLh7vcTGbXBrzRwCYwHwYDVR0j
# BBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0
# cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljVGltU3Rh
# UENBXzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNUaW1TdGFQQ0Ff
# MjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcD
# CDANBgkqhkiG9w0BAQsFAAOCAQEAhCAnoQbouNb8kjrKSNady9CWjrME2siuhF+r
# OqL02rViVi8KwbKPPrcfLGBadSLOR5HfQXrZnpA0K6NYAw3DhsaW1bqF0eNjtBlR
# vWePNmXs1hkmlweM+laX/sxcGW13Bljp0QuvGqsLFPdPCVDDGWuYzCHjJYbWQTfr
# ZS3ZbGyPR/8XT72lUDajq8LcdXDhYVrvQRsqA9EGeV7KpkMYq1dEk4HA60KoEwXU
# GDicWyY23JXrM6W0cJr8vZ1vpAek3x5Cpw87uUGxtku/hBJF2W7PWHy242sLrgAG
# 1qSWu2cRLztQ6ZJs9ZpZyIfkr2S+VSwzcDYfi/Tq5pwBPaQ7L6GCA3cwggJfAgEB
# MIHioYG4pIG1MIGyMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MQwwCgYDVQQLEwNBT0MxJzAlBgNVBAsTHm5DaXBoZXIgRFNFIEVTTjowREU4LTJE
# QzUtM0NBOTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIl
# CgEBMAkGBSsOAwIaBQADFQB/oDBsfKPq6vKBBNM1oufc4tSFPaCBwTCBvqSBuzCB
# uDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEMMAoGA1UECxMD
# QU9DMScwJQYDVQQLEx5uQ2lwaGVyIE5UUyBFU046MjY2NS00QzNGLUM1REUxKzAp
# BgNVBAMTIk1pY3Jvc29mdCBUaW1lIFNvdXJjZSBNYXN0ZXIgQ2xvY2swDQYJKoZI
# hvcNAQEFBQACBQDdv8T+MCIYDzIwMTcxMTIyMDk0MjIyWhgPMjAxNzExMjMwOTQy
# MjJaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAN2/xP4CAQAwCgIBAAICLhECAf8w
# BwIBAAICGVEwCgIFAN3BFn4CAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGE
# WQoDAaAKMAgCAQACAxbjYKEKMAgCAQACAwehIDANBgkqhkiG9w0BAQUFAAOCAQEA
# LeUGUZ+Tfnc/B9kAbpXwPDn4Mo56jTbMr3P+QboNqjzdw0Vau/O7LhjUr0+a3lin
# qCoGlf0Mg435ihMGT2W2Gsdtni8vhOqOSZwmjrrox6zLl36dFdNUthiKtYhCL0yb
# G/m05bmZFx6m9Xk4nl01AeJ+E1tiNTC/ju2PbPL5TKoP4BB41oVSbJ/1LAWgfY5C
# 0SbYPWDDIgvGxxajEOdh/yEmDBZUxTCqT4Wgt0ODfGWl/4S+pDQfG9tQLBmm0CN0
# vaXUPSLGvG2RF4FwHauJ4ToNQX/hH8z5TfBVyS5zueYm4/q+Rg8V3eFoS2lT/mKZ
# JHpfjDacwvB7L8gCCekK1DGCAvUwggLxAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwAhMzAAAApv1S4IsWJz8AAAAAAACmMA0GCWCGSAFlAwQCAQUA
# oIIBMjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIE
# IAprXH65EIIa+spK6yrbcBXFJ+yf+OtTXiLQ4Dby+k+DMIHiBgsqhkiG9w0BCRAC
# DDGB0jCBzzCBzDCBsQQUf6AwbHyj6urygQTTNaLn3OLUhT0wgZgwgYCkfjB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAKb9UuCLFic/AAAAAAAApjAW
# BBTuEoSi+O9h6XJwkt43B26J3DokuTANBgkqhkiG9w0BAQsFAASCAQB8rplTclxM
# CuR/ReuLr9hFuPcQXFCm5c1ruqT6FTBXH/2/QOoWYuS2A1QNw0Vn/ljL+V5vaIJc
# 8Igo67f4Fxq6oTWrP+J8t/pVtTh9Av20Px8iE8zFIySWxptplvGK166oE9LtCVpF
# QVSIvwomNTyxY1TAaZMCugGrjgJPUyakoW7RlJgXmBLTnJKybNAAb+bQ/jCnOLhq
# 0yQygMLiYDKRccL8R4cuxuRja/BpuDM/VE3eJa+obBnmIlZNSaHZm37MT+b+/baJ
# nZRIbd+QlCpkdZ33EbC3i0TXcN507xofeFu8s9zDTXxC9TQPmtAhVASGQwAZJSeH
# t7y+U7RddU+e
# SIG # End signature block
