<#
    .SYNOPSIS
        Imports NAV IDE PowerShell module.
    .DESCRIPTION
        Imports NAV IDE PowerShell module.
    .PARAMETER FinSqlExeFile
        Specifies the path to the finsql.exe executable for the Microsoft Dynamics NAV development environment.
    .PARAMETER IDEModuleSuggestedPath
        Specifies a suggested directory where to find the Microsoft.Dynamics.Nav.Ide.psm1 module.
#>
function Import-NAVIdeModule
{
    [CmdletBinding()]
    param
        (
            [parameter(Mandatory=$false)]
            [string]$FinSqlExeFile = "",

            [parameter(Mandatory=$false)]
            [string]$IDEModuleSuggestedPath = ""
        )
    PROCESS
    {
        # By default, add the IDEModuleSuggestedPath to the list of possibilites where to load the Microsoft.Dynamics.Nav.Ide.psm1 module.
        if($IDEModuleSuggestedPath -and !$FinSqlExeFile)
        {
            Write-Error "For custom module load of Microsoft.Dynamics.Nav.Ide.psm1 from $IDEModuleSuggestedPath location, provide a non empty path to finsql.exe."
            return
        }

        if($IDEModuleSuggestedPath -and !(Test-Path $FinSqlExeFile))
        {
            Write-Error "For custom module load of Microsoft.Dynamics.Nav.Ide.psm1 from $IDEModuleSuggestedPath location, provide a valid path to finsql.exe. Currently: $FinSqlExeFile"
            return
        }

        # Try to import the IDE Module from the common installation path of the Microsoft Dynamics NAV 2016 Windows client.
        # We want to import the version specific to the current script.
        $CommonRTCInstallationPath = ""
        $registryKeyPath = ""
        if ([Environment]::Is64BitProcess)
        {
            $registryKeyPath = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Microsoft Dynamics NAV\110\RoleTailored Client'
        }
        else
        {
            $registryKeyPath = 'HKLM:\SOFTWARE\Microsoft\Microsoft Dynamics NAV\110\RoleTailored Client'
        }

        $registryKey = Get-ItemProperty -Path $registryKeyPath -ErrorAction SilentlyContinue
        if ($registryKey)
        {
            $CommonRTCInstallationPath = $registryKey.Path
        }

        # Try to import the IDE Module based on the registry information. We will import the module from the
        # current version of the installed Microsoft.Dynamics.Nav.Client.exe.
        # It might not be a Microsoft Dynamics NAV 2016 Windows client
        $registryKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Microsoft.Dynamics.Nav.Client.exe"
        $registryKey = Get-ItemProperty -Path $registryKeyPath -ErrorAction SilentlyContinue
        $CurrentVersionRTCPath = ""
        if ($registryKey)
        {
            $CurrentVersionRTCPath = $registryKey.Path
        }

        # Process the list with all possible module paths
        $allModulePaths = @($IDEModuleSuggestedPath, $CommonRTCInstallationPath, $CurrentVersionRTCPath)
        foreach($modulePath in $allModulePaths)
        {
            if($modulePath -and (Try-ImportIdeModuleFromPath -ModulePath $modulePath -FinSqlExe $FinSqlExeFile))
            {
                return
            }
        }

        Write-Error "The module Microsoft.Dynamics.Nav.Ide.psm1 was not found at the specified location: $allModulePaths"
    }
}

Export-ModuleMember -Function Import-NAVIdeModule

function Try-ImportIdeModuleFromPath
{
    param
    (
    [string]$modulePath,
    [string]$FinSqlExe
    )
    PROCESS
    {
        $modulePath = [System.Environment]::ExpandEnvironmentVariables($modulePath)
        $modulePath = Join-Path $modulePath "Microsoft.Dynamics.Nav.Ide.psm1" -ErrorAction SilentlyContinue

        Import-Module $modulePath -Global -Arg $FinSqlExeFile -ErrorVariable errorVariable -ErrorAction SilentlyContinue

        if (!$errorVariable)
        {
            Write-Verbose "The module was successfully imported from $ModulePath -Arg $FinSqlExe."
            return $true
        }

        return $false
    }
}


# SIG # Begin signature block
# MIIkBQYJKoZIhvcNAQcCoIIj9jCCI/ICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB5aoeQh7I/1Gte
# DYBeLbY02DnjMwd07ac1mrMi4X9+PqCCDYIwggYAMIID6KADAgECAhMzAAAAww6b
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIO5GSQ5j
# p8U76h5OIAM9OrR8NnLLYATeBokOZy4ox7d9MFwGCisGAQQBgjcCAQwxTjBMoC6A
# LABNAGkAYwByAG8AcwBvAGYAdAAgAEQAeQBuAGEAbQBpAGMAcwAgAE4AQQBWoRqA
# GGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTANBgkqhkiG9w0BAQEFAASCAQAHBqkr
# jfuWvYpqVHvNTU937JGDHieZsePVOjDHnUjLqMk6B/bxXIKEWjw/UfzUQep7XCHx
# C4VSkYDZUNkGDULtu8pJgxNm4p3J0K0Lw0qEbJO1T78gunMVgCIhkXm3W8PZ5i7Q
# E8MWIn2rrDLWFhPLo5XXr+rRC4iT9wfCEO6xAaajdOgxQPGpixG6t7H2Cz54fv1E
# BBc+C88bt2A1WHjrAhNaxLPQnkd3RuZ8u8JP9cxmr7xigtzFuSLEQLbZl3lPoSyr
# 5779cqml6uwLG7rw0XZMopSQjUfdO4OMwRE8N1CtkNujHsQ5OJwse9VaXXAMEDY9
# GyRfOEwlQd/lkJNMoYITSTCCE0UGCisGAQQBgjcDAwExghM1MIITMQYJKoZIhvcN
# AQcCoIITIjCCEx4CAQMxDzANBglghkgBZQMEAgEFADCCATwGCyqGSIb3DQEJEAEE
# oIIBKwSCAScwggEjAgEBBgorBgEEAYRZCgMBMDEwDQYJYIZIAWUDBAIBBQAEICLf
# Js59kkVyfW/M3DAIuyteGT6BU9w0MdHwkPJsEjHlAgZZ1oiZRfQYEzIwMTcxMTIy
# MjA1NDQxLjgwOFowBwIBAYACAfSggbikgbUwgbIxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xDDAKBgNVBAsTA0FPQzEnMCUGA1UECxMebkNpcGhl
# ciBEU0UgRVNOOjEyRTctMzA2NC02MTEyMSUwIwYDVQQDExxNaWNyb3NvZnQgVGlt
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
# oAMCAQICEzMAAACsiiG8etKbcvQAAAAAAKwwDQYJKoZIhvcNAQELBQAwfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMTYwOTA3MTc1NjU0WhcNMTgwOTA3
# MTc1NjU0WjCBsjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEM
# MAoGA1UECxMDQU9DMScwJQYDVQQLEx5uQ2lwaGVyIERTRSBFU046MTJFNy0zMDY0
# LTYxMTIxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQChxPQ8pY5zMaEXQVyrdwi3qdFD
# qrvf3HT5ujVWaoQJ2Km7+1T3GNnGpbND6PomAcw9NfV+C+RMmCrThpUlBVzeuzsN
# L2Lsj9mMdK83ixebazenSrA0rXLIifWBzKHVP6jzsQWo96cHukHZqI8xRp3tYivg
# apt5LLrn9Rm2Jn+E0h2lKDOw5sIteZiriOMPH2Z7mtgYXmyB8ThgdB46p6frNGpc
# Xr11pa1Vkldl0iY6oBAKQQSxJ5Bn4N7ui5Wj5wDkDZzGAg6n1ptMPTPJhL2uosW8
# 4YjnSp/2suNap3qOjKEYXmpGzvasq5qyqPyvfqfksOfNBaJntfpC8dIDJKrnAgMB
# AAGjggEbMIIBFzAdBgNVHQ4EFgQU2EdwqIU1ixNhr4eQ6EUXJOCYpw0wHwYDVR0j
# BBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0
# cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljVGltU3Rh
# UENBXzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNUaW1TdGFQQ0Ff
# MjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcD
# CDANBgkqhkiG9w0BAQsFAAOCAQEASOzoXifDGxicXbTOdm43DB9dYxwNXaQj0hW0
# ztBACeWbX6zxee1w7TJeXQx1IfTz1BWJAfVla7HA1oxa0LiF/Uf6rfRvEEmGmHr9
# wWEbr3xiErllTFE2V/mdYBSEwdj74m8QLBeFY37Cjx4TFe+AB/FQly3kvfrJKDaY
# YTTXTAFYAKpi0AcDTcESXZcshJ/O8UZs9fr0BgrOm5h7qeQ1CJNmDMVEqElQt/cF
# O3dxqrAKv3Fu/nsT5GkABu+vIibgxX6tNmqccIIXKALgv7zDIaRAAWtXV9Lwnmst
# DUbIp8dH/oSVm3tPnCPlrB3+C28vPnvJdbtJi/yOuETd+rLn+qGCA3cwggJfAgEB
# MIHioYG4pIG1MIGyMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MQwwCgYDVQQLEwNBT0MxJzAlBgNVBAsTHm5DaXBoZXIgRFNFIEVTTjoxMkU3LTMw
# NjQtNjExMjElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIl
# CgEBMAkGBSsOAwIaBQADFQA5cCWLFMh53V8MXemLnLOUmfcct6CBwTCBvqSBuzCB
# uDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEMMAoGA1UECxMD
# QU9DMScwJQYDVQQLEx5uQ2lwaGVyIE5UUyBFU046MjY2NS00QzNGLUM1REUxKzAp
# BgNVBAMTIk1pY3Jvc29mdCBUaW1lIFNvdXJjZSBNYXN0ZXIgQ2xvY2swDQYJKoZI
# hvcNAQEFBQACBQDdv8MPMCIYDzIwMTcxMTIyMDkzNDA3WhgPMjAxNzExMjMwOTM0
# MDdaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAN2/ww8CAQAwCgIBAAICGnsCAf8w
# BwIBAAICGdswCgIFAN3BFI8CAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGE
# WQoDAaAKMAgCAQACAxbjYKEKMAgCAQACAwehIDANBgkqhkiG9w0BAQUFAAOCAQEA
# A028pcLE/zMy1+FDYw5NkccCq+Pb5vSpiQ8Y2VTS7zjhMz/hYCTa7oJir2fzH9OQ
# NnXPpI8ZbTp4e8vbuu9oTaNiwW3NspuIXh1P9jJr7CshN6MXSo0yCMzMHdflmlHG
# zZCCXcSFMU41cku3wtXWa687Q5PJHuEDhbaCEDgi3zrI/ip/LFSk760NB54tSou5
# Ynngk5QLS5cMTKf3Y3oIK6mRJZ5vn27TjPsPMrDQEwjGfkRvn2pX1BCwh/lgcU4t
# xBKVN+KQkK++qAV+o87wLdcpgsGx/mgAi9ouXppULR6NZMwZVE/QBsU4x9pbFHN/
# cWA4B8yALBAAQIxx7HWXdjGCAvUwggLxAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwAhMzAAAArIohvHrSm3L0AAAAAACsMA0GCWCGSAFlAwQCAQUA
# oIIBMjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIE
# ICSXsdPg5FNkmo1+hG+ChMDZ1byxz5J9eeDm56znSyJpMIHiBgsqhkiG9w0BCRAC
# DDGB0jCBzzCBzDCBsQQUOXAlixTIed1fDF3pi5yzlJn3HLcwgZgwgYCkfjB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAKyKIbx60pty9AAAAAAArDAW
# BBTW96AfG2IjtbZRgwmI9nLh7xN4BzANBgkqhkiG9w0BAQsFAASCAQB1TEaL6hj3
# cgFlbUvyD5eEwLhyfUn9yryR4EQChR/r1ELfe1m8ETZ0Cel6u3qJ9W61665E+SJD
# iX58B+l1oLhD2JRH/MzjzJ4Wn7jxq/ZouCDmBjjAzZG6LrBaOusHQ5aUHjXe9Mwq
# SSJ28U+h/lp0DDwhYySM7WF+6t7N4aqginTPXgXo+fetdVX1rzLJWv26U5McBaZc
# sJtW/DZCvml1sw/PUXjJZvGI5y1ESWVzUqMhgcqglnm17Fse9GKhDyq3UO3vFw7D
# l5V6HSuuyjPmRH/qjE10m1cqptUlMPAu4hmPvLjpInCBc7CRlrrGl+ZPXUtkyPTF
# 3TXjaPrsqy1z
# SIG # End signature block
