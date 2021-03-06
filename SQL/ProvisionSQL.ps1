<#
 * Copyright Microsoft Corporation
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
#>

param([parameter(Mandatory=$true)][string]$configFilePath,
      [parameter(Mandatory=$true)][string]$choice,
      [parameter(Mandatory=$true)][string]$scriptFolder)

#write-host $deployStandaloneSQLIIS (1)
#write-host $deployDomainSQLIIS (2)
#write-host $deploySharePoint (3)
      
$sqlScriptPath = (Join-Path -Path $scriptFolder -ChildPath 'SQL\ProvisionSqlVm.ps1')
[string]$sqlServerName = [string]::Empty

$config = [xml](gc $configFilePath)

$dcServiceName = $config.Azure.Connections.ActiveDirectory.ServiceName
$dcVmName = $config.Azure.Connections.ActiveDirectory.DomainControllerVM
$domainInstallerUserName = $config.Azure.Connections.ActiveDirectory.ServiceAccountName
$domainInstallerPassword = GetPasswordByUserName $domainInstallerUserName $config.Azure.ServiceAccounts.ServiceAccount

#Add AD Accounts
if ($choice -ne $deployStandaloneSQLIIS) { 

   Write-Host "Adding service account(s)"
   #Get the hosted service WinRM Uri
   [System.Uri]$DC_Uris = (GetVMConnection -ServiceName $dcServiceName -vmName $dcVmName)
   if ($DC_Uris -eq $null){return}

   $domainCredential = (SetCredential -Username $domainInstallerUsername -Password $domainInstallerPassword)

   if(($config.Azure.ServiceAccounts.ServiceAccount | ?{$_.Create -eq "Yes"}) -ne $null){
      $serviceAccounts = $config.Azure.ServiceAccounts.ServiceAccount
      foreach($serviceAccount in $serviceAccounts)
         {
         if($serviceAccount.UserName.Contains('\') -and ([string]::IsNullOrEmpty($serviceAccount.Create) -or (-not $serviceAccount.Create.Equals('No')))) {
            $username = $serviceAccount.UserName.Split('\')[1]		
            $password = $serviceAccount.Password

            AddServiceAccount `
            	-uris $DC_Uris ` 
               -credential $domainCredential `
               -ouName "ServiceAccounts" `
               -adUserName $username `
               -samAccountName $username `
               -displayName $username `
               -accountPassword $password
       	}
      }
      Write-Host "Completed";Write-Host
   }
   else{Write-Host -ForegroundColor Yellow "Skipping, No account(s) to add"}
}


# Provision VMs in each VM Group
foreach($vmRole in $config.Azure.AzureVMGroups.VMRole)
{
	if($vmRole.Name -eq 'SQLServers')
	{
		$subnetNames = @($vmRole.SubnetNames)
		foreach($azureVm in $vmRole.AzureVM)
		{			
			$dataDisks = @()
			foreach($dataDiskEntry in $vmRole.DataDiskSizesInGB.Split(';'))
			{
				$dataDisks += @($dataDiskEntry)
			}
			$availabilitySetName = $vmRole.AvailabilitySet
			if([string]::IsNullOrEmpty($availabilitySetName))
			{
				$availabilitySetName = $config.Azure.ServiceName
			}
			
			$defaultSqlBackupFolder = ''

			$adminUsername = $vmRole.ServiceAccountName
			$adminPassword = GetPasswordByUserName $VMRole.ServiceAccountName $config.Azure.ServiceAccounts.ServiceAccount
			 
			$domainDnsName = $config.Azure.Connections.ActiveDirectory.DnsDomain
			$domainInstallerUsername = $config.Azure.SQLCluster.InstallerDomainUsername			
			$domainInstallerPassword = GetPasswordByUserName $domainInstallerUsername $config.Azure.ServiceAccounts.ServiceAccount
			
			$databaseInstallerUsername = $config.Azure.SQLCluster.InstallerDatabaseUsername			
			$databaseInstallerPassword = GetPasswordByUserName $databaseInstallerUsername $config.Azure.ServiceAccounts.ServiceAccount
			$vnetName = $config.Azure.VNetName 
         $affinityGroup = $config.Azure.AffinityGroup
         $location = $config.Azure.Location
			$imageName = $vmRole.StartingImageName
         $vmSize = $vmRole.VMSize
         
			& $sqlScriptPath -subscriptionName $config.Azure.SubscriptionName -storageAccount $config.Azure.StorageAccount -subnetNames $subnetNames `
			-vmName $azureVm.Name -serviceName $config.Azure.ServiceName -vmSize $vmSize -vmType $azureVm.Type -imageName $imageName -availabilitySetName $availabilitySetName `
			-dataDisks $dataDisks -defaultSqlDataFolder $vmRole.DefaultSQLDataFolder -defaultSqlLogFolder $vmRole.DefaultSQLLogFolder `
			-highAvailabilityType $vmRole.HighAvailabilityType -defaultSqlBackupFolder $defaultSqlBackupFolder `
			-adminUsername $adminUsername -adminPassword $adminPassword -vnetName $vnetName -AffinityGroup $affinityGroup -domainDnsName $domainDnsName `
         -DomainInstallerUsername $domainInstallerUsername -DomainInstallerPassword $domainInstallerPassword `
         -DatabaseInstallerUsername $databaseInstallerUsername -DatabaseInstallerPassword $databaseInstallerPassword `
         -Choice $choice -Location $location -scriptFolder $scriptFolder

		}
	}
}
 
## End script