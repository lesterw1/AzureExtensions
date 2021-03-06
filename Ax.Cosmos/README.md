# Ax.Cosmos
The Ax.Cosmos module is provided as an interim PowerShell solution
for Azure Cosmos in the absence of a Microsoft-provided solution.
With this module, you can:

* Create and delete Cosmos accounts
* Create and delete Cosmos databases
* Create and delete Cosmos collections (containers)
* Create and update (upsert) Cosmos documents

The Ax.Cosmos module requires that a *context* be created in order to work with
databases and collections. The context contains the access key, the currently selected
collection / container name, and the partition key name associated with the collection.
The **New-AxCosmosContext** cmdlet is used to create a new context.
When creating a new Cosmos account with **New-AxCosmosAccount**, a context will also be return
but it will be necessary to then create a database and container before Cosmos documents can be added.
Use **Select-AxCosmosDatabaseCollection** to switch between collections (containers) within the selected database.

The **New-AxCosmosAccount** and **New-AxCosmosDatabase** cmdlets can take up to 10 minutes to complete.
All cmdlets are synchronous in this module version (so you just have to wait for the cmdlet to complete),
except for **New-AxCosmoBulkDocuments** which has an **-Async** option (currently under development; not recommended at this time).
Given the length of time for account, database, and collection creation, the respective cmdlets will output a warning
about the time it will take (which can optionally be supressed with the -WarningAction switch).

## Cmdlets
This module provides the following commands:

| Cmdlet | Description |
| --- | --- |
| Get-AxCosmosDatabase | Retrieve information for one or more databases in the Cosmos account. |
| Get-AxCosmosDatabaseCollection | Retrieve one or more collections (containers) in the specified Cosmos database. |
| Get-AxCosmosDocument | Query for a Cosmos document object in the specified database (and optionally within a collection). |
| New-AxCosmosAccount | Create a new Cosmos account. |
| New-AxCosmosContext | Create a new AxCosmosContext. |
| New-AxCosmosDatabase | Create a new Cosmos database. |
| New-AxCosmosDatabaseCollection | Create a new collection (container) within a Cosmos database. |
| New-AxCosmosDocument | Create a new document (object) within a Cosmos collection. |
| New-AxCosmoBulkDocuments | Creates multiple documents (objects) within a Cosmos collection. |
| Remove-AxCosmosAccount | Delete a Cosmos account and all databases within. |
| Remove-AxCosmosDatabase | Delete a Cosmos database instance. |
| Remove-AxCosmosDatabaseCollection | Delete a collection (container) within a Cosmos database. |
| Remove-AxCosmosDocument | Delete an existing Cosmos document by id. |
| Select-AxCosmosDatabaseCollection | Select the Cosmos database and collection (container) to use. |

At this time, there is no programmatic way (that I am aware of) to *retrieve* the configuration for containers (i.e., the RUs).

### Documentation
The cmdlets are documented in the [https://github.com/lesterw1/AzureExtensions/blob/master/Ax.Cosmos/Ax.Cosmos.md](Ax.Cosmos.md) page in this repository.


## Getting Started
The following steps will help you get started:

1) Install the Ax.Cosmos module.
This is done by first determining where modules are installed. Start PowerShell and run the command:
```
$Env:PSModulePath
```
This will result in several paths.
Use the first path if you want the module to be available for a specific user.
Use the second path to make the module available for all users.

Next, copy or download the **Ax.Cosmos** *as a folder* into the new path. That is, you
should have an **Ax.Cosmos** folder in the directory referenced by **$Env:PSModulePath**.

2) Import the Ax.Cosmos module.

```
Import-Module Ax.Cosmos
```

3) The first step is to create a Cosmos account. This can be done with the **New-AxCosmosAccount** cmdlet.
The process takes 5 to 10 minutes to complete. 

```powershell
New-AzResourceGroup -Name 'rg-cosmos' -Location 'westeurope'
$c = New-AxCosmosAccount -AccountName 'contoso' -ResourceGroupName 'rg-cosmos' -Location 'westeurope' -Verbose -Force
```
The **New-AxCosmosAccount** returns a AxCosmosAccountContext object which must be used for subsequent access to the account.

4)  The next step is to create a database using the context $c from above:

```powershell
New-AxCosmosDatabase -Context $c -DatabaseName 'MyDatabase' -Force -Verbose
```

The above creates a new database named 'MyDatabase'. The process takes 1 to 2 minutes.

5) Next, create a collection (container) named 'MyCollection' within the database.
Note that it is necessary to specify the DatabaseName in this cmdlet.

```powershell
New-AxCosmosDatabaseCollection -Context $c -DatabaseName 'MyDatabase' -CollectionName 'MyCollection' -PartitionKeyName 'Country' -Force -Verbose
```

The above creates a new database named 'MyDatabase'. The context $c is updated with the selected database, collection, and
partition key names so that subsequent use of the context will default accordingly.

6) Now that a database and a collection has been created, we can insert a document:

```powershell
$MyObject = '{ "id": "100",  "Name": "John Doe",   "City": "London",  "Country": "United Kingdom" }' | ConvertFrom-Json
New-AxCosmosDocument -Context $c -Object $MyObject -Upsert -Verbose
```

There are _two_ REQUIRED properties in *every* object that is inserted into this container: (1) the 'id' property whose
name MUST be lower case (e.g., 'id'); AND the property associated with the container's partition key must also be present
and must exactly match case (e.g., for the above example, we used 'Country' so that property name must match exactly; e.g., 'country'
is not acceptable).

The -Upsert switch can be used to replace the document object if it already exists (i.e., has the same 'id' value).
Note that Cosmos does not support partial document updates, so the entire document must be rewritten each time
any change is required.

7) Next, we can query for this object using the 'id' property:

```powershell
Get-AxCosmosDocument -Context $c -idValue '100'
```

This will return the object that we created in step 5, which will also
have some additional properties attached as shown below:

```
id           : 100
Name         : John Doe
City         : London
Country      : United Kingdom
_rid         : jhVrAKo4XREBAAAAAAAAAA==
_self        : dbs/jhVrAA==/colls/jhVrAKo4XRE=/docs/jhVrAKo4XREBAAAAAAAAAA==/
_etag        : "0000d72a-0000-0d00-0000-5e64cde80000"
_attachments : attachments/
_ts          : 1583664616
```

Querying for Cosmos documents (objects) using other properties is possible, but requires a more advanced structure
to be passed in.  

8) Lastly, we can remove the Cosmos document using the id:

```powershell
Remove-AxCosmosDocument -Context $c -idValue '100'
```

### AxCosmosContext Object
The Ax.Cosmos module requires that a *context* be created in order to work with
databases and collections. The **AxCosmosContext** object, used to hold this context,
contains the access key, the currently selected collection / container name, and the
partition key name associated with the collection.

For example:
```
accountName       : contoso
resourceGroupName : rg-cosmos
subscriptionId    : 00000000-0000-0000-0000-000000000000
location          : 
databaseName      : MyDatabase
collectionName    : MyCollection
partitionKeyName  : Country
AzDabatasePath    : contoso/sql/MyDatabase
AzContainerPath   : contoso/sql/MyDatabase/MyCollection
keyType           : master
tokenVersion      : 1.0
hmacSHA256        : System.Security.Cryptography.HMACSHA256
endPoint          : https://contoso.documents.azure.com
collectionURI     : https://contoso.documents.azure.com/dbs/MyDatabase/colls/MyCollection
ApiVersion        : 2018-06-18
```

The hmacSHA256 property contains the object which is used to digitally sign the underlyig Cosmos REST APIs.
Note that the location property is not filled in as the underlying API does not yet return it.


## Performance
Achieving decent performance is challenging. Event with 20,000 RUs configured, adding/upserting documents is dead slow.
I attempted to improve this by spawning jobs for calling the Cosmos REST API via Invoke-WebRequest, but even this ran
into its own issues. Some observations:

* LIMITATION: The Cosmos REST API [here](https://docs.microsoft.com/en-us/rest/api/cosmos-db/documents) only allows a single document to be synchronously added at a time. 
There doesn't appear to be any API to allow multiple documents to be created at once.
The .NET team has created a bulk executor library for Cosmos 
but this 1st cut of the module is itself in powershell so cannot yet take advantage. 

* The PowerShell **Invoke-RestMethod** cmdlet has an unexplainable lag, as if the requests are being serialized.
In fairness, this could be resolved by re-implementing this module in C#.

Some benchmarks using Ax.Cosmos and the **Test-BulkInsert.ps1** script for insertion of 1,000 items with a
database container configured for Throughput of 20,000 (RU/s). For this version, the concurrent jobs is set to 50.

| **BulkSize** | **Async** | **Elapsed Time** | **Cosmos Time** | **Time per Item** |
| --- | --- | --- | --- |--- |
| 50 | False | 00:01:42.7553027 | 00:01:34.8130316 | 0.095 Seconds |
| 100 | False | 00:01:42.1512901 | 00:01:34.5813155 | 0.095 Seconds |
| 200 | False | 00:01:41.7932899 | 00:01:34.2697490 | 0.094 Seconds |
| 50 | True | 00:05:37.5189992 | 00:05:28.0603363 | 0.328 Seconds |
| 100 | True | 00:03:16.4224028 | 00:03:06.3761100 | 0.186 Seconds |
| 200 | True | 00:05:46.4596323 | 00:05:36.9803734 | 0.337 Seconds |

The next development step will attempt to spawn jobs to do synchronous bulk insertion in groups of 50.
So 1,000 items would be 20 parallel jobs.  I'll post the stats once this is in place.

# Architecture
This Ax.Cosmos module is written in PowerShell and utilizes a combination of
the [Cosmos REST APIs](https://docs.microsoft.com/en-us/rest/api/cosmos-db/)
and the Azure [New-AzResource](https://docs.microsoft.com/en-us/powershell/module/az.resources/new-azresource)
and related cmdlets. The design is not intended for high-performance use.


## Next Steps
In no particular order:

* Ensure all the functions have headers. The documentation is generated from these headers.

* Add the individual help headers for each cmdlet function so that **Get-Help** may  be used to retrieve the documentation for each.

* Implement Remove-AxCosmosDocument using query parameters (vs just by id).

* Provide support for various Cosmos account sizes, replication settings, etc.
The current implementation is hard-coded for a small size.

* Implement support for Get-AxCosmosDocument with complex queries.

* Improve error handling.

* Eliminate need for .Key property in AxCosmosContext.
This involves changing the code to use the hmacSHA256 instance. 

* Improve the Query-AxCosmosDocuments cmdlet.
The cmdlet is fairly narrow and tedious to use.
Provide a "simple" mode along side the more complex query mode.

* Provide examples within each cmdlet in the .Example comment section.

* Fill in *location* property in AxCosmosContext Object. 
This is a known issue in that the underlying API does not return the location for some unknown reason.

* Figure out how to *retrieve* the current throughput (RU/Sec) for a database container.

* C# .NET implementation... any volunteers?

### Implementation Notes
This module is itself implemented in PowerShell using a combination of the Azure **AzResource**
cmdlets (Get-AzResource, New-AzResource, Remove-AzResource) and by calling Cosmos REST APIs directly. 
It is intended for casual use of Cosmos databases and would benefit from being implemented in C#.NET,
particularly using the new Bulk executor module (https://docs.microsoft.com/en-us/azure/cosmos-db/bulk-executor-overview).
**Any volunteers?** :blush:

