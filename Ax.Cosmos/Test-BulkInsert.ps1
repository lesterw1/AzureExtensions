<#
.SYNOPSIS
	Test-BulkInsert - Insert multiple entries via New-AxCosmosBulkDocuments cmdlet.
	
.DESCRIPTION
	This script generates a simple set of records and then calls New-AxCosmosBulkDocuments
	to create/update the records in a cosmos database.
	
.NOTES
	Author: Lester Waters
	Version: v0.02
	Date: 29-Mar-20

.LINK
	https://docs.microsoft.com/en-us/azure/cosmos-db/bulk-executor-overview
	
#>

# +=================================================================================================+
# |  PARAMETERS	              																		|
# +=================================================================================================+
[cmdletbinding()]   #  Add -Verbose support; use: [cmdletbinding(SupportsShouldProcess=$True)] to add WhatIf support
Param (
	[Parameter(Mandatory=$false)] [int] $Count = 1000			# Write out Cosmos DB
)


# +=================================================================================================+
# |  MODULES																						|
# +=================================================================================================+
Import-Module -Name Ax.Cosmos
Add-Type -AssemblyName System.Web

# +=================================================================================================+
# |  CLASSES																						|
# +=================================================================================================+

class TESTRECORD
{
	[string]  $id						# id MUST be lowercase for Cosmos!
	[string]  $_partitionKey			# Case MUST match that specified for the collection!!
	[string]  $Dummy					# Dummy Data
}

# +=================================================================================================+
# |  TEST CONSTANTS 																				|
# +=================================================================================================+
$Cosmos_Location				= 'West Europe'	
$Cosmos_ResourceGroupName		= 'rg-XXXXXX'
$Cosmos_AccountName				= 'XXXXXXX'					# Must be globally unique name and lower case  **CUSTOMIZE ME**
$Cosmos_databaseName 			= 'database1'
$Cosmos_partitionKeyName		= '_partitionKey'			# Name of property that we will use for consistent partition key names
$Cosmos_CollectionName 			= 'MyCollection'


# +=================================================================================================+
# |  VARIABLES																						|
# +=================================================================================================+

# Import Word List (used to generate column names)
write-host -ForegroundColor Yellow -NoNewLine "Reading wordlist.csv... "
$wordlist = Import-Csv -Path wordlist.csv -Header Word -ErrorAction SilentlyContinue
if ($wordlist.count -gt 1)
	{ write-host "OK" }
else
	{ write-warning "wordlist.csv not found. Will proceed without it."  ; $wordlist = $null }

# Start time after we have imported data
$startTime = Get-Date


# +=================================================================================================+
# |  COSMOS 																							|
# +=================================================================================================+
$CosmosTime 					= [TimeSpan] 0				# Sum of total time doing Cosmos APIs
$CosmosInsertList				= @()

write-host -ForegroundColor Yellow -NoNewLine "Getting Cosmos Context... "
$CosmosContext = New-AxCosmosContext -ResourceGroupName $Cosmos_ResourceGroupName -AccountName $Cosmos_AccountName `
					-DatabaseName $Cosmos_databaseName  -CollectionName $Cosmos_CollectionName # -MasterKey
write-host "OK"
					
if (!$CosmosContext)
{
	write-error "Unable to retreive Cosmos Context for account '$Cosmos_Account'"
	return
}


# +=================================================================================================+
# |  MAIN 																							|
# +=================================================================================================+
$Activity = "Writing Data"
$ctr = [int32] 0
write-progress -Activity $Activity -PercentComplete 0

# Now generate the entries
for ($i = 1; $i -le $Count; $i++)
{
	# Choose a random word for the ID and append the number
	if ($wordlist)
	{
		$r = Get-Random -Minimum -2 -Maximum ($wordlist.Count-2)
		$RowID = $wordlist[$r].Word + "-" + $i
	}
	else
	{
		$RowID = "Entry_" + $i
	}
	
	# Update progress but not too often so we dont become output bound
	$ctr++
	if ((($i % 10) -eq 0) -Or ($i -eq 1))
	{
		$pctComplete = [string] ([math]::Truncate(($ctr / $Count)*100))
		Write-Progress -Activity $Activity -PercentComplete $pctComplete -Status "$i of $Count - $RowID"
	}
		
	# Generate a record and add it to the insertion list
	$Entry 					= New-Object TESTRECORD
	$Entry.id				= $RowID		
	$Entry._partitionKey	= "Apple"			# Fine for < 10GB
	$Entry.Dummy			= "Written $(Get-Date)"
	$CosmosInsertList		+= $Entry

	# At the threshold of 50, BULK insert
	if (($i % 50) -eq 0)
	{
		write-verbose "Calling New-AxCosmosBulkDocuments..."
		$TimeTaken = Measure-Command { $d = New-AxCosmosBulkDocuments -Context $CosmosContext -Upsert -Object $CosmosInsertList -SkipChecks -Async  }  # -DEBUG -Verbose
		$CosmosTime += $TimeTaken; $TimeTakenTxt = $TimeTaken -f "ss"
		$CosmosInsertList = @()
	}
}
		
# Write out remaining records
if ($CosmosInsertList.Count -gt 0)
{
	write-progress -Activity $Activity -PercentComplete $pctComplete -Status "Writing remaining entries"
	$TimeTaken = Measure-Command { $d = New-AxCosmosBulkDocuments -Context $CosmosContext -Upsert -Object $CosmosInsertList -SkipChecks -Async }  # -DEBUG -Verbose
	$CosmosTime += $TimeTaken; $TimeTakenTxt = $TimeTaken -f "ss"
	$CosmosInsertList = @()
}

write-progress -Activity $Activity -PercentComplete 100 -Completed

# Output progress to console
$ElapsedTime = (Get-Date) - $StartTime
write-host -ForegroundColor Gray "Elapsed Time: $ElapsedTime"



Write-Progress -Activity $Activity -PercentComplete 100 -Completed

# +=================================================================================================+
# |  WRAP-UP																						|
# +=================================================================================================+

$ElapsedTime = (Get-Date) - $StartTime
write-host -ForegroundColor Yellow "`nSTATISTICS:"
write-host "Document Count : $Count"
write-host "Elapsed Time   :  $ElapsedTime"
write-host "Cosmos Time    :  $CosmosTime" 

