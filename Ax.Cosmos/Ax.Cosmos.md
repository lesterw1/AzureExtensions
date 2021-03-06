# Ax.Cosmos
***THIS IS UNDER CONSTRUCTION!!!***


| Cmdlet | Synopsis |
| --- | --- |
| [New-AxCosmosDocument](#New-AxCosmosDocument) | New-AxCosmosDocument [-Context] <AxCosmosContext> [-Object] <psobject> [-Upsert] [<CommonParameters>] |
| [Get-AxCosmosAuthSignature](#get-axcosmosauthsignature) | Get-AxCosmosAuthSignature [-verb] <string> [-resourceLink] <string> [-resourceType] <string> [-dateTime] <string> [-key] <string> [-keyType] <string> [[-tokenVersion] <string>] [<CommonParameters>] |
| [Get-AxCosmosDatabase](#get-axcosmosdatabase) | Get-AxCosmosDatabase [-Context] <AxCosmosContext> [<CommonParameters>] |
| [Get-AxCosmosDatabaseCollection](#get-axcosmosdatabasecollection) | Get-AxCosmosDatabaseCollection [-Context] <AxCosmosContext> [-DatabaseName] <string> [[-CollectionName] <string>] [<CommonParameters>] |
| [Get-AxCosmosDocument](#Get-AxCosmosDocument) | Get-AxCosmosDocument [-Context] <AxCosmosContext> [[-PartitionKeyValue] <string>] [[-idValue] <string>] [<CommonParameters>] |
| [New-AxCosmosAccount](#new-axcosmosaccount) | New-AxCosmosAccount [-AccountName] <string> [-ResourceGroupName] <string> [-Location] <string> [-Force] [<CommonParameters>] |
| [New-AxCosmosContext](#new-axcosmoscontext) | New-AxCosmosContext [-AccountName] <string> [-ResourceGroupName] <string> [[-DatabaseName] <string>] [[-MasterKey] <string>] [[-CollectionName] <string>] [<CommonParameters>] |
| [New-AxCosmosDatabase](#new-axcosmosdatabase) | New-AxCosmosDatabase [-Context] <AxCosmosContext> [-DatabaseName] <string> [-Force] [<CommonParameters>] |
| [New-AxCosmosDatabaseCollection](#new-axcosmosdatabasecollection) | New-AxCosmosDatabaseCollection [-Context] <AxCosmosContext> [-DatabaseName] <string> [-CollectionName] <string> [-PartitionKeyName] <string> [-Force] [<CommonParameters>] |
| [Remove-AxCosmosAccount](#remove-axcosmosaccount) | Remove-AxCosmosAccount [-AccountName] <string> [-ResourceGroupName] <string> [-Force] [<CommonParameters>] |
| [Remove-AxCosmosDatabase](#remove-axcosmosdatabase) | Remove-AxCosmosDatabase [-Context] <AxCosmosContext> [-DatabaseName] <string> [-Force] [<CommonParameters>] |
| [Remove-AxCosmosDatabaseCollection](#remove-axcosmosdatabasecollection) | Remove-AxCosmosDatabaseCollection [-Context] <AxCosmosContext> [-DatabaseName] <string> [-CollectionName] <string> [-Force] [<CommonParameters>] |
| [Select-AxCosmosDatabaseCollection](#select-axcosmosdatabasecollection) | Select-AxCosmosDatabaseCollection [-Context] <AxCosmosContext> [-DatabaseName] <string> [-CollectionName] <string> [<CommonParameters>] |

---
## New-AxCosmosDocument

### Synopsis

New-AxCosmosDocument [-Context] <AxCosmosContext> [-Object] <psobject> [-Upsert] [<CommonParameters>]

### Syntax

syntaxItem                                                                                                         
----------                                                                                                         
{@{name=New-AxCosmosDocument; CommonParameters=True; WorkflowCommonParameters=False; parameter=System.Object[]}}

### Description



### Parameters

	-Context <AxCosmosContext>

	-Object <psobject>

	-Upsert <>

---
## Get-AxCosmosAuthSignature

### Synopsis

Get-AxCosmosAuthSignature [-verb] <string> [-resourceLink] <string> [-resourceType] <string> [-dateTime] <string> [-key] <string> [-keyType] <string> [[-tokenVersion] <string>] [<CommonParameters>]

### Syntax

syntaxItem                                                                                                           
----------                                                                                                           
{@{name=Get-AxCosmosAuthSignature; CommonParameters=True; WorkflowCommonParameters=False; parameter=System.Object[]}}

### Description



### Parameters

	-dateTime <string>

	-key <string>

	-keyType <string>

	-resourceLink <string>

	-resourceType <string>

	-tokenVersion <string>

	-verb <string>

---
## Get-AxCosmosDatabase

### Synopsis

Get-AxCosmosDatabase [-Context] <AxCosmosContext> [<CommonParameters>]

### Syntax

syntaxItem                                                                                                      
----------                                                                                                      
{@{name=Get-AxCosmosDatabase; CommonParameters=True; WorkflowCommonParameters=False; parameter=System.Object[]}}

### Description



### Parameters

	-Context <AxCosmosContext>

---
## Get-AxCosmosDatabaseCollection

### Synopsis

Get-AxCosmosDatabaseCollection [-Context] <AxCosmosContext> [-DatabaseName] <string> [[-CollectionName] <string>] [<CommonParameters>]

### Syntax

syntaxItem                                                                                                                
----------                                                                                                                
{@{name=Get-AxCosmosDatabaseCollection; CommonParameters=True; WorkflowCommonParameters=False; parameter=System.Object[]}}

### Description



### Parameters

	-CollectionName <string>

	-Context <AxCosmosContext>

	-DatabaseName <string>

---
## New-AxCosmosAccount

### Synopsis

New-AxCosmosAccount [-AccountName] <string> [-ResourceGroupName] <string> [-Location] <string> [-Force] [<CommonParameters>]

### Syntax

syntaxItem                                                                                                     
----------                                                                                                     
{@{name=New-AxCosmosAccount; CommonParameters=True; WorkflowCommonParameters=False; parameter=System.Object[]}}

### Description



### Parameters

	-AccountName <string>

	-Force <>

	-Location <string>

	-ResourceGroupName <string>

---
## New-AxCosmosContext

### Synopsis

New-AxCosmosContext [-AccountName] <string> [-ResourceGroupName] <string> [[-DatabaseName] <string>] [[-MasterKey] <string>] [[-CollectionName] <string>] [<CommonParameters>]

### Syntax

syntaxItem                                                                                                     
----------                                                                                                     
{@{name=New-AxCosmosContext; CommonParameters=True; WorkflowCommonParameters=False; parameter=System.Object[]}}

### Description



### Parameters

	-AccountName <string>

	-CollectionName <string>

	-DatabaseName <string>

	-MasterKey <string>

	-ResourceGroupName <string>

---
## New-AxCosmosDatabase

### Synopsis

New-AxCosmosDatabase [-Context] <AxCosmosContext> [-DatabaseName] <string> [-Force] [<CommonParameters>]

### Syntax

syntaxItem                                                                                                      
----------                                                                                                      
{@{name=New-AxCosmosDatabase; CommonParameters=True; WorkflowCommonParameters=False; parameter=System.Object[]}}

### Description



### Parameters

	-Context <AxCosmosContext>

	-DatabaseName <string>

	-Force <>

---
## New-AxCosmosDatabaseCollection

### Synopsis

New-AxCosmosDatabaseCollection [-Context] <AxCosmosContext> [-DatabaseName] <string> [-CollectionName] <string> [-PartitionKeyName] <string> [-Force] [<CommonParameters>]

### Syntax

syntaxItem                                                                                                                
----------                                                                                                                
{@{name=New-AxCosmosDatabaseCollection; CommonParameters=True; WorkflowCommonParameters=False; parameter=System.Object[]}}

### Description



### Parameters

	-CollectionName <string>

	-Context <AxCosmosContext>

	-DatabaseName <string>

	-Force <>

	-PartitionKeyName <string>

---
## Get-AxCosmosDocument

### Synopsis

Get-AxCosmosDocument [-Context] <AxCosmosContext> [[-PartitionKeyValue] <string>] [[-idValue] <string>] [<CommonParameters>]

### Syntax

syntaxItem                                                                                                         
----------                                                                                                         
{@{name=Get-AxCosmosDocument; CommonParameters=True; WorkflowCommonParameters=False; parameter=System.Object[]}}

### Description



### Parameters

	-Context <AxCosmosContext>

	-PartitionKeyValue <string>

	-idValue <string>

---
## Remove-AxCosmosAccount

### Synopsis

Remove-AxCosmosAccount [-AccountName] <string> [-ResourceGroupName] <string> [-Force] [<CommonParameters>]

### Syntax

syntaxItem                                                                                                        
----------                                                                                                        
{@{name=Remove-AxCosmosAccount; CommonParameters=True; WorkflowCommonParameters=False; parameter=System.Object[]}}

### Description



### Parameters

	-AccountName <string>

	-Force <>

	-ResourceGroupName <string>

---
## Remove-AxCosmosDatabase

### Synopsis

Remove-AxCosmosDatabase [-Context] <AxCosmosContext> [-DatabaseName] <string> [-Force] [<CommonParameters>]

### Syntax

syntaxItem                                                                                                         
----------                                                                                                         
{@{name=Remove-AxCosmosDatabase; CommonParameters=True; WorkflowCommonParameters=False; parameter=System.Object[]}}

### Description



### Parameters

	-Context <AxCosmosContext>

	-DatabaseName <string>

	-Force <>

---
## Remove-AxCosmosDatabaseCollection

### Synopsis

Remove-AxCosmosDatabaseCollection [-Context] <AxCosmosContext> [-DatabaseName] <string> [-CollectionName] <string> [-Force] [<CommonParameters>]

### Syntax

syntaxItem                                                                                                                   
----------                                                                                                                   
{@{name=Remove-AxCosmosDatabaseCollection; CommonParameters=True; WorkflowCommonParameters=False; parameter=System.Object[]}}

### Description



### Parameters

	-CollectionName <string>

	-Context <AxCosmosContext>

	-DatabaseName <string>

	-Force <>

---
## Select-AxCosmosDatabaseCollection

### Synopsis

Select-AxCosmosDatabaseCollection [-Context] <AxCosmosContext> [-DatabaseName] <string> [-CollectionName] <string> [<CommonParameters>]

### Syntax

syntaxItem                                                                                                                   
----------                                                                                                                   
{@{name=Select-AxCosmosDatabaseCollection; CommonParameters=True; WorkflowCommonParameters=False; parameter=System.Object[]}}

### Description



### Parameters

	-CollectionName <string>

	-Context <AxCosmosContext>

	-DatabaseName <string>

---

