data LocalizedData
{
    # culture='en-US'
    # TODO: Support WhatIf
    ConvertFrom-StringData -StringData @'
InvalidIdentifyingNumber = The specified IdentifyingNumber ({0}) is not a valid Guid
InvalidPath = The specified Path ({0}) is not in a valid format. Valid formats are local paths, UNC, and HTTP
InvalidNameOrId = The specified Name ({0}) and IdentifyingNumber ({1}) do not match Name ({2}) and IdentifyingNumber ({3}) in the MSI file
NeedsMoreInfo = Either Name or ProductId is required
InvalidBinaryType = The specified Path ({0}) does not appear to specify an EXE or MSI file and as such is not supported
CouldNotOpenLog = The specified LogPath ({0}) could not be opened
CouldNotStartProcess = The process {0} could not be started
UnexpectedReturnCode = The return code {0} was not expected. Configuration is likely not correct
PathDoesNotExist = The given Path ({0}) could not be found
CouldNotOpenDestFile = Could not open the file {0} for writing
CouldNotGetHttpStream = Could not get the {0} stream for file {1}
ErrorCopyingDataToFile = Encountered error while writing the contents of {0} to {1}
PackageConfigurationComplete = Package configuration finished
PackageConfigurationStarting = Package configuration starting
InstalledPackage = Installed package
UninstalledPackage = Uninstalled package
NoChangeRequired = Package found in desired state, no action required
RemoveExistingLogFile = Remove existing log file
CreateLogFile = Create log file
MountSharePath = Mount share to get media
DownloadHTTPFile = Download the media over HTTP or HTTPS
StartingProcessMessage = Starting process {0} with arguments {1}
RemoveDownloadedFile = Remove the downloaded file
PackageInstalled = Package has been installed
PackageUninstalled = Package has been uninstalled
MachineRequiresReboot = The machine requires a reboot
PackageDoesNotAppearInstalled = The package {0} is not installed
PackageAppearsInstalled = The package {0} is installed
PostValidationError = Package from {0} was installed, but the specified ProductId and/or Name does not match package details
CheckingFileHash = Checking file '{0}' for expected {2} hash value of {1}
InvalidFileHash = File '{0}' does not match expected {2} hash value of {1}.
CheckingFileSignature = Checking file '{0}' for valid digital signature.
FileHasValidSignature = File '{0}' contains a valid digital signature. Signer Thumbprint: {1}, Subject: {2}
InvalidFileSignature = File '{0}' does not have a valid Authenticode signature.  Status: {1}
WrongSignerSubject = File '{0}' was not signed by expected signer subject '{1}'
WrongSignerThumbprint = File '{0}' was not signed by expected signer certificate thumbprint '{1}'
CreatingRegistryValue = Creating package registry value of {0}.
RemovingRegistryValue = Removing package registry value of {0}.
ValidateStandardArgumentsPathwasPath = Validate-StandardArguments, Path was {0}
TheurischemewasuriScheme = The uri scheme was {0}
ThepathextensionwaspathExt = The path extension was {0}
ParsingProductIdasanidentifyingNumber = Parsing {0} as an identifyingNumber
ParsedProductIdasidentifyingNumber = Parsed {0} as {1}
EnsureisEnsure = Ensure is {0}
productisproduct = product {0} found
productasbooleanis = product as boolean is {0}
Creatingcachelocation = Creating cache location
NeedtodownloadfilefromschemedestinationwillbedestName = Need to download file from {0}, destination will be {1}
Creatingthedestinationcachefile = Creating the destination cache file
Creatingtheschemestream = Creating the {0} stream
Settingdefaultcredential = Setting default credential
Settingauthenticationlevel = Setting authentication level
Ignoringbadcertificates = Ignoring bad certificates
Gettingtheschemeresponsestream = Getting the {0} response stream
ErrorOutString = Error: {0}
Copyingtheschemestreambytestothediskcache = Copying the {0} stream bytes to the disk cache
Redirectingpackagepathtocachefilelocation = Redirecting package path to cache file location
ThebinaryisanEXE = The binary is an EXE
Userhasrequestedloggingneedtoattacheventhandlerstotheprocess = User has requested logging, need to attach event handlers to the process
StartingwithstartInfoFileNamestartInfoArguments = Starting {0} with {1}
'@
}

# Commented-out until more languages are supported
# Import-LocalizedData -BindingVariable 'LocalizedData' -FileName 'MSFT_xPackageResource.strings.psd1'

Import-Module -Name "$PSScriptRoot\..\CommonResourceHelper.psm1" -Force

$script:packageCacheLocation = "$env:programData\Microsoft\Windows\PowerShell\Configuration\BuiltinProvCache\MSFT_xPackageResource"
$script:msiTools = $null

<#
    .SYNOPSIS
        Asserts that the path extension is valid.

    .PARAMETER Path
        The path to validate the extension of.
#>
function Assert-PathExtensionValid
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path
    )

    $pathExtension = [System.IO.Path]::GetExtension($Path)
    Write-Verbose -Message ($LocalizedData.ThePathExtensionWasPathExt -f $pathExtension)
    
    $validPathExtensions = @( '.msi', '.exe' )
    
    if ($validPathExtensions -notcontains $pathExtension.ToLower())
    {
        New-InvalidArgumentException -ArgumentName 'Path' -Message ($LocalizedData.InvalidBinaryType -f $Path)
    }
}

<#
    .SYNOPSIS
        Retrieves the product ID as an identifying number.

    .PARAMETER ProductId
        The product id to retrieve as an identifying number.
#>
function Convert-ProductIdToIdentifyingNumber
{
    [OutputType([String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ProductId
    )

    try
    {
        Write-Verbose -Message ($LocalizedData.ParsingProductIdAsAnIdentifyingNumber -f $ProductId)
        $identifyingNumber = "{{{0}}}" -f [Guid]::Parse($ProductId).ToString().ToUpper()
        
        Write-Verbose -Message ($LocalizedData.ParsedProductIdAsIdentifyingNumber -f $ProductId, $identifyingNumber)
        return $identifyingNumber
    }
    catch
    {
        New-InvalidArgumentException -ArgumentName 'ProductId' -Messsage ($LocalizedData.InvalidIdentifyingNumber -f $ProductId)
    }
}

<#
    .SYNOPSIS
        Converts the given path to a URI.
        Throws an exception if the path's scheme as a URI is not valid.

    .PARAMETER Path
        The path to retrieve as a URI.
#>
function Convert-PathToUri
{
    [OutputType([Uri])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path
    )

    try
    {
        $uri = [Uri] $Path
    }
    catch
    {
        New-InvalidArgumentException -ArgumentName 'Path' -Message ($LocalizedData.InvalidPath -f $Path)
    }

    $validUriSchemes = @( 'file', 'http', 'https' )

    if ($validUriSchemes -notcontains $uri.Scheme)
    {
        Write-Verbose -Message ($Localized.TheUriSchemeWasUriScheme -f $uri.Scheme)
        New-InvalidArgumentException -ArgumentName 'Path' -Message ($LocalizedData.InvalidPath -f $Path)
    }

    return $uri
}

<#
    .SYNOPSIS
        Retrieves the product entry for the package with the given name and/or identifying number.

    .PARAMETER Name
        The name of the product entry to retrieve.

    .PARAMETER IdentifyingNumber
        The identifying number of the product entry to retrieve.
#>
function Get-ProductEntry
{
    [CmdletBinding()]
    param
    (
        [String]
        $Name,

        [String]
        $IdentifyingNumber
    )

    $uninstallRegistryKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    $uninstallRegistryKeyWow64 = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

    $productEntry = $null

    if (-not [String]::IsNullOrEmpty($IdentifyingNumber))
    {
        $productEntryKeyLocation = Join-Path -Path $uninstallRegistryKey -ChildPath $IdentifyingNumber

        $productEntry = Get-Item -Path $productEntryKeyLocation -ErrorAction 'SilentlyContinue'
        
        if ($null -eq $productEntry)
        {
            $productEntryKeyLocation = Join-Path -Path $uninstallRegistryKeyWow64 -ChildPath $IdentifyingNumber
            $productEntry = Get-Item $productEntryKeyLocation -ErrorAction 'SilentlyContinue'
        }
    }
    else
    {
        foreach ($registryKeyEntry in (Get-ChildItem -Path @( $uninstallRegistryKey, $uninstallRegistryKeyWow64) -ErrorAction 'Ignore' ))
        {
            if ($Name -eq (Get-LocalizedRegistryKeyValue -RegistryKey $registryKeyEntry -ValueName 'DisplayName'))
            {
                $productEntry = $registryKeyEntry
                break
            }
        }
    }

    return $productEntry
}

function Test-TargetResource
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [ValidateSet('Present', 'Absent')]
        [String] 
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]
        $ProductId,

        [String]
        $Arguments,

        [PSCredential]
        $Credential,

        # Return codes 1641 and 3010 indicate success when a restart is requested per installation
        [ValidateNotNullOrEmpty()]
        [UInt32[]]
        $ReturnCode = @( 0, 1641, 3010 ),

        [String]
        $LogPath,

        [String]
        $FileHash,

        [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5', 'RIPEMD160')]
        [String]
        $HashAlgorithm,

        [String]
        $SignerSubject,

        [String]
        $SignerThumbprint,

        [String]
        $ServerCertificateValidationCallback
    )

    Assert-PathExtensionValid -Path $Path
    $uri = Convert-PathToUri -Path $Path

    if (-not [String]::IsNullOrEmpty($ProductId))
    {
        $identifyingNumber = Convert-ProductIdToIdentifyingNumber -ProductId $ProductId
    }

    $productEntry = Get-ProductEntry -Name $Name -IdentifyingNumber $identifyingNumber

    Write-Verbose -Message ($LocalizedData.EnsureIsEnsure -f $Ensure)

    if ($null -eq $productEntry)
    {
        Write-Verbose -Message ($LocalizedData.ProductIsProduct -f $productEntry)
    }
    else
    {
        Write-Verbose -Message 'Product installation cannot be determined'
    }

    Write-Verbose -Message ($LocalizedData.ProductAsBooleanIs -f [Boolean]$productEntry)

    if ($null -ne $productEntry)
    {
        $displayName = Get-LocalizedRegistryKeyValue -RegistryKey $productEntry -ValueName 'DisplayName'
        Write-Verbose -Message ($LocalizedData.PackageAppearsInstalled -f $displayName)
    }
    else
    {   
        $displayName = $null

        if (-not [String]::IsNullOrEmpty($Name))
        {
            $displayName = $Name
        }
        else
        {
            $displayName = $ProductId
        }
    
        Write-Verbose -Message ($LocalizedData.PackageDoesNotAppearInstalled -f $displayName)
    }

    return ($null -ne $productEntry -and $Ensure -eq 'Present') -or ($null -eq $productEntry -and $Ensure -eq 'Absent')
}

<#
    .SYNOPSIS
        Retrieves a localized registry key value.

    .PARAMETER RegistryKey
        The registry key to retrieve the value from.

    .PARAMETER ValueName
        The name of the value to retrieve.
#>
function Get-LocalizedRegistryKeyValue
{
    [CmdletBinding()]
    param
    (
        [Object]
        $RegistryKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ValueName
    )

    $localizedRegistryKeyValue = $RegistryKey.GetValue('{0}_Localized' -f $ValueName)
    
    if ($null -eq $localizedRegistryKeyValue)
    {
        $localizedRegistryKeyValue = $RegistryKey.GetValue($ValueName)
    }

    return $localizedRegistryKeyValue
}

function Get-TargetResource
{
    [OutputType([Hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]
        $ProductId        
    )

    Assert-PathExtensionValid -Path $Path
    $uri = Convert-PathToUri -Path $Path

    if (-not [String]::IsNullOrEmpty($ProductId))
    {
        $identifyingNumber = Convert-ProductIdToIdentifyingNumber -ProductId $ProductId
    }

    $productEntry = Get-ProductEntry -Name $Name -IdentifyingNumber $identifyingNumber

    if ($null -eq $productEntry)
    {
        return @{
            Ensure = 'Absent'
            Name = $Name
            ProductId = $identifyingNumber
            Installed = $false
        }
    }

    <#
        Identifying number can still be null here (e.g. remote MSI with Name specified, local EXE).
        If the user gave a product ID just pass it through, otherwise get it from the product.
    #>
    if ($null -eq $identifyingNumber)
    {
        $identifyingNumber = Split-Path -Path $productEntry.Name -Leaf 
    }

    $installDate = $productEntry.GetValue('InstallDate')
    
    if ($null -ne $installDate)
    {
        try
        {
            $installDate = '{0:d}' -f [DateTime]::ParseExact($installDate, 'yyyyMMdd',[System.Globalization.CultureInfo]::CurrentCulture).Date
        }
        catch
        {
            $installDate = $null
        }
    }

    $publisher = Get-LocalizedRegistryKeyValue -RegistryKey $productEntry -ValueName 'Publisher'
    
    $estimatedSize = $productEntry.GetValue('EstimatedSize')

    if ($null -ne $estimatedSize)
    {
        $estimatedSize = $estimatedSize / 1024
    }

    $displayVersion = $productEntry.GetValue('DisplayVersion')

    $comments = $productEntry.GetValue('Comments')

    $displayName = Get-LocalizedRegistryKeyValue -RegistryKey $productEntry -ValueName 'DisplayName'

    return @{
        Ensure = 'Present'
        Name = $displayName
        Path = $Path
        InstalledOn = $installDate
        ProductId = $identifyingNumber
        Size = $estimatedSize
        Installed = $true
        Version = $displayVersion
        PackageDescription = $comments
        Publisher = $publisher
    }
}

<#
    .SYNOPSIS
        Retrieves the MSI tools type.
#>
function Get-MsiTools
{
    [OutputType([System.Type])]
    [CmdletBinding()]
    param ()

    if ($null -ne $script:msiTools)
    {
        return $script:msiTools
    }

    $msiToolsCodeDefinition = @'
    [DllImport("msi.dll", CharSet = CharSet.Unicode, PreserveSig = true, SetLastError = true, ExactSpelling = true)]
    private static extern UInt32 MsiOpenPackageExW(string szPackagePath, int dwOptions, out IntPtr hProduct);

    [DllImport("msi.dll", CharSet = CharSet.Unicode, PreserveSig = true, SetLastError = true, ExactSpelling = true)]
    private static extern uint MsiCloseHandle(IntPtr hAny);

    [DllImport("msi.dll", CharSet = CharSet.Unicode, PreserveSig = true, SetLastError = true, ExactSpelling = true)]
    private static extern uint MsiGetPropertyW(IntPtr hAny, string name, StringBuilder buffer, ref int bufferLength);

    private static string GetPackageProperty(string msi, string property)
    {
        IntPtr MsiHandle = IntPtr.Zero;
        try
        {
            var res = MsiOpenPackageExW(msi, 1, out MsiHandle);
            if (res != 0)
            {
                return null;
            }

            int length = 256;
            var buffer = new StringBuilder(length);
            res = MsiGetPropertyW(MsiHandle, property, buffer, ref length);
            return buffer.ToString();
        }
        finally
        {
            if (MsiHandle != IntPtr.Zero)
            {
                MsiCloseHandle(MsiHandle);
            }
        }
    }
    public static string GetProductCode(string msi)
    {
        return GetPackageProperty(msi, "ProductCode");
    }

    public static string GetProductName(string msi)
    {
        return GetPackageProperty(msi, "ProductName");
    }
'@
    
    if (([System.Management.Automation.PSTypeName]'Microsoft.Windows.DesiredStateConfiguration.xPackageResource.MsiTools').Type)
    {
        $script:msiTools = ([System.Management.Automation.PSTypeName]'Microsoft.Windows.DesiredStateConfiguration.xPackageResource.MsiTools').Type
    }
    else
    {
        $script:msiTools = Add-Type `
            -Namespace 'Microsoft.Windows.DesiredStateConfiguration.xPackageResource' `
            -Name 'MsiTools' `
            -Using 'System.Text' `
            -MemberDefinition $msiToolsCodeDefinition `
            -PassThru
    }
    
    return $script:msiTools
}

<#
    .SYNOPSIS
        Retrieves the name of a product from an msi.

    .PARAMETER Path
        The path to the msi to retrieve the name from.
#>
function Get-MsiProductName
{
    [OutputType([String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path
    )

    $msiTools = Get-MsiTools

    $productName = $msiTools::GetProductName($Path)

    return $productName
}

<#
    .SYNOPSIS
        Retrieves the code of a product from an msi.

    .PARAMETER Path
        The path to the msi to retrieve the code from.
#>
function Get-MsiProductCode
{
    [OutputType([String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path
    )

    $msiTools = Get-MsiTools

    $productCode = $msiTools::GetProductCode($Path)

    return $productCode
}

function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [ValidateSet('Present', 'Absent')]
        [String] 
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]
        $ProductId,

        [String]
        $Arguments,

        [PSCredential]
        $Credential,

        # Return codes 1641 and 3010 indicate success when a restart is requested per installation
        [ValidateNotNullOrEmpty()]
        [UInt32[]]
        $ReturnCode = @( 0, 1641, 3010 ),

        [String]
        $LogPath,

        [String]
        $FileHash,

        [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5', 'RIPEMD160')]
        [String]
        $HashAlgorithm,

        [String]
        $SignerSubject,

        [String]
        $SignerThumbprint,

        [String]
        $ServerCertificateValidationCallback
    )

    $ErrorActionPreference = 'Stop'

    if (Test-TargetResource -Ensure $Ensure -Name $Name -Path $Path -ProductId $ProductId)
    {
        return
    }

    Assert-PathExtensionValid -Path $Path
    $uri = Convert-PathToUri -Path $Path

    if (-not [String]::IsNullOrEmpty($ProductId))
    {
        $identifyingNumber = Convert-ProductIdToIdentifyingNumber -ProductId $ProductId
    }

    $productEntry = Get-ProductEntry -Name $Name -IdentifyingNumber $identifyingNumber

    <#
        Path gets overwritten in the download code path. Retain the user's original Path in case
        the install succeeded but the named package wasn't present on the system afterward so we
        can give a better error message.
    #>
    $originalPath = $Path

    Write-Verbose -Message $LocalizedData.PackageConfigurationStarting

    $logStream = $null
    $psDrive = $null
    $downloadedFileName = $null

    try
    {
        $fileExtension = [System.IO.Path]::GetExtension($Path).ToLower()
        if (-not [String]::IsNullOrEmpty($LogPath))
        {
            try
            {
                if ($fileExtension -eq '.msi')
                {
                    <#
                        We want to pre-verify the log path exists and is writable ahead of time
                        even in the MSI case, as detecting WHY the MSI log path doesn't exist would
                        be rather problematic for the user.
                    #>
                    if ((Test-Path -Path $LogPath) -and $PSCmdlet.ShouldProcess($LocalizedData.RemoveExistingLogFile, $null, $null))
                    {
                        Remove-Item -Path $LogPath
                    }

                    if ($PSCmdlet.ShouldProcess($LocalizedData.CreateLogFile, $null, $null))
                    {
                        New-Item -Path $LogPath -Type 'File' | Out-Null
                    }
                }
                elseif ($PSCmdlet.ShouldProcess($LocalizedData.CreateLogFile, $null, $null))
                {
                    $logStream = New-Object -TypeName 'System.IO.StreamWriter' -ArgumentList @( $LogPath, $false )
                }
            }
            catch
            {
                New-InvalidOperationException -Message ($LocalizedData.CouldNotOpenLog -f $LogPath) -ErrorRecord $_
            }
        }

        # Download or mount file as necessary
        if (-not ($fileExtension -eq '.msi' -and $Ensure -eq 'Absent'))
        {
            if ($uri.IsUnc -and $PSCmdlet.ShouldProcess($LocalizedData.MountSharePath, $null, $null))
            {
                $psDriveArgs = @{
                    Name = [Guid]::NewGuid()
                    PSProvider = 'FileSystem'
                    Root = Split-Path -Path $uri.LocalPath
                }

                # If we pass a null for Credential, a dialog will pop up.
                if ($null -ne $Credential)
                {
                    $psDriveArgs['Credential'] = $Credential
                }

                $psDrive = New-PSDrive @psDriveArgs
                $Path = Join-Path -Path $psDrive.Root -ChildPath (Split-Path -Path $uri.LocalPath -Leaf)
            }
            elseif (@( 'http', 'https' ) -contains $uri.Scheme -and $Ensure -eq 'Present' -and $PSCmdlet.ShouldProcess($LocalizedData.DownloadHTTPFile, $null, $null))
            {
                $uriScheme = $uri.Scheme
                $outStream = $null
                $responseStream = $null

                try
                {
                    Write-Verbose -Message ($LocalizedData.CreatingCacheLocation)

                    if (-not (Test-Path -Path $script:packageCacheLocation -PathType 'Container'))
                    {
                        New-Item -Path $script:packageCacheLocation -ItemType 'Directory' | Out-Null
                    }

                    $destinationPath = Join-Path -Path $script:packageCacheLocation -ChildPath (Split-Path -Path $uri.LocalPath -Leaf)

                    Write-Verbose -Message ($LocalizedData.NeedtodownloadfilefromschemedestinationwillbedestName -f $uriScheme, $destinationPath)

                    try
                    {
                        Write-Verbose -Message ($LocalizedData.CreatingTheDestinationCacheFile)
                        $outStream = New-Object -TypeName 'System.IO.FileStream' -ArgumentList @( $destinationPath, 'Create' )
                    }
                    catch
                    {
                        # Should never happen since we own the cache directory
                        New-InvalidOperationException -Message ($LocalizedData.CouldNotOpenDestFile -f $destinationPath) -ErrorRecord $_
                    }

                    try
                    {
                        Write-Verbose -Message ($LocalizedData.CreatingTheSchemeStream -f $uriScheme)
                        $webRequest = [System.Net.WebRequest]::Create($uri)
                        
                        Write-Verbose -Message ($LocalizedData.SettingDefaultCredential)
                        $webRequest.Credentials = [System.Net.CredentialCache]::DefaultCredentials

                        if ($uriScheme -eq 'http')
                        {
                            # Default value is MutualAuthRequested, which applies to the https scheme
                            Write-Verbose -Message ($LocalizedData.SettingAuthenticationLevel)
                            $webRequest.AuthenticationLevel = [System.Net.Security.AuthenticationLevel]::None
                        }
                        elseif ($uriScheme -eq 'https' -and -not [String]::IsNullOrEmpty($ServerCertificateValidationCallback))
                        {
                            Write-Verbose -Message 'Assigning user-specified certificate verification callback'
                            $serverCertificateValidationScriptBlock = [ScriptBlock]::Create($ServerCertificateValidationCallback)
                            $webRequest.ServerCertificateValidationCallBack = $serverCertificateValidationScriptBlock
                        }

                        Write-Verbose -Message ($LocalizedData.Gettingtheschemeresponsestream -f $uriScheme)
                        $responseStream = (([System.Net.HttpWebRequest]$webRequest).GetResponse()).GetResponseStream()
                    }
                    catch
                    {
                         Write-Verbose -Message ($LocalizedData.ErrorOutString -f ($_ | Out-String))
                         New-InvalidOperationException -Message ($LocalizedData.CouldNotGetHttpStream -f $uriScheme, $Path) -ErrorRecord $_
                    }

                    try
                    {
                        Write-Verbose -Message ($LocalizedData.CopyingTheSchemeStreamBytesToTheDiskCache -f $uriScheme)
                        $responseStream.CopyTo($outStream)
                        $responseStream.Flush()
                        $outStream.Flush()
                    }
                    catch
                    {
                        New-InvalidOperationException -Message ($LocalizedData.ErrorCopyingDataToFile -f $Path, $destinationPath) -ErrorRecord $_
                    }
                }
                finally
                {
                    if ($null -ne $outStream)
                    {
                        $outStream.Close()
                    }

                    if ($null -ne $responseStream)
                    {
                        $responseStream.Close()
                    }
                }
                
                Write-Verbose -Message ($LocalizedData.RedirectingPackagePathToCacheFileLocation)
                $Path = $destinationPath
                $downloadedFileName = $destinationPath
            }

            # At this point the Path ought to be valid unless it's a MSI uninstall case
            if (-not (Test-Path -Path $Path -PathType 'Leaf'))
            {
                New-InvalidOperationException -Message ($LocalizedData.PathDoesNotExist -f $Path)
            }

            Assert-FileValid -Path $Path -HashAlgorithm $HashAlgorithm -FileHash $FileHash -SignerSubject $SignerSubject -SignerThumbprint $SignerThumbprint
        }

        $startInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo'

        # Necessary for I/O redirection and just generally a good idea
        $startInfo.UseShellExecute = $false

        $process = New-Object -TypeName 'System.Diagnostics.Process'
        $process.StartInfo = $startInfo

        # Concept only, will never touch disk
        $errorLogPath = $LogPath + ".err" 
        
        if ($fileExtension -eq '.msi')
        {
            $startInfo.FileName = "$env:winDir\system32\msiexec.exe"
            
            if ($Ensure -eq 'Present')
            {
                # Check if the MSI package specifies the ProductName and Code
                $productName = Get-MsiProductName -Path $Path
                $productCode = Get-MsiProductCode -Path $Path

                if ((-not [String]::IsNullOrEmpty($Name)) -and ($productName -ne $Name))
                {
                    New-InvalidArgumentException -ArgumentName 'Name' -Message ($LocalizedData.InvalidNameOrId -f $Name, $identifyingNumber, $productName, $productCode)
                }

                if ((-not [String]::IsNullOrEmpty($identifyingNumber)) -and ($identifyingNumber -ne $productCode))
                {
                    New-InvalidArgumentException -ArgumentName 'ProductId' -Message ($LocalizedData.InvalidNameOrId -f $Name, $identifyingNumber, $productName, $productCode)
                }

                $startInfo.Arguments = '/i "{0}"' -f $Path
            }
            else
            {
                $productEntry = Get-ProductEntry -Name $Name -IdentifyingNumber $identifyingNumber
                
                # We may have used the Name earlier, now we need the actual ID
                $id = Split-Path -Path $productEntry.Name -Leaf
                $startInfo.Arguments = '/x{0}' -f $id
            }

            if ($LogPath)
            {
                $startInfo.Arguments += ' /log "{0}"' -f $LogPath
            }

            $startInfo.Arguments += " /quiet"

            if ($Arguments)
            {
                $startInfo.Arguments += "$Arguments"
            }
        }
        else
        {
            # EXE
            Write-Verbose -Message $LocalizedData.TheBinaryIsAnExe

            if ($Ensure -eq 'Present')
            {
                $startInfo.FileName = $Path
                $startInfo.Arguments = $Arguments

                if ($LogPath)
                {
                    Write-Verbose -Message ($LocalizedData.UserHasRequestedLoggingNeedToAttachEventHandlersToTheProcess)
                    $startInfo.RedirectStandardError = $true
                    $startInfo.RedirectStandardOutput = $true

                    Register-ObjectEvent -InputObject $process -EventName 'OutputDataReceived' -SourceIdentifier $LogPath
                    Register-ObjectEvent -InputObject $process -EventName 'ErrorDataReceived' -SourceIdentifier $errorLogPath
                }
            }
            else
            {
                # Absent case
                $startInfo.FileName = "$env:winDir\system32\msiexec.exe"

                $id = Split-Path -Path $productEntry.Name -Leaf      
                $startInfo.Arguments = ('/x{0} /quiet' -f $id)

                # Never let msiexec restart automatically. DSC should handle reboot requests.
                $startInfo.Arguments += ' /norestart'
                
                if ($LogPath)
                {
                    $startInfo.Arguments += ' /log "{0}"' -f $LogPath
                }
                
                if ($Arguments)
                {
                    $startInfo.Arguments += "$Arguments"
                }
            }
        }

        Write-Verbose -Message ($LocalizedData.StartingWithStartInfoFileNameStartInfoArguments -f $startInfo.FileName, $startInfo.Arguments)

        if ($PSCmdlet.ShouldProcess(($LocalizedData.StartingProcessMessage -f $startInfo.FileName, $startInfo.Arguments), $null, $null))
        {
            try
            {
                $exitCode = 0

                $process.Start() | Out-Null

                # Identical to $fileExtension -eq '.exe' -and $logPath
                if ($logStream) 
                {
                    $process.BeginOutputReadLine()
                    $process.BeginErrorReadLine()
                }
          
                $process.WaitForExit()

                if ($process)
                {
                    $exitCode = $process.ExitCode
                }
            }
            catch
            {
                New-InvalidOperationException -Message ($LocalizedData.CouldNotStartProcess -f $Path) -ErrorRecord $_
            }


            if ($logStream)
            {
                #We have to re-mux these since they appear to us as different streams
                #The underlying Win32 APIs prevent this problem, as would constructing a script
                #on the fly and executing it, but the former is highly problematic from PowerShell
                #and the latter doesn't let us get the return code for UI-based EXEs
                $outputEvents = Get-Event -SourceIdentifier $LogPath
                $errorEvents = Get-Event -SourceIdentifier $errLogPath
                $masterEvents = @() + $outputEvents + $errorEvents
                $masterEvents = $masterEvents | Sort-Object -Property TimeGenerated

                foreach($event in $masterEvents)
                {
                    $logStream.Write($event.SourceEventArgs.Data);
                }

                Remove-Event -SourceIdentifier $LogPath
                Remove-Event -SourceIdentifier $errLogPath
            }

            if(-not ($ReturnCode -contains $exitCode))
            {
                New-InvalidOperationException ($LocalizedData.UnexpectedReturnCode -f $exitCode.ToString())
            }
        }
    }
    finally
    {
        if ($psDrive)
        {
            Remove-PSDrive -Name $psDrive -Force 
        }

        if ($logStream)
        {
            $logStream.Dispose()
        }
    }

    if ($downloadedFileName -and $PSCmdlet.ShouldProcess($LocalizedData.RemoveDownloadedFile, $null, $null))
    {
        <#
            This is deliberately not in the finally block because we want to leave the downloaded
            file on disk if an error occurred as a debugging aid for the user.
        #>
        Remove-Item -Path $downloadedFileName
    }

    $operationMessageString = $LocalizedData.PackageUninstalled
    if ($Ensure -eq 'Present')
    {
        $operationMessageString = $LocalizedData.PackageInstalled
    }

    <#
        Check if a reboot is required, if so notify CA. The MSFT_ServerManagerTasks provider is
        missing on some client SKUs (worked on both Server and Client Skus in Windows 10).
    #>

    $serverFeatureData = Invoke-CimMethod -Name 'GetServerFeature' -Namespace 'root\microsoft\windows\servermanager' -Class 'MSFT_ServerManagerTasks' -Arguments @{ BatchSize = 256 } -ErrorAction 'Ignore'
    $registryData = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction 'Ignore'

    if (($serverFeatureData -and $serverFeatureData.RequiresReboot) -or $registryData -or $exitcode -eq 3010 -or $exitcode -eq 1641)
    {
        Write-Verbose $LocalizedData.MachineRequiresReboot
        $global:DSCMachineStatus = 1
    }
    
    if ($Ensure -eq 'Present')
    {
        $productEntry = Get-ProductEntry -Name $Name -IdentifyingNumber $identifyingNumber

        if (-not $productEntry)
        {
            New-InvalidOperationException -Message ($LocalizedData.PostValidationError -f $originalPath)
        }
    }

    Write-Verbose -Message $operationMessageString
    Write-Verbose -Message $LocalizedData.PackageConfigurationComplete
}

<#
    .SYNOPSIS
        Asserts that the file at the given path is valid.

    .PARAMETER Path
        The path to the file to check.

    .PARAMETER FileHash
        The hash that should match the hash of the file.

    .PARAMETER HashAlgorithm
        The algorithm to use to retrieve the file hash.

    .PARAMETER SignerThumbprint
        The certificate thumbprint that should match the file's signer certificate.

    .PARAMETER SignerSubject
        The certificate subject that should match the file's signer certificate.
#>
function Assert-FileValid
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Path,

        [String]
        $FileHash,

        [String]
        $HashAlgorithm,

        [String]
        $SignerThumbprint,

        [String]
        $SignerSubject
    )

    if (-not [String]::IsNullOrEmpty($FileHash))
    {
        Assert-FileHashValid -Path $Path -Hash $FileHash -Algorithm $HashAlgorithm
    }

    if (-not [String]::IsNullOrEmpty($SignerThumbprint) -or -not [String]::IsNullOrEmpty($SignerSubject))
    {
        Assert-FileSignatureValid -Path $Path -Thumbprint $SignerThumbprint -Subject $SignerSubject
    }
}

<#
    .SYNOPSIS
        Asserts that the hash of the file at the given path matches the given hash.

    .PARAMETER Path
        The path to the file to check the hash of.

    .PARAMETER Hash
        The hash to check against.

    .PARAMETER Algorithm
        The algorithm to use to retrieve the file's hash.
#>
function Assert-FileHashValid
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Path,

        [Parameter(Mandatory)]
        [String]
        $Hash,

        [String]
        $Algorithm = 'SHA256'
    )

    if ([String]::IsNullOrEmpty($Algorithm))
    {
        $Algorithm = 'SHA256'
    }

    Write-Verbose -Message ($LocalizedData.CheckingFileHash -f $Path, $Hash, $Algorithm)

    $fileHash = Get-FileHash -LiteralPath $Path -Algorithm $Algorithm -ErrorAction 'Stop'

    if ($fileHash.Hash -ne $Hash)
    {
        throw ($LocalizedData.InvalidFileHash -f $Path, $Hash, $Algorithm)
    }
}

<#
    .SYNOPSIS
        Asserts that the signature of the file at the given path is valid.

    .PARAMETER Path
        The path to the file to check the signature of

    .PARAMETER Thumbprint
        The certificate thumbprint that should match the file's signer certificate.

    .PARAMETER Subject
        The certificate subject that should match the file's signer certificate.
#>
function Assert-FileSignatureValid
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Path,

        [String]
        $Thumbprint,

        [String]
        $Subject
    )

    Write-Verbose -Message ($LocalizedData.CheckingFileSignature -f $Path)

    $signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction 'Stop'

    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid)
    {
        throw ($LocalizedData.InvalidFileSignature -f $Path, $signature.Status)
    }
    else
    {
        Write-Verbose -Message ($LocalizedData.FileHasValidSignature -f $Path, $signature.SignerCertificate.Thumbprint, $signature.SignerCertificate.Subject)
    }

    if ($null -ne $Subject -and ($signature.SignerCertificate.Subject -notlike $Subject))
    {
        throw ($LocalizedData.WrongSignerSubject -f $Path, $Subject)
    }

    if ($null -ne $Thumbprint -and ($signature.SignerCertificate.Thumbprint -ne $Thumbprint))
    {
        throw ($LocalizedData.WrongSignerThumbprint -f $Path, $Thumbprint)
    }
}

Export-ModuleMember -Function *-TargetResource
