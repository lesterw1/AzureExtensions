#Requires -Version 5
<#
.SYNOPSIS
	Ax.Cosmos TEST
.DESCRIPTION
	PowerShell cmdlets which perform selected CosmosDB actions
	(at least until Microsoft releases an official set of cmdlets).
	
	This module follows the Azure Storage module in that a context must first be
	configured for access and then subsequently used thereafter.
	
.PARAMETER

.EXAMPLE

	
.NOTES
	Author: Lester Waters
	Version: v0.05a
	Date: 07-Mar-20
	
	IMPORTANT:
		(1) CosmosDB Property names are CaSe SeNsItIvE!
		(2) CosmosDB makes use of the fixed property name ('id') in lower case for unique key.
		(3) The Azure ARM portal barfs on slashes in the ID; but the REST API does not
		    The following characters are restricted and cannot be used in the id property: '/', '\\', '?', '#'
			https://docs.microsoft.com/en-us/dotnet/api/microsoft.azure.documents.resource.id?view=azure-dotnet
			
.LINK
	https://docs.microsoft.com/en-us/dotnet/api/microsoft.azure.documents.resource.id?view=azure-dotnet
	The following characters are restricted and cannot be used in the Id property: '/', '\\', '?', '#'	
	
	http://www.jbmurphy.com/2019/02/28/add-a-document-to-cosmosdb-via-the-rest-api-using-powershell/
	https://www.systemcenterautomation.com/2018/06/cosmos-db-rest-api-powershell/
#>


# +=================================================================================================+
# |  MODULES	              																		|
# +=================================================================================================+
Import-Module Az.Resources
Add-Type -AssemblyName System.Web


# +=================================================================================================+
# |  TEST CONSTANTS 																				|
# +=================================================================================================+
$Test_Location				= 'West Europe'	
$Test_ResourceGroupName		= 'rg-CosmosDB'
$Test_AccountName			= 'axcosmostest1'			# Must be globally unique name and lower case  **CUSTOMIZE ME**
$Test_databaseName 			= "database1"
$Test_partitionKeyName		= "_partitionKey"					# Name of property that we will use for consistent partition key names
$Test_CollectionName 		= "TestContainer"

# 
# CosmosDb resource names as used through the New-AzResource, Get-AzResource, etc. 
# These are DIFFERENT from the paths used in the REST API!
$resourceName 			= $CosmosDbAccountName + '/sql/' + $databaseName
$containerResourceName 	= $CosmosDbAccountName + '/sql/' + $databaseName + "/" + $containerName

#
# CosmosDB Properties (posted through the New-AzResource cmdlet)
#
$locations = @(
    @{ "locationName"=$Location; "failoverPriority"=0 }
)

$consistencyPolicy = @{
    "defaultConsistencyLevel"="BoundedStaleness";
    "maxIntervalInSeconds"=300;
    "maxStalenessPrefix"=100000
}

$CosmosDBProperties = @{
    "databaseAccountOfferType"="Standard";
    "locations"=$locations;
    "consistencyPolicy"=$consistencyPolicy;
    "enableMultipleWriteLocations"="false"
}

$DataBaseProperties = @{
    "resource"=@{"id"=$databaseName}
}

$ContainerProperties = @{
    "resource"=@{
        "id"=$containerName;
        "partitionKey"=@{
            "paths"=@("/$partitionKeyName");
            "kind"="Hash";
			"Version"=2
        }
    };
    "options"=@{ "Throughput"="400" }
}


# +=================================================================================================+
# |  CLASSES																						|
# +=================================================================================================+

Class AxCosmosContext
{
	[string]									$accountName			# CosmosDB Account Name
	[string]									$resourceGroupName		# Azure Resource Group Name
	[string]									$subscriptionId			# subscriptionId
	[string]									$location				# Azure location
    [string]									$databaseName			# database name
	[string]									$collectionName			# optional collection / container named
	[string]									$partitionKeyName		# optional partitionKey name
	[string]									$AzDabatasePath			# Resource names through the New-AzResource, etc. 
	[string]									$AzContainerPath		# Resource names through the New-AzResource, etc. 
	hidden [string]								$key					# Key (DEBUG temporary only)
	[string]									$keyType = "master"		# "master" or "resource"
	[string]									$tokenVersion = "1.0"	# Signature Version
	[System.Security.Cryptography.HMACSHA256]	$hmacSHA256 = [System.Security.Cryptography.HMACSHA256]::new()	# HMAC Context based on key
	[string]									$endPoint				# HTTPS endpoint (based on $accountName)
	[string]									$collectionURI			# Full URI to collection, excluding trailing slash
	[string]									$ApiVersion
}

Class AxCosmosDatabase
{
	[string]	$Name              		# Database Name
	[string]	$ResourceGroupName 		# Azure Resource Group Name
	[string]	$ResourceType			# Azure Resource Type: Microsoft.DocumentDb/databaseAccounts/apis/databases
	[string]	$Location				# Azure Location
	[string]	$ResourceId				# Azure Resource ID
	[PSObject]	$Properties				# Propertioes as returned in Rest API
}

Class AxCosmosDatabaseCollection
{
	[string]	$Name              		# Collection Name
	[string]	$ResourceGroupName 		# Azure Resource Group Name
	[string]	$ResourceType			# Azure Resource Type: Microsoft.DocumentDb/databaseAccounts/apis/databases/containers
	[string]	$Location				# Azure Location
	[string]	$ResourceId				# Azure Resource ID
	[PSObject]	$Properties				# Properties as returned in Rest API
	[string]	$PartitionKeyName		# Partition Key Name
}


# +=================================================================================================+
# |  FUNCTIONS																						|
# +=================================================================================================+


# +---------------------------------------------+
# |  Test-Debug									|
# +---------------------------------------------+
Function Test-Debug {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$IgnorePSBoundParameters
        ,
        [Parameter(Mandatory = $false)]
        [switch]$IgnoreDebugPreference
        ,
        [Parameter(Mandatory = $false)]
        [switch]$IgnorePSDebugContext
    )
    process {
        ((-not $IgnoreDebugPreference.IsPresent) -and ($DebugPreference -ne 'SilentlyContinue')) -or
        ((-not $IgnorePSBoundParameters.IsPresent) -and $PSBoundParameters.Debug.IsPresent) -or
        ((-not $IgnorePSDebugContext.IsPresent) -and ($PSDebugContext))
    }
}


# +---------------------------------------------+
# |  Get-AxCosmosAuthSignature					|
# +---------------------------------------------+
# https://docs.microsoft.com/en-gb/rest/api/cosmos-db/access-control-on-cosmosdb-resources
Function Get-AxCosmosAuthSignature {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][String]	$verb,					# HTTP verb, such as GET, POST, or PUT
        [Parameter(Mandatory=$true)][String]	$resourceLink,			# Case SeNsItIvE!!! (this is the parent path for the $resourceType)
        [Parameter(Mandatory=$true)][String]	$resourceType,			# type of resource that the request is for, Eg. "dbs", "colls", "docs"
        [Parameter(Mandatory=$true)][String]	$dateTime,				# Must exactly match x-ms-date in header (and be lower case)
        [Parameter(Mandatory=$true)][String]	$key,					#
        [Parameter(Mandatory=$true)][String]	$keyType,				# "master" or "resource"
        [Parameter(Mandatory=$false)][String]	$tokenVersion = "1.0"	# 
    )
    $hmacSha256 = New-Object System.Security.Cryptography.HMACSHA256
    $hmacSha256.Key = [System.Convert]::FromBase64String($key)
 
    If ($resourceLink -eq $resourceType)
		{ $resourceLink = "" }
 
    $payLoad = "$($verb.ToLowerInvariant())`n$($resourceType.ToLowerInvariant())`n$resourceLink`n$($dateTime.ToLowerInvariant())`n`n"   # WAS: ($dateTime.ToLowerInvariant())
	# write-host -ForegroundColor Cyan "---- Payload ----`n$payload-----------------"  # DEBUG
    $hashPayLoad = $hmacSha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($payLoad))
    $signature = [System.Convert]::ToBase64String($hashPayLoad)
 
	[System.Web.HttpUtility]::UrlEncode("type=$keyType&ver=$tokenVersion&sig=$signature")
}



# +---------------------------------------------+
# |  New-AxCosmosContext						|
# +---------------------------------------------+
# TEST: $c = New-AxCosmosContext -AccountName $Test_AccountName -ResourceGroupName $Test_ResourceGroupName -DatabaseName $Test_DatabaseName -CollectionName $Test_CollectionName -Verbose
Function New-AxCosmosContext {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][String]	$AccountName,		# CosmosDB Account Name
		[Parameter(Mandatory=$true)][String]	$ResourceGroupName,	# Azure Resource Group
        [Parameter(Mandatory=$false)][String]	$DatabaseName,		# Database name
        [Parameter(Mandatory=$false)][String]	$MasterKey,			# Master key for account
		[Parameter(Mandatory=$false)][String]	$CollectionName		# Collection (container) Name
    )
	
	$EndPoint 		= "https://" + $AccountName + ".documents.azure.com"
    $ResourceLink 	= "dbs/$DatabaseName/colls/$CollectionName"
    $ResourceType 	= "docs"										# Not used here (for reference only)
    $queryUri 		= "$EndPoint/$ResourceLink/$ResourceType"		# Not used here (for reference only)
	
	# Verify that resource exists
	$r = Get-AzResource -ResourceType 'Microsoft.DocumentDb/databaseAccounts' `
		-ApiVersion '2020-01-01' -ResourceGroupName $resourceGroupName -ErrorAction Stop
	if (!$r)
	{
		write-error "Resource Not found"
		return $null
	}

	# Retrieve Master Key if it was not specified...
	if (!$MasterKey)
	{
		write-verbose "Retrieving CosmosDB master keys..."
		$keys = Invoke-AzResourceAction -Action listKeys -Force `
			-ResourceType "Microsoft.DocumentDb/databaseAccounts" -ApiVersion "2015-04-08" `
			-ResourceGroupName $ResourceGroupName -Name $AccountName
		$MasterKey = $keys.primaryMasterKey
		if (!$MasterKey)
		{
			write-warning "Unable to retreive keys from CosmosDB account '$CosmosDbAccountName'`nVerify that it exists and that you have access.`nAlso check your currently selected subscription."
			return $null
		}
	}
	
    $NewCosmosContext					= New-Object AxCosmosContext
	$NewCosmosContext.ApiVersion		= "2018-06-18"  # was "2015-12-16"  # SEE: https://docs.microsoft.com/en-us/rest/api/cosmos-db/index
    $NewCosmosContext.hmacSHA256.Key	= [System.Convert]::FromBase64String($MasterKey)
	$NewCosmosContext.accountName		= $AccountName.ToLower()
	$NewCosmosContext.resourceGroupName	= $ResourceGroupName
	$NewCosmosContext.subscriptionId	= (Get-AzContext).Subscription.Id
	$NewCosmosContext.key				= $MasterKey
	$NewCosmosContext.endPoint 			= $EndPoint
	if ($DatabaseName.Length -gt 0 -And $CollectionName.Length -gt 0)
		{ $NewCosmosContext.collectionURI		= "$EndPoint/$ResourceLink" }

	# CosmosDb resource names as used through the New-AzResource, Get-AzResource, etc. 
	# These are DIFFERENT from the paths used in the REST API!
	if ($DatabaseName.Length -gt 0)
	{
		# Save the database details
		$NewCosmosContext.databaseName		= $DatabaseName
		$NewCosmosContext.AzDabatasePath 	= $AccountName + '/sql/' + $DatabaseName
		
		# See if collection exists and retrieve the partition key name
		if ($CollectionName.Length -gt 0)
		{
			$Collection 	= Get-AxCosmosDatabaseCollection -Context $NewCosmosContext -DatabaseName $DatabaseName -CollectionName $CollectionName
			if (!$Collection)
			{
				Throw "Database '$DatabaseName' or Collection '$CollectionName' does not exist"
				return $null
			}
			
			$ResourceLink 	= "dbs/$DatabaseName/colls/$CollectionName"
			$ResourceType 	= "docs"										# Not used here (for reference only)
			$queryUri 		= "$EndPoint/$ResourceLink/$ResourceType"		# Not used here (for reference only)

			$NewCosmosContext.collectionName	= $CollectionName
			$NewCosmosContext.collectionURI		= "$EndPoint/$ResourceLink"
			$NewCosmosContext.PartitionKeyName	= $Collection.PartitionKeyName
			$NewCosmosContext.AzContainerPath	= $AccountName + '/sql/' + $DatabaseName + '/' + $CollectionName
			$NewCosmosContext.AzContainerPath	= $AccountName + '/sql/' + $DatabaseName + '/' + $CollectionName
		}
	}

	return $NewCosmosContext
}


# +---------------------------------------------+
# |  New-AxCosmosAccount						|
# +---------------------------------------------+
# TEST: New-AzResourceGroup -Name $Test_ResourceGroupName -Location $Test_Location
# TEST: $c = New-AxCosmosAccount -AccountName $Test_AccountName -ResourceGroupName $Test_ResourceGroupName -Location $Test_Location -Verbose
Function New-AxCosmosAccount {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][String]	$AccountName,		# CosmosDB Account Name
		[Parameter(Mandatory=$true)][String]	$ResourceGroupName,	# Azure Resource Group
		[Parameter(Mandatory=$true)][String]	$Location,			# Azure Location
		[Parameter(Mandatory=$false)][Switch]	$Force				
    )
	
	# See if the resource already exists
	$r = Get-AzResource -ResourceType 'Microsoft.DocumentDb/databaseAccounts' `
		-ApiVersion '2020-01-01' -ResourceGroupName $resourceGroupName -ErrorAction Stop
	if ($r)
	{
		write-error "Resource already exists"
		return $null
	}

	#
	# CosmosDB Properties (posted through the New-AzResource cmdlet)
	#
	$locations = @(
		@{ "locationName"=$Location; "failoverPriority"=0 }
	)

	$consistencyPolicy = @{
		"defaultConsistencyLevel"="BoundedStaleness";
		"maxIntervalInSeconds"=300;
		"maxStalenessPrefix"=100000
	}

	$CosmosDBProperties = @{
		"databaseAccountOfferType"="Standard";
		"locations"=$locations;
		"consistencyPolicy"=$consistencyPolicy;
		"enableMultipleWriteLocations"="false"
	}

	# Create CosmosDB account (takes a long time!!!)
	write-warning "Creating CosmosDB account '$AccountName'... (this will take 5 to 8 minutes)"
	write-verbose "Creating CosmosDB account '$AccountName'... (this will take 5 to 8 minutes)"
	$t = Measure-Command { $r = New-AzResource -ResourceType 'Microsoft.DocumentDb/databaseAccounts' `
		-ApiVersion '2015-04-08' -ResourceGroupName $ResourceGroupName -Location $Location `
		-Name $AccountName.ToLower() -PropertyObject $CosmosDBProperties -Force:$Force }
	write-verbose "CosmosDb creation took $($t.ToString('T'))"

	$NewCosmosContext = New-AxCosmosContext -AccountName $AccountName -ResourceGroupName $ResourceGroupName 

	return $NewCosmosContext
}


# +---------------------------------------------+
# |  Remove-AxCosmosAccount						|
# +---------------------------------------------+
# TEST: Remove-AzResourceGroup -Name $Test_ResourceGroupName 
# TEST: $c = Remove-AxCosmosAccount -AccountName $Test_AccountName -ResourceGroupName $Test_ResourceGroupName -Verbose
# TODO: Allow -Context
Function Remove-AxCosmosAccount {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][String]	$AccountName,		# CosmosDB Account Name
		[Parameter(Mandatory=$true)][String]	$ResourceGroupName,	# Azure Resource Group
		[Parameter(Mandatory=$false)][Switch]	$Force				
    )
	
	# See if the resource already exists
	$r = Get-AzResource -ResourceType 'Microsoft.DocumentDb/databaseAccounts' `
		-ApiVersion '2020-01-01' -ResourceGroupName $resourceGroupName -ErrorAction Stop
	if (!$r)
	{
		write-error "Resource Does not exists"
		return $null
	}

	# Remove CosmosDB account (takes a long time!!!)
	write-warning "Removing CosmosDB account '$AccountName'... (this may take 4 to 8 minutes)"
	write-verbose "Removing CosmosDB account '$AccountName'... (this may take 4 to 8 minutes)"
	$t = Measure-Command { $r = Remove-AzResource -ResourceType 'Microsoft.DocumentDb/databaseAccounts' `
		-ApiVersion '2019-12-12' -ResourceGroupName $ResourceGroupName `
		-Name $AccountName.ToLower() -Force:$Force }
	write-verbose "CosmosDb account deletion took $($t.ToString('T'))"

	return $null
}


# +---------------------------------------------+
# |  New-AxCosmosDatabase						|
# +---------------------------------------------+
# TEST: $c8 = New-AxCosmosDatabase -Context $c -DatabaseName $Test_databaseName -Verbose
Function New-AxCosmosDatabase {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][AxCosmosContext]	$Context,			# CosmosDB Context
        [Parameter(Mandatory=$true)][String]			$DatabaseName,		# Database name
		[Parameter(Mandatory=$false)][Switch]			$Force				
    )
	
	$resourceName 		= $Context.accountName + '/sql/' + $DatabaseName
	$DataBaseProperties = @{
		"resource"=@{"id"=$databaseName}
		}

	# Create database within CosmosDb account
	write-verbose "Creating CosmosDB database '$databaseName'... (this will take 1 to 2 minutes)"
	write-warning "Creating CosmosDB database '$databaseName'... (this will take 1 to 2 minutes)"
	$t = Measure-Command { New-AzResource -ResourceType 'Microsoft.DocumentDb/databaseAccounts/apis/databases' `
		-ApiVersion '2015-04-08' -ResourceGroupName $Context.resourceGroupName `
		-Name $resourceName -PropertyObject $DataBaseProperties	-Force:$Force }
	write-verbose "CosmosDb database creation took $($t.ToString('T'))"
	

	# Add the Database Name details into the $Context
	$Context.databaseName				= $DatabaseName
	$Context.AzDabatasePath 			= $Context.accountName + '/sql/' + $DatabaseName

	return $Context
}


# +---------------------------------------------+
# |  Remove-AxCosmosDatabase					|
# +---------------------------------------------+
# TEST: $x = Remove-AxCosmosDatabase -Context $c -DatabaseName $Test_databaseName -Verbose
Function Remove-AxCosmosDatabase {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][AxCosmosContext]	$Context,			# CosmosDB Context
        [Parameter(Mandatory=$true)][String]			$DatabaseName,		# Database name
		[Parameter(Mandatory=$false)][Switch]			$Force				
    )
		
	$resourceName 		= $Context.accountName + '/sql/' + $DatabaseName
	$DataBaseProperties = @{
		"resource"=@{"id"=$databaseName}
		}

	# Remove database within CosmosDb account
	write-verbose "Removing CosmosDB database '$databaseName'... (this will take 1 to 2 minutes)"
	write-warning "Removing CosmosDB database '$databaseName'... (this will take 1 to 2 minutes)"
	$t = Measure-Command { Remove-AzResource -ResourceType 'Microsoft.DocumentDb/databaseAccounts/apis/databases' `
		-ApiVersion '2015-04-08' -ResourceGroupName $Context.resourceGroupName `
		-Name $resourceName	-Force:$Force }
	write-verbose "CosmosDb database deletion took $($t.ToString('T'))"

	# Remove the Database Name details from the $Context
	$Context.databaseName				= $null
	$Context.AzDabatasePath 			= $null

	return $Context
}


# +---------------------------------------------+
# |  Get-AxCosmosDatabase						|
# +---------------------------------------------+
# TEST: $db = Get-AxCosmosDatabase -Context $c -Verbose
Function Get-AxCosmosDatabase {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][AxCosmosContext]	$Context			# CosmosDB Context			
    )
		
	$resourceName 		= $Context.accountName + '/sql/' + $DatabaseName
	$DataBaseProperties = @{
		"resource"=@{"id"=$databaseName}
		}

	# Get databases within CosmosDb account
	# WARNING: This method does NOT always return the complete list!!
	write-verbose "Retrieving CosmosDB databases ..."
	$r = Get-AzResource -ResourceType 'Microsoft.DocumentDb/databaseAccounts/apis/databases' `
		-ApiVersion '2015-04-08' -ResourceGroupName $Context.resourceGroupName `
		-Name $resourceName 
		
	# https://docs.microsoft.com/en-us/rest/api/cosmos-db/databases
	write-host -ForegroundColor Cyan -NoNewLine "`nChecking for database '$databaseName'... "
	$Endpoint		= $Context.endPoint
	$dateTime		= [DateTime]::UtcNow.ToString("r").ToLowerInvariant()
	$Verb			= "GET"
	$ResourceLink	= "dbs"
	$QueryURI		= "$EndPoint/$ResourceLink"
	$ResourceType	= "dbs"
	$contentType	= "application/json"
	$authHeader		= Get-AxCosmosAuthSignature -verb $Verb -resourceLink $ResourceLink -resourceType $ResourceType `
						-key $Context.Key -keyType $Context.keyType -tokenVersion $Context.tokenVersion -dateTime $dateTime
	$header			= @{authorization=$authHeader;"x-ms-date"=$dateTime;"x-ms-version"="2015-12-16"}
	
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$r2 = $null
	# write-host -ForegroundColor Cyan "---- Header ----`n$($header | ConvertTo-Json)`n----------------"  # DEBUG
	$r2 = Invoke-RestMethod -Method $Verb -ContentType $contentType -Uri $QueryURI -Headers $header -UseBasicParsing # -Verbose -Debug
	
	# Merge Results
	$Results 	= @()
	$Databases 	= @($r.Name)
	$Databases	+= @($r2.Databases.id)
	$Databases	= $Databases | Select-Object -Unique
	foreach ($d in $Databases)
	{
		$AzEntry 					= $r | Where-Object {$_.Name -like $d} | Select-Object -First 1
		$CosmosEntry				= $r2.Databases | Where-Object {$_.id -like $d}
		$Entry 						= New-Object AxCosmosDatabase
		$Entry.Name					= $d
		$Entry.ResourceGroupName	= $AzEntry.ResourceGroupName 
		$Entry.ResourceType      	= $AzEntry.ResourceType		# Microsoft.DocumentDb/databaseAccounts/apis/databases
		$Entry.Location				= $AzEntry.Locations		# {empty for some reason}
		$Entry.ResourceId        	= $AzEntry.ResourceId		# /subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.DocumentDb/databaseAccounts/xxx/apis/sql/databases/xxx
		$Entry.Properties			= $CosmosEntry
		$Results					+= $Entry
	}

	return $Results
}

# +---------------------------------------------+
# |  New-AxCosmosDatabaseCollection				|
# +---------------------------------------------+
# TEST: $c2 = New-AxCosmosDatabaseCollection -Context $c -DatabaseName $Test_databaseName -CollectionName $Test_CollectionName -PartitionKeyName $Test_partitionKeyName -Verbose
Function New-AxCosmosDatabaseCollection {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][AxCosmosContext]	$Context,			# CosmosDB Context
        [Parameter(Mandatory=$true)][String]			$DatabaseName,		# Database name
		[Parameter(Mandatory=$true)][String]			$CollectionName,	# Container
		[Parameter(Mandatory=$true)][String]			$PartitionKeyName,	# Name of key to use as partition key
		[Parameter(Mandatory=$false)][Switch]			$Force				
    )
	
	# CosmosDb Container Properties
	$ContainerProperties = @{
		"resource"=@{
			"id"=$CollectionName;
			"partitionKey"=@{
				"paths"=@("/$PartitionKeyName");
				"kind"="Hash";
				"Version"=2
			}
		};
		"options"=@{ "Throughput"="400" }
	}

	$containerResourceName 	= $Context.accountName + '/sql/' + $DatabaseName + "/" + $CollectionName
	$DataBaseProperties = @{
		"resource"=@{"id"=$DatabaseName}
		}


	# Create the CosmosDb container (collection)
	write-verbose "Creating CosmosDB container '$containerResourceName'... (this will take 1 to 2 minutes)"
	write-warning "Creating CosmosDB container '$containerResourceName'... (this will take 1 to 2 minutes)"
	$t = Measure-Command { New-AzResource -ResourceType 'Microsoft.DocumentDb/databaseAccounts/apis/databases/containers' `
		-ApiVersion '2016-03-31' -ResourceGroupName $Context.resourceGroupName `
		-Name $containerResourceName -PropertyObject $ContainerProperties -Force }
	write-verbose "CosmosDb database collection creation took $($t.ToString('T'))"

	# Add the Database and container names into the $Context
	$Context.databaseName				= $DatabaseName
	$Context.AzDabatasePath 			= $Context.accountName + '/sql/' + $DatabaseName
	$Context.AzContainerPath			= $containerResourceName

	return $Context
}


# +---------------------------------------------+
# |  Remove-AxCosmosDatabaseCollection			|
# +---------------------------------------------+
# TEST: $c3 = Remove-AxCosmosDatabaseCollection -Context $c -DatabaseName $Test_databaseName -CollectionName $Test_CollectionName -Verbose
Function Remove-AxCosmosDatabaseCollection {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][AxCosmosContext]	$Context,			# CosmosDB Context
        [Parameter(Mandatory=$true)][String]			$DatabaseName,		# Database name
		[Parameter(Mandatory=$true)][String]			$CollectionName,	# Container
		[Parameter(Mandatory=$false)][Switch]			$Force				
    )

	$containerResourceName 	= $Context.accountName + '/sql/' + $DatabaseName + "/" + $CollectionName

	# Remove the CosmosDb container (collection)
	write-verbose "Removing CosmosDB container '$containerResourceName'... (this will take 1 to 2 minutes)"
	write-warning "Removing CosmosDB container '$containerResourceName'... (this will take 1 to 2 minutes)"
	$t = Measure-Command { Remove-AzResource -ResourceType 'Microsoft.DocumentDb/databaseAccounts/apis/databases/containers' `
		-ApiVersion '2016-03-31' -ResourceGroupName $Context.resourceGroupName `
		-Name $containerResourceName -Force:$Force }
	write-verbose "CosmosDb database collection removal took $($t.ToString('T'))"

	# Add the Database and container names into the $Context
	if ($Context.collectionName -like $CollectionName)
	{
		$Context.collectionName 	= $null
		$Context.AzContainerPath	= $null
	}

	return $Context
}


# +---------------------------------------------+
# |  Get-AxCosmosDatabaseCollection				|
# +---------------------------------------------+
# TEST: $dbc = Get-AxCosmosDatabaseCollection -Context $c -DatabaseName $Test_databaseName -Verbose
Function Get-AxCosmosDatabaseCollection {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][AxCosmosContext]	$Context,			# CosmosDB Context
        [Parameter(Mandatory=$true)][String]			$DatabaseName,		# Database name
		[Parameter(Mandatory=$false)][String]			$CollectionName		# Collection name (optional)
    )

	if ($CollectionName)
	{
		#-------------------------------+
		# Retrieve a single named entry	|
		#-------------------------------+
		$collectionResourceName 	= $Context.accountName + '/sql/' + $DatabaseName  + '/' + $CollectionName
	}
	else
	{
		#-------------------------------+
		# Retrieve multiple entries		|
		#-------------------------------+
		$collectionResourceName 	= $Context.accountName + '/sql/' + $DatabaseName 
	}
	write-verbose "Retrieving CosmosDB collection(s)... (this will take 1 to 2 minutes)"
	$r = Get-AzResource -ResourceType 'Microsoft.DocumentDb/databaseAccounts/apis/databases/containers' `
		-ApiVersion '2016-03-31' -ResourceGroupName $Context.resourceGroupName `
		-Name $collectionResourceName
	
	# Retrieve collection list from CosmosDb (there is no way to retrieve just one - TBD)
	# https://docs.microsoft.com/en-us/rest/api/cosmos-db/databases
	$Endpoint		= $Context.endPoint
	$dateTime		= [DateTime]::UtcNow.ToString("r").ToLowerInvariant()
	$Verb			="GET"
	$ResourceLink 	= "dbs/$databaseName"		# This is the PARENT of the $ResourceType
	$ResourceType	= "colls"
	$QueryURI		= "$EndPoint/$ResourceLink/$ResourceType"	
	$contentType	= "application/json"
	$authHeader		= Get-AxCosmosAuthSignature -verb $Verb -resourceLink $ResourceLink -resourceType $ResourceType `
						-key $Context.Key -keyType $Context.keyType -tokenVersion $Context.tokenVersion -dateTime $dateTime
	$header			= @{authorization=$authHeader;"x-ms-date"=$dateTime;"x-ms-version"="2015-12-16"}

	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$r2 = $null
	# write-host -ForegroundColor Cyan "---- Header ----`n$($header | ConvertTo-Json)`n----------------"  # DEBUG
	$r2 = Invoke-RestMethod -Method $Verb -ContentType $contentType -Uri $QueryURI -Headers $header -UseBasicParsing # -Verbose -Debug


	#-------------------------------+
	# Merge Results					|
	#-------------------------------+
	$Results 	= @()
	$Collections 	= @($r.Name)
	$Collections	+= @($r2.DocumentCollections.id)
	$Collections	= $Collections | Select-Object -Unique
	if ($CollectionName)
		{ $Collections = $Collections | Where-Object {$_ -like $CollectionName} }
	foreach ($c in $Collections)
	{
		$AzEntry 					= $r | Where-Object {$_.Name -like $c} | Select-Object -First 1
		$CosmosEntry				= $r2.DocumentCollections | Where-Object {$_.id -like $c}
		$Entry 						= New-Object AxCosmosDatabaseCollection
		$Entry.Name					= $c
		$Entry.ResourceGroupName	= $AzEntry.ResourceGroupName 
		$Entry.ResourceType      	= $AzEntry.ResourceType		# Microsoft.DocumentDb/databaseAccounts/apis/databases/containers
		$Entry.Location				= $AzEntry.Locations		# {empty for some reason}
		$Entry.ResourceId        	= $AzEntry.ResourceId		# /subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.DocumentDb/databaseAccounts/xxx/apis/sql/databases/xxx/containers/xxx
		$Entry.Properties			= $CosmosEntry
		
		# Process Partition Key Name
		if ($CosmosEntry.partitionKey.Paths)
			{ $Entry.PartitionKeyName		= $CosmosEntry.partitionKey.paths[0].SubString(1) }
		
		$Results					+= $Entry
	}

	return $Results
}


# +---------------------------------------------+
# |  Select-AxCosmosDatabaseCollection			|
# +---------------------------------------------+
# TEST: $c5 = Select-AxCosmosDatabaseCollection -Context $c -DatabaseName $Test_databaseName -CollectionName $Test_CollectionName -Verbose
Function Select-AxCosmosDatabaseCollection {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][AxCosmosContext]	$Context,	# CosmosDB Context
        [Parameter(Mandatory=$true)][String]	$DatabaseName,		# Database name
		[Parameter(Mandatory=$true)][String]	$CollectionName		# Collection (container) Name
    )
	
	# See if collection exists and retrieve the partition key name
	$Collection 				= Get-AxCosmosDatabaseCollection -Context $Context -DatabaseName $DatabaseName -CollectionName $CollectionName
	if (!$Collection)
	{
		Throw "Database '$DatabaseName' or Collection '$CollectionName' does not exist"
		return $null
	}
	
	$EndPoint 		= $Context.endPoint
    $ResourceLink 	= "dbs/$DatabaseName/colls/$CollectionName"
    $ResourceType 	= "docs"										# Not used here (for reference only)
    $queryUri 		= "$EndPoint/$ResourceLink/$ResourceType"		# Not used here (for reference only)

	$Context.databaseName		= $DatabaseName
	$Context.collectionName		= $CollectionName
	$Context.collectionURI		= "$EndPoint/$ResourceLink"
	$Context.PartitionKeyName	= $Collection.PartitionKeyName
	$Context.AzDabatasePath 	= $AccountName + '/sql/' + $DatabaseName
	$Context.AzContainerPath	= $AccountName + '/sql/' + $DatabaseName + '/' + $CollectionName
	
	return $Context
}


# +---------------------------------------------+
# |  Create-AxCosmosDocument					|
# +---------------------------------------------+
# TEST: Create-AxCosmosDocument -Context $c -Object $Entry1 -Upsert -Verbose
$Entry1 = New-Object PsObject
$Entry1 | Add-Member -NotePropertyName 'id' -NotePropertyValue 'FriendlyID1'
$Entry1 | Add-Member -NotePropertyName "_partitionKey" -NotePropertyValue "Partition1"
$Entry1 | Add-Member -NotePropertyName '_lastUpdate' -NotePropertyValue (get-date)
$Entry1 | Add-Member -NotePropertyName 'Description' -NotePropertyValue "This is a friendly id value"

Function Create-AxCosmosDocument {
    [CmdletBinding()]
    Param(
		[Parameter(Mandatory=$true)][AxCosmosContext]	$Context,		# Context object
		[Parameter(Mandatory=$false)][Switch]			$Upsert,		# Creates the document with the ID if it doesn’t exist, or update it if it exists.
        [Parameter(Mandatory=$true)][PsObject]			$Object			# JSON Document
    )
	
	# Check for id
	if (!$Object.id)
	{
		write-warning "'id' property is missing in object."
	}

	# The "id" property MUST be present in the Object with the name in lower case.
	# The id property cannot exceed 255 characters in length.
	# The following characters are restricted and cannot be used in the id property: '/', '\\', '?', '#'
	# https://docs.microsoft.com/en-us/dotnet/api/microsoft.azure.documents.resource.id?view=azure-dotnet
	foreach ($c in [char[]]'/?#')
	{
		if ($Object.id.Contains($c))
		{
			throw "Invalid '$c' character in 'id' property. The following characters are restricted and cannot be used in the id property: '/', '\\', '?', '#'."
			return $null
		}
	}
	if ($Object.id.Contains('\\'))
	{
		throw "Invalid '\\' in 'id' property. The following characters are restricted and cannot be used in the id property: '/', '\\', '?', '#'."
		return $null
	}
	
	# Check that we have a Database and Collection
	if ($Context.databaseName.Length -eq 0 -Or $Context.collectionName.Length -eq 0)
	{
		throw "Incomplete Context - Missing database or collection name. Try Select-AxCosmosDatabaseCollection."
		return $null
	}
	
	# API Version - SEE: https://docs.microsoft.com/en-us/rest/api/cosmos-db/index
	if ($Context.ApiVersion)
		{ $ApiVersion = $Context.ApiVersion }
	else
		{ $ApiVersion = "2018-06-18" }
	
	$Verb			= "POST"
	$JSON 			= ($Object | ConvertTo-Json -Depth 3)
	$UpsertTxt 		= $Upsert.ToString()				# True / False
	write-host "Upsert is $UpsertTxt"
    $ResourceType 	= "docs"
    $ResourceLink 	= "dbs/$($Context.databaseName)/colls/$($Context.CollectionName)"
	$contentType	= "application/json"
    $queryUri 		= "$($Context.EndPoint)/$ResourceLink/$ResourceType" # $Context.collectionURI + "/docs"
    $dateTime 		= [DateTime]::UtcNow.ToString("r")  # .ToLowerInvariant()
    $authHeader 	= Get-AxCosmosAuthSignature -verb $Verb -resourceLink $ResourceLink -resourceType $ResourceType `
							-key $Context.Key -keyType $Context.keyType -tokenVersion $Context.tokenVersion -dateTime $dateTime

	if ($Context.partitionKeyName)
	{ 
		# This needs to be the VALUE of the partition key for THIS entry and NOT the name of the partition key.
	    $partitionkeyValue = "[""$($Object.$($Context.partitionKeyName))""]" 
		$header = @{authorization=$authHeader;"x-ms-version"=$ApiVersion;"x-ms-date"=$dateTime;"x-ms-documentdb-partitionkey"=$partitionkeyValue;"x-ms-documentdb-is-upsert"=$UpsertTxt}
		$partitionKeyName = $Context.partitionKey
	}
	else
		{ $header = @{authorization=$authHeader;"x-ms-version"=$ApiVersion;"x-ms-date"=$dateTime;"x-ms-documentdb-is-upsert"=$UpsertTxt} }
	
	# Request TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	
		write-host -ForegroundColor Cyan "Object id: $($object.id)`n$partitionKeyName : '$($object.$partitionKeyName)' "
		write-host -ForegroundColor Cyan "QueryURI: $queryUri"
		write-host -ForegroundColor Cyan "---- Header ----`n$($header | ConvertTo-Json)`n----------------"  # DEBUG

	# https://stackoverflow.com/questions/35986647/how-do-i-get-the-body-of-a-web-request-that-returned-400-bad-request-from-invoke
	try {
		$result = Invoke-WebRequest -Method $Verb -ContentType $contentType -Uri $queryUri -Headers $header -Body $JSON -Debug # -Verbose -Debug # -ErrorVariable WebError
    }
   catch [System.Net.WebException] {
		# Below helps us get the REAL error reason instead of the 400 error
        $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
		$streamReader.BaseStream.Position = 0
        $response = ($streamReader.ReadToEnd() | ConvertFrom-Json)
        $streamReader.Close()
		if (Test-Debug)
		{
			write-host -ForegroundColor Cyan "`n==== DEBUG: Create-AxCosmosDocument ===="
			write-host -ForegroundColor Yellow "---- URI --------"
			write-host "$Verb  $queryUri"
			write-host -ForegroundColor Yellow "---- Headers ----"
			[string[]] $l_array = ($header | Out-String -Stream) -notmatch '^$' | select -Skip 2 ; 	write-host $l_array
			write-host -ForegroundColor Yellow "---- Body ------" ; write-host $query ; write-host -ForegroundColor Yellow "-----------------`n"
		}
		Throw "ERROR in Invoke-WebRequest: $($response.code) : $($response.message.Split(',')[0])"
		# $response | fl  # DEBUG
		# write-host ($_ | ConvertTo-json -Depth 4)   # $_.TargetObject   (LOTS OF STUFF!!)
		return 
    }
	
	return $null
}


# +---------------------------------------------+
# |  Remove-AxCosmosDocument					|
# +---------------------------------------------+
# TEST: Remove-AxCosmosDocument -Context $c -Object $Entry1 -Upsert -Verbose
Function Remove-AxCosmosDocument {
    [CmdletBinding()]
    Param(
		[Parameter(Mandatory=$true)][AxCosmosContext]	$Context,		# Context object
        [Parameter(Mandatory=$false)][String]			$idValue,      
		[Parameter(Mandatory=$false)][Switch]			$Force			# Creates the document with the ID if it doesn’t exist, or update it if it exists.
    )
	
	# Check for id
	if (!$Object.id)
	{
		write-warning "'id' property is missing in object."
	}

	# The "id" property MUST be present in the Object with the name in lower case.
	# The id property cannot exceed 255 characters in length.
	# The following characters are restricted and cannot be used in the id property: '/', '\\', '?', '#'
	# https://docs.microsoft.com/en-us/dotnet/api/microsoft.azure.documents.resource.id?view=azure-dotnet
	foreach ($c in [char[]]'/?#')
	{
		if ($Object.id.Contains($c))
		{
			throw "Invalid '$c' character in 'id' property. The following characters are restricted and cannot be used in the id property: '/', '\\', '?', '#'."
			return $null
		}
	}
	if ($Object.id.Contains('\\'))
	{
		throw "Invalid '\\' in 'id' property. The following characters are restricted and cannot be used in the id property: '/', '\\', '?', '#'."
		return $null
	}
	
	# Check that we have a Database and Collection
	if ($Context.databaseName.Length -eq 0 -Or $Context.collectionName.Length -eq 0)
	{
		throw "Incomplete Context - Missing database or collection name. Try Select-AxCosmosDatabaseCollection."
		return $null
	}
	
	# API Version - SEE: https://docs.microsoft.com/en-us/rest/api/cosmos-db/index
	if ($Context.ApiVersion)
		{ $ApiVersion = $Context.ApiVersion }
	else
		{ $ApiVersion = "2018-06-18" }
	
	$Verb			= "POST"
	$JSON 			= ($Object | ConvertTo-Json -Depth 3)
	$UpsertTxt 		= $Upsert.ToString()				# True / False
	write-host "Upsert is $UpsertTxt"
    $ResourceType 	= "docs"
    $ResourceLink 	= "dbs/$($Context.databaseName)/colls/$($Context.CollectionName)"
	$contentType	= "application/json"
    $queryUri 		= "$($Context.EndPoint)/$ResourceLink/$ResourceType" # $Context.collectionURI + "/docs"
    $dateTime 		= [DateTime]::UtcNow.ToString("r")  # .ToLowerInvariant()
    $authHeader 	= Get-AxCosmosAuthSignature -verb $Verb -resourceLink $ResourceLink -resourceType $ResourceType `
							-key $Context.Key -keyType $Context.keyType -tokenVersion $Context.tokenVersion -dateTime $dateTime

	if ($Context.partitionKeyName)
	{ 
		# This needs to be the VALUE of the partition key for THIS entry and NOT the name of the partition key.
	    $partitionkeyValue = "[""$($Object.$($Context.partitionKeyName))""]" 
		$header = @{authorization=$authHeader;"x-ms-version"=$ApiVersion;"x-ms-date"=$dateTime;"x-ms-documentdb-partitionkey"=$partitionkeyValue;"x-ms-documentdb-is-upsert"=$UpsertTxt}
		$partitionKeyName = $Context.partitionKey
	}
	else
		{ $header = @{authorization=$authHeader;"x-ms-version"=$ApiVersion;"x-ms-date"=$dateTime;"x-ms-documentdb-is-upsert"=$UpsertTxt} }
	
	# Request TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	
		write-host -ForegroundColor Cyan "Object id: $($object.id)`n$partitionKeyName : '$($object.$partitionKeyName)' "
		write-host -ForegroundColor Cyan "QueryURI: $queryUri"
		write-host -ForegroundColor Cyan "---- Header ----`n$($header | ConvertTo-Json)`n----------------"  # DEBUG

	# https://stackoverflow.com/questions/35986647/how-do-i-get-the-body-of-a-web-request-that-returned-400-bad-request-from-invoke
	try {
		$result = Invoke-WebRequest -Method $Verb -ContentType $contentType -Uri $queryUri -Headers $header -Body $JSON -Debug # -Verbose -Debug # -ErrorVariable WebError
    }
   catch [System.Net.WebException] {
		# Below helps us get the REAL error reason instead of the 400 error
        $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
		$streamReader.BaseStream.Position = 0
        $response = ($streamReader.ReadToEnd() | ConvertFrom-Json)
        $streamReader.Close()
		if (Test-Debug)
		{
			write-host -ForegroundColor Cyan "`n==== DEBUG: Create-AxCosmosDocument ===="
			write-host -ForegroundColor Yellow "---- URI --------"
			write-host "$Verb  $queryUri"
			write-host -ForegroundColor Yellow "---- Headers ----"
			[string[]] $l_array = ($header | Out-String -Stream) -notmatch '^$' | select -Skip 2 ; 	write-host $l_array
			write-host -ForegroundColor Yellow "---- Body ------" ; write-host $query ; write-host -ForegroundColor Yellow "-----------------`n"
		}
		Throw "ERROR in Invoke-WebRequest: $($response.code) : $($response.message.Split(',')[0])"
		# $response | fl  # DEBUG
		# write-host ($_ | ConvertTo-json -Depth 4)   # $_.TargetObject   (LOTS OF STUFF!!)
		return 
    }
	
	return $null
}


		
# +---------------------------------------------+
# |  Query-AxCosmosDocuments					|
# +---------------------------------------------+
# https://docs.microsoft.com/en-us/rest/api/cosmos-db/querying-cosmosdb-resources-using-the-rest-api
# TEST: $r = Query-AxCosmosDocuments -Context $c
Function Query-AxCosmosDocuments {
    [CmdletBinding()]
    Param(
		[Parameter(Mandatory=$true)][AxCosmosContext]	$Context,				# Context object
		[Parameter(Mandatory=$false)][String]			$PartitionKeyValue,		# Optionally specify a Partition Key Value (else cross-partition query enabled
        [Parameter(Mandatory=$false)][String]			$idValue      
    )

	# Extract fields 
	$partitionKeyName	= $Context.partitionKeyName
	$MasterKey		= $Context.Key

	$Verb="POST"
	$ApiVersion		= "2018-06-18"  # was "2015-12-16"  # SEE: https://docs.microsoft.com/en-us/rest/api/cosmos-db/index
    $ResourceType	= "docs";
    $ResourceLink	= "dbs/$($Context.databaseName)/colls/$($Context.collectionName)"
	if ($idValue)
	{
$query=@"
{  
  "query": "SELECT * FROM contacts c WHERE c.id = @id",  
  "parameters": [  
    {  
      "name": "@id",  
      "value": "$idValue"  
    }
  ]  
} 
"@
} else {
$query=@"
{  
  "query": "SELECT * FROM c",
  "parameters": []  
} 
"@
}

	$dateTime = [DateTime]::UtcNow.ToString("r")
    $contentType= "application/query+json"
    $queryUri = "$($Context.endPoint)/$ResourceLink/docs"
    $authHeader = Get-AxCosmosAuthSignature -verb $Verb -resourceLink $ResourceLink -resourceType $ResourceType -key $MasterKey -keyType "master" -tokenVersion "1.0" -dateTime $dateTime
    # $header = @{authorization=$authHeader;"x-ms-version"="2015-12-16";"x-ms-documentdb-isquery"="True";"x-ms-date"=$dateTime}

	if ($PartitionKeyValue)
	{ 
		# This needs to be the VALUE of the partition key for THIS entry and NOT the name of the partition key.
		$partitionkey = "[""$partitionKeyValue""]"
		$header = @{authorization=$authHeader;"x-ms-version"=$ApiVersion;"x-ms-date"=$dateTime;"x-ms-documentdb-partitionkey"=$partitionkey;"x-ms-documentdb-isquery"="True" }
		$partitionKeyName = $Context.partitionKey
	}
	else
		{ $header = @{authorization=$authHeader;"x-ms-version"=$ApiVersion;"x-ms-date"=$dateTime;"x-ms-documentdb-isquery"="True"; "x-ms-documentdb-query-enablecrosspartition"="True" } }

	
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	
	try {
		$result = Invoke-WebRequest -Method $Verb -ContentType $contentType -Uri $queryUri -Headers $header -Body $query -UseBasicParsing -Verbose -Debug # -Verbose -Debug # -ErrorVariable WebError
    }
    catch [System.Net.WebException] {
		# Below helps us get the REAL error reason instead of the 400 error
        $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
		$streamReader.BaseStream.Position = 0
        $response = ($streamReader.ReadToEnd() | ConvertFrom-Json)
        $streamReader.Close()
		if (Test-Debug)
		{
			write-host -ForegroundColor Cyan "`n==== DEBUG: Query-AxCosmosDocuments ===="
			write-host -ForegroundColor Cyan "id: '$($object.id)'"
			write-host -ForegroundColor Yellow "---- URI --------"
			write-host "$Verb  $queryUri"
			write-host -ForegroundColor Yellow "---- Headers ----"
			[string[]] $l_array = ($header | Out-String -Stream) -notmatch '^$' | select -Skip 2 ; 	write-host $l_array
			write-host -ForegroundColor Yellow "---- Body ------" ; write-host $query ; write-host -ForegroundColor Yellow "-----------------`n"
		}
		Throw "ERROR in Invoke-WebRequest: $($response.code) : $($response.message.Split(',')[0])"
		# $response | fl  # DEBUG
		# write-host ($_ | ConvertTo-json -Depth 4)   # $_.TargetObject   (LOTS OF STUFF!!)
		return 
    }
	
	# Check Results
	if ($result.StatusCode -eq 200)
	{
		Return ($result.Content | ConvertFrom-json).Documents
	}
	else
	{
		write-warning "Status code $($result.StatusCode) returned"
		if (Test-Debug)
		{
			write-host -ForegroundColor Cyan "`n==== DEBUG: Query-AxCosmosDocuments ===="
			write-host -ForegroundColor Cyan "id: '$($object.id)'"
			write-host -ForegroundColor Yellow "---- URI --------"
			write-host "$Verb  $queryUri"
			write-host -ForegroundColor Yellow "---- RawContet ----"
			write-host $result.RawContent
			write-host -ForegroundColor Yellow "-----------------`n"
		}		
	}
}



# +=================================================================================================+
# |  MAIN BODY																						|
# +=================================================================================================+


# +-----------------------------------------------------+
# |  Add some Test data, starting with a nice entry		|
# +-----------------------------------------------------+
# The following characters used to be restricted in the 'id' property: '/', '\\', '?', '#'	

if ($true -eq $true)
{
write-host -ForegroundColor Cyan "`nInserting test data into CosmosDB database...`n"

# Nice Entry with all friendly characters in the 'id'
$Entry = New-Object PsObject
$Entry | Add-Member -NotePropertyName 'id' -NotePropertyValue 'FriendlyID1'
$Entry | Add-Member -NotePropertyName $partitionKeyName -NotePropertyValue "Partition1"
$Entry | Add-Member -NotePropertyName '_lastUpdate' -NotePropertyValue $timeStamp
$Entry | Add-Member -NotePropertyName 'Description' -NotePropertyValue "This is a friendly id value"
$x = Create-AxCosmosDocument -accountName $CosmosDbAccountName -MasterKey $MasterKey -partitionKey ($Entry.$partitionKeyName) `
		-databaseName $databaseName -CollectionName $containerName -Upsert $true -Object $Entry

# Entry with a couple of slashes
$Entry = New-Object PsObject
$Entry | Add-Member -NotePropertyName 'id' -NotePropertyValue '/subscriptions/1234/id'
$Entry | Add-Member -NotePropertyName $partitionKeyName -NotePropertyValue "Partition1"
$Entry | Add-Member -NotePropertyName '_lastUpdate' -NotePropertyValue $timeStamp
$Entry | Add-Member -NotePropertyName 'Description' -NotePropertyValue "This id has slashes in it and will fail in ARM portal"
$x = Create-AxCosmosDocument -accountName $CosmosDbAccountName -MasterKey $MasterKey -partitionKey ($Entry.$partitionKeyName) `
		-databaseName $databaseName -CollectionName $containerName -Upsert $true -Object $Entry 

# Entry with a couple of slashes
$Entry = New-Object PsObject
$Entry | Add-Member -NotePropertyName 'id' -NotePropertyValue '/subscriptions/1234/id'
$Entry | Add-Member -NotePropertyName $partitionKeyName -NotePropertyValue "Partition1"
$Entry | Add-Member -NotePropertyName '_lastUpdate' -NotePropertyValue $timeStamp
$Entry | Add-Member -NotePropertyName 'Description' -NotePropertyValue "This id has forward slashes (/) in it and will fail in ARM portal"
$x = Create-AxCosmosDocument -accountName $CosmosDbAccountName -MasterKey $MasterKey -partitionKey ($Entry.$partitionKeyName) `
		-databaseName $databaseName -CollectionName $containerName -Upsert $true -Object $Entry 

# Another Entry with a couple of slashes
$Entry = New-Object PsObject
$Entry | Add-Member -NotePropertyName 'id' -NotePropertyValue 'Another/entryid'
$Entry | Add-Member -NotePropertyName $partitionKeyName -NotePropertyValue "Partition1"
$Entry | Add-Member -NotePropertyName '_lastUpdate' -NotePropertyValue $timeStamp
$Entry | Add-Member -NotePropertyName 'Description' -NotePropertyValue "This id also has forward slashes (/) in it and will fail in ARM portal"
$x = Create-AxCosmosDocument -accountName $CosmosDbAccountName -MasterKey $MasterKey -partitionKey ($Entry.$partitionKeyName) `
		-databaseName $databaseName -CollectionName $containerName -Upsert $true -Object $Entry 

# This entry has hash (#) symbol in it. 
# Not sure if this character is supported in API yet.
$Entry = New-Object PsObject
$Entry | Add-Member -NotePropertyName 'id' -NotePropertyValue 'YetAnother#entryid'
$Entry | Add-Member -NotePropertyName $partitionKeyName -NotePropertyValue "Partition1"
$Entry | Add-Member -NotePropertyName '_lastUpdate' -NotePropertyValue $timeStamp
$Entry | Add-Member -NotePropertyName 'Description' -NotePropertyValue "This id has a hash (#) in it and will fail in ARM portal"
$x = Create-AxCosmosDocument -accountName $CosmosDbAccountName -MasterKey $MasterKey -partitionKey ($Entry.$partitionKeyName) `
		-databaseName $databaseName -CollectionName $containerName -Upsert $true -Object $Entry 

# This entry has a Question Mark (?) symbol in it. 
# Not sure if this character is supported in API yet.
$Entry = New-Object PsObject
$Entry | Add-Member -NotePropertyName 'id' -NotePropertyValue 'StillAnother?entryid'
$Entry | Add-Member -NotePropertyName $partitionKeyName -NotePropertyValue "Partition1"
$Entry | Add-Member -NotePropertyName '_lastUpdate' -NotePropertyValue $timeStamp
$Entry | Add-Member -NotePropertyName 'Description' -NotePropertyValue "This id has a question mark (?) in it and will fail in ARM portal"
$x = Create-AxCosmosDocument -accountName $CosmosDbAccountName -MasterKey $MasterKey -partitionKey ($Entry.$partitionKeyName) `
		-databaseName $databaseName -CollectionName $containerName -Upsert $true -Object $Entry 

# The last entry is a good one and has no controversial characters
$Entry = New-Object PsObject
$Entry | Add-Member -NotePropertyName 'id' -NotePropertyValue 'LastEntryid'
$Entry | Add-Member -NotePropertyName $partitionKeyName -NotePropertyValue "Partition1"
$Entry | Add-Member -NotePropertyName '_lastUpdate' -NotePropertyValue $timeStamp
$Entry | Add-Member -NotePropertyName 'Description' -NotePropertyValue "This is the last entry and has no controversial id"
$x = Create-AxCosmosDocument -accountName $CosmosDbAccountName -MasterKey $MasterKey -partitionKey ($Entry.$partitionKeyName) `
		-databaseName $databaseName -CollectionName $containerName -Upsert $true -Object $Entry 
}

# +---------------------------------------------+
# | Now test if READING back works...			|
# +---------------------------------------------+
write-host -ForegroundColor Cyan "`nReading ALL entries back from CosmosDB database...`n"
$r = Query-AxCosmosDocuments -accountName $CosmosDbAccountName -databaseName $databaseName -partitionKey "Partition1" `
		 -CollectionName $containerName -MasterKey $MasterKey
write-host $r.Content

write-host -ForegroundColor Cyan "`nReading SINGLE entry with id='/subscriptions/1234/id' back from CosmosDB database...`n"
$r = Query-AxCosmosDocuments -accountName $CosmosDbAccountName -databaseName $databaseName -partitionKey "Partition1" `
		 -CollectionName $containerName -MasterKey $MasterKey -idValue '/subscriptions/1234/id'
write-host $r.Content



# +=================================================================================================+
# |  MODULE EXPORTS																					|
# +=================================================================================================+
Export-ModuleMember -Function Get-AxCosmosAuthSignature 
Export-ModuleMember -Function New-AxCosmosContext
Export-ModuleMember -Function New-AxCosmosAccount
Export-ModuleMember -Function Remove-AxCosmosAccount
Export-ModuleMember -Function New-AxCosmosDatabase
Export-ModuleMember -Function Remove-AxCosmosDatabase
Export-ModuleMember -Function Get-AxCosmosDatabase
Export-ModuleMember -Function New-AxCosmosDatabaseCollection
Export-ModuleMember -Function Remove-AxCosmosDatabaseCollection
Export-ModuleMember -Function Get-AxCosmosDatabaseCollection
Export-ModuleMember -Function Select-AxCosmosDatabaseCollection
Export-ModuleMember -Function Create-AxCosmosDocument
Export-ModuleMember -Function Query-CosmosDocuments
