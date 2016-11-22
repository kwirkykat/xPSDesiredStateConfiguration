$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

#Import CommonResourceHelper for Test-IsNanoServer
$moduleRootFilePath = Split-Path -Path $PSScriptRoot -Parent
$dscResourcesFolderFilePath = Join-Path -Path $moduleRootFilePath -ChildPath 'DSCResources'
$commonResourceHelperFilePath = Join-Path -Path $dscResourcesFolderFilePath -ChildPath 'CommonResourceHelper.psm1'
Import-Module -Name $commonResourceHelperFilePath

<#
    .SYNOPSIS
        Determines if a Windows group exists.

    .PARAMETER GroupName
        The name of the group to test.
#>
function Test-GroupExists
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $GroupName
    )

    if (Test-IsNanoServer)
    {
        return Test-GroupExistsOnNanoServer @PSBoundParameters
    }
    else
    {
        return Test-GroupExistsOnFullSKU @PSBoundParameters
    }
}

<#
    .SYNOPSIS
        Determines if a Windows group exists on a full server.

    .PARAMETER GroupName
        The name of the group to test.
#>
function Test-GroupExistsOnFullSKU
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $GroupName
    )

    $adsiComputerEntry = [ADSI] "WinNT://$env:computerName"

    foreach ($adsiComputerEntryChild in $adsiComputerEntry.Children)
    {
        if ($adsiComputerEntryChild.Path -like "WinNT://*$env:computerName/$GroupName")
        {
            return $true
        }
    }

    return $false
}

<#
    .SYNOPSIS
        Determines if a Windows group exists on a Nano server

    .PARAMETER GroupName
        The name of the group to test.
#>
function Test-GroupExistsOnNanoServer
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $GroupName
    )

    try
    {
        $null = Get-LocalGroup -Name $GroupName -ErrorAction 'Stop'
    }
    catch [System.Exception]
    {
        if (-not $_.CategoryInfo.ToString().Contains('GroupNotFoundException'))
        {
            throw $_.Exception
        }

        return $false
    }

    return $true
}

<#
    .SYNOPSIS
        Creates a Windows group.

    .PARAMETER GroupName
        The name of the group.

    .PARAMETER Description
        The description of the group.

    .PARAMETER Members
        The usernames of the members to add to the group.
#>
function New-Group
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $GroupName,

        [Parameter()]
        [String]
        $Description,

        [Parameter()]
        [String[]]
        $Members
    )

    if (Test-IsNanoServer)
    {
        New-GroupOnNanoServer @PSBoundParameters
    }
    else
    {
        New-GroupOnFullSKU @PSBoundParameters
    }
}

<#
    .SYNOPSIS
        Creates a Windows group on a full server.

    .PARAMETER GroupName
        The name of the group.

    .PARAMETER Description
        The description of the group.

    .PARAMETER Members
        The usernames of the members to add to the group.
#>
function New-GroupOnFullSKU
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $GroupName,

        [Parameter()]
        [String]
        $Description,

        [Parameter()]
        [String[]]
        $Members
    )

    if (Test-GroupExists -GroupName $GroupName)
    {
        throw "Group $GroupName already exists."
    }

    $adsiComputerEntry = [ADSI] "WinNT://$env:computerName"
    $adsiGroupEntry = $adsiComputerEntry.Create('Group', $GroupName)

    if ($PSBoundParameters.ContainsKey('Description'))
    {
        $null = $adsiGroupEntry.Put('Description', $Description)
    }

    $null = $adsiGroupEntry.SetInfo()

    if ($PSBoundParameters.ContainsKey("Members"))
    {
        $adsiGroupEntry = [ADSI]"WinNT://$env:computerName/$GroupName,group"

        foreach ($memberUserName in $Members)
        {
            $null = $adsiGroupEntry.Add("WinNT://$env:computerName/$memberUserName")
        }
    }
}

<#
    .SYNOPSIS
        Creates a Windows group on a Nano server.

    .PARAMETER GroupName
        The name of the group.

    .PARAMETER Description
        The description of the group.

    .PARAMETER Members
        The usernames of the members to add to the group.
#>
function New-GroupOnNanoServer
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $GroupName,

        [Parameter()]
        [String]
        $Description,

        [Parameter()]
        [String[]]
        $Members
    )

    if (Test-GroupExists -GroupName $GroupName)
    {
        throw "Group $GroupName already exists."
    }

    $null = New-LocalGroup -Name $GroupName

    if ($PSBoundParameters.ContainsKey('Description'))
    {
        $null = Set-LocalGroup -Name $GroupName -Description $Description
    }

    if ($PSBoundParameters.ContainsKey('Members'))
    {
        $null = Add-LocalGroupMember -Name $GroupName -Member $Members
    }
}

<#
    .SYNOPSIS
        Deletes a Windows group.

    .PARAMETER GroupName
        The name of the group.
#>
function Remove-Group
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $GroupName
    )

    if (Test-IsNanoServer)
    {
        Remove-GroupOnNanoServer @PSBoundParameters
    }
    else
    {
        Remove-GroupOnFullSKU @PSBoundParameters
    }
}

<#
    .SYNOPSIS
        Deletes a Windows group on a full server.

    .PARAMETER GroupName
        The name of the group.
#>
function Remove-GroupOnFullSKU
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $GroupName
    )

    $adsiComputerEntry = [ADSI]"WinNT://$env:computerName"

    if (Test-GroupExists -GroupName $GroupName)
    {
        $null = $adsiComputerEntry.Delete('Group', $GroupName)
    }
    else
    {
        throw "Group $GroupName does not exist to remove."
    }
}

<#
    .SYNOPSIS
        Deletes a Windows group on a Nano server.

    .PARAMETER GroupName
        The name of the group.
#>
function Remove-GroupOnNanoServer
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $GroupName
    )

    if (Test-GroupExists -GroupName $GroupName)
    {
        Remove-LocalGroup -Name $GroupName
    }
    else
    {
        throw "Group $GroupName does not exist to remove."
    }
}

Export-ModuleMember -Function @( 'New-Group', 'Remove-Group', 'Test-GroupExists' )
