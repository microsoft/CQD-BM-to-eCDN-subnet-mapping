<#
.SYNOPSIS
    Convert a CQD building mapping file to a subnet mapping format.
.DESCRIPTION
    Script to convert a CQD building mapping file to an eCDN subnet mapping format.
    The building mapping file must contain all the following columns even if they are empty:
        NetworkIP            # ! REQUIRED
        NetworkName          # ! REQUIRED
        NtworkRange          # ! REQUIRED
        BuildingName         # ! REQUIRED
        OwnershipType        # Optional
        BuildingType         # Optional
        BuildingOfficeType   # Optional
        City                 # Recommended
        ZipCode              # Recommended
        Country              # Recommended
        State                # Recommended
        Region               # Recommended
        InsideCorp           # ! REQUIRED
        ExpressRoute         # ! REQUIRED
        VPN                  # Optional

    The eCDN subnet mapping output will be formatted with the following properties or "columns":
        GroupId
        Subnets
        P2P
        WAN
        Label
        Country
        City

    Without OutFilePath, the script will output the eCDN subnet mapping format to the console. 
    Provide an OutFilePath to save the converted data to a CSV file.
.PARAMETER BMFilePath
    The path to the CQD building mapping file.
.PARAMETER OutFilePath
    The path to the output file. (Will be a csv file)
.PARAMETER Delimiter
    The delimiter used in the building mapping file. (Default: will be auto-detected)
.PARAMETER CountryCodesMapping
    Provide a hashtable mapping country names to their corresponding two-letter ISO country codes. (Optional)
    Note that Microsoft eCDN expects two-letter ISO country codes in the Country column.
.PARAMETER RemoveEmpties
    Remove rows where the GroupId is empty.
.PARAMETER RemoveIPv6
    Remove rows where the Subnets column contains IPv6 addresses.
.EXAMPLE
    .\Convert-BuildingMappingToEcdnSubnetMapping.ps1 -BMFilePath .\building-mapping.tsv
    This example will output to console, a convertion the building mapping file to an eCDN subnet mapping format.
.EXAMPLE
    .\Convert-BuildingMappingToEcdnSubnetMapping.ps1 -BMFilePath .\building-mapping.tsv -OutFilePath .\subnet-mapping.csv
    This example will save the converted data to a CSV file.
.OUTPUTS
    An array of eCDN subnet mapping objects containing the following properties:
        GroupId
        Subnets
        P2P
        WAN
        Label
        Country
        City
    
    The output can be saved to a CSV file using the below command.
    .\Convert-BuildingMappingToEcdnSubnetMapping.ps1 -BMFilePath .\building-mapping.tsv | Export-Csv -Path .\subnet-mapping.csv -NoTypeInformation

    Caution: If the source data contains quotation marks ("), this method will produce an invalid CSV file.
    To avoid this, use the OutFilePath parameter to save the output to a CSV file.
.NOTES
    There are three expectations of the building mapping file.
    1. Not having a header row. (optional)
    2. The following columns must not be empty:
        NetworkIP,NetworkName,NtworkRange,BuildingName,InsideCorp,ExpressRoute
    3. Having the required columns in the correct positions. (optional if header row is included)
        NetworkIP,NetworkName,NtworkRange,BuildingName,OwnershipType,BuildingType,BuildingOfficeType,City,ZipCode,Country,State,Region,InsideCorp,ExpressRoute,VPN

    Author: Diego Reategui
    Alias: v-dreategui

    Copyright (c) Microsoft Corporation.
    Licensed under the MIT License.
#>
[cmdletbinding()]
param(
    [Parameter(Mandatory=$true,Position=0)]
    [ValidatePattern(".*\.(csv|tsv|psv|ssv)")]
    [string]
    $BMFilePath,
    [Parameter(Mandatory=$false,Position=1)]
    [string]
    $OutFilePath,
    [ValidateSet(',', "`t", ';', ':', '|')]
    [string]
    $Delimiter,
    [hashtable]
    $CountryCodesMapping,
    [switch]
    $RemoveEmpties,
    [switch]
    $RemoveIPv6
)

if (-not (Test-Path $BMFilePath)) {
    Write-Error "File not found: $BMFilePath"
    return
}

if ($OutFilePath -and !(Test-Path $OutFilePath -IsValid)) {
    Write-Error "Invalid out file path: $OutFilePath"
    return
}

function Detect-Delimiter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $delimiterNames = @{
        "," = "comma"
        "`t" = "tab"
        "|" = "pipe"
        ";" = "semicolon"
        ":" = "colon"
    }

    # Read the first line of the file
    $firstLine = Get-Content $FilePath -TotalCount 1

    # Count the number of occurrences of each possible delimiter
    $commaCount     = ($firstLine -split ",").Count - 1
    $tabCount       = ($firstLine -split "`t").Count - 1
    $pipeCount      = ($firstLine -split "\|").Count - 1
    $semicolonCount = ($firstLine -split ";").Count - 1
    $colonCount     = ($firstLine -split ":").Count - 1

    # Choose the delimiter with the highest count
    $delimiterCounts = @{
        "," = $commaCount
        "`t" = $tabCount
        "|" = $pipeCount
        ";" = $semicolonCount
        ":" = $colonCount
    }
    $mostCommonDelimiter = ($delimiterCounts.GetEnumerator() | Sort-Object Value -Descending)[0].Key

    Write-Verbose "The detected delimiter is a $($delimiterNames[$mostCommonDelimiter])"

    # Output the chosen delimiter
    return $mostCommonDelimiter
}

if (-not $Delimiter) {
    $Delimiter = Detect-Delimiter -FilePath $BMFilePath
}

$headers =  "NetworkIP",            # ! REQUIRED
            "NetworkName",          # ! REQUIRED
            "NtworkRange",          # ! REQUIRED
            "BuildingName",         # ! REQUIRED
            "OwnershipType",        # Optional
            "BuildingType",         # Optional
            "BuildingOfficeType",   # Optional
            "City",                 # Recommended
            "ZipCode",              # Recommended
            "Country",              # Recommended
            "State",                # Recommended
            "Region",               # Recommended
            "InsideCorp",           # ! REQUIRED
            "ExpressRoute",         # ! REQUIRED
            "VPN"                   # Optional

# Replacing '\"' with '\""' so PS's conversion doesn't strip away some quotes.
$raw = (Get-Content $BMFilePath) -replace '\\"', '\""'

# First trying to import normally in case headers are already included in the file.
try   { $building_mapping_data = ConvertFrom-Csv $raw -Delimiter $Delimiter -WarningAction Suspend -ErrorAction Stop }
catch { Write-Verbose "Not importing without headers. Because: $($_.Exception.Message)" }

# If that didn't work, we'll assume the building mapping file is formatted correctly (without the header row) and try again.
if (-not $building_mapping_data) {
    try   { $building_mapping_data = ConvertFrom-Csv $raw -Delimiter $Delimiter -Header $headers -ErrorAction Stop }
    catch { Write-Error "Failed to import file: $BMFilePath"
            return
    }
}

# Check for required columns
$requiredProperties = $headers[0..3] + $headers[12..13]
$objectProperties = $building_mapping_data | Get-Member -MemberType NoteProperty,Property | Select-Object -ExpandProperty Name
$missingProperties = $requiredProperties | Where-Object {$_ -notin $objectProperties}
if ($missingProperties) {
    $missingProperties = "`nMissing required properties:  $($missingProperties -join ', ')"
    Write-Error $missingProperties
    return
}

$stringTrueValues = @("true","yes","on","1")

$outputProperties = @(
    @{label='GroupId' ; expression={$_.NetworkName}},
    @{label='Subnets' ; expression={$_.NetworkIP + '/' + $_.NtworkRange}},
    @{label='P2P'     ; expression={if ($_.VPN -in $stringTrueValues) {"p2p-off"} else {"p2p-on"}}},
    @{label='WAN'     ; expression={"wan-off"}},
    @{label='Label'   ; expression={$_.BuildingName}},
    @{label='Country' ; expression={if ($CountryCodesMapping[$_.Country]) {$CountryCodesMapping[$_.Country]} else {$_.Country}}},
    @{label='City'    ; expression={$_.City}}
)

$subnet_mapping = $building_mapping_data | Select-Object $outputProperties

# Removing rows with invalid data
if ($RemoveEmpties) {
    $subnet_mapping = $subnet_mapping.Where({$_.GroupId})
}
else {
    if ($subnet_mapping.Where({!$_.GroupId})) {
        Write-Warning "There are rows with empty GroupId values. Use the RemoveEmpties switch to remove these rows."
    }
}

if ($RemoveIPv6) {
    $subnet_mapping = $subnet_mapping.Where({$_.Subnets -notmatch "\d*:"})
}
else {
    if ($subnet_mapping.Where({$_.Subnets -notmatch "\d*:"})) {
        Write-Warning "There are rows with IPv6 addresses in the Subnets column. Use the RemoveIPv6 switch to remove these rows."
    }
}

if ($subnet_mapping.Where({$_.Country.Length -ne 2})) {
    Write-Warning "There are rows with invalid Country values. Use the CountryCodesMapping parameter to provide a hashmap of map country names to their corresponding two-letter ISO country codes."
}

if (-not $OutFilePath) {
    return $subnet_mapping
}

if ($OutFilePath -notmatch "\.csv$") {
    $OutFilePath += ".csv"
}

# Getting around PowerShell's issues converting to CSV with quotes.
$csv_data = $subnet_mapping | ConvertTo-Csv -NoTypeInformation -ErrorAction Stop
Set-Content -Value ($csv_data -replace '\\""', '\"') -Path $OutFilePath