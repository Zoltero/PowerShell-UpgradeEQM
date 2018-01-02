
function Remove-EQMRemoveComments
{
    [CmdletBinding()]
    param
        (
            [Parameter(Mandatory=$false)]
            [String]$WrkNavServerInstance,
    
            [Parameter(Mandatory=$false)]
            [String]$WorkingDirectory
        )
    BEGIN
    {
    }
    PROCESS
    {
        New-Item -Path $WorkingDirectory -Name 'Files' -ItemType "directory" -Force
        $WorkingDirectoryForEQMObjects = Join-Path $WorkingDirectory -ChildPath 'Files'

        $LocalExpPath = Join-Path -path $WorkingDirectoryForEQMObjects -ChildPath 'eqmobjects.txt'
        $LocalImpPath = Join-Path -path $WorkingDirectoryForEQMObjects -ChildPath 'eqmobjects_imp.txt'
        $WorkingFilestoDelete = Join-Path $WorkingDirectoryForEQMObjects -ChildPath '*.*'
        $versionFilter = 'Version List=*@EQM*'

        Write-Verbose "Removes Comments from the EQM Objects from $WrkNAVServerInstance"
  
        foreach ($num in 1,2,3,4,5) {
            switch ($num) 
            {
                1 { $tableFilter = 'Type=Table' }
                2 { $tableFilter = 'Type=Page' }
                3 { $tableFilter = 'Type=Report' }
                4 { $tableFilter = 'Type=Codeunit' }
                5 { $tableFilter = 'Type=Xmlport' }
            }
    
            $navFilter = $tableFilter + ';' + $versionFilter
    
            Write-Verbose " - Exporting EQM $tableFilter.."

            # Deletes existing files in the folder 
            remove-item $WorkingFilestoDelete

            Export-NAVApplicationObject2 `
                -ServerInstance $WrkNAVServerInstance `
                -Filter $navFilter `
                -Path $LocalExpPath `
                -LogPath $WorkingDirectory
    
            # Call the Codeunit to remove comments. it will create the file eqmobject_Imp.txt
            Write-Verbose " - Removes Comments in EQM $tableFilter.."
            Invoke-NAVCodeunit -ServerInstance $WrkNAVServerInstance -CodeunitId 85010 -MethodName "RunFromPowershell" -Argument $LocalExpPath
    
            Write-Verbose " - Importing EQM $tableFilter"
            Import-NAVApplicationObject2 `
                -Path $LocalImpPath `
                -ServerInstance $WrkNAVServerInstance `
                -LogPath $WorkingDirectory
        }
    }
}

Export-ModuleMember -Function Remove-EQMRemoveComments
