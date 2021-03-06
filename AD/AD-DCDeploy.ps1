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

param(
   $subscriptionFilePath,
   $subscriptionName,
   $storageAccount,
   $location,
   $affinityGroupName,	
   $vmName, 
   $serviceName, 
   $availabilitySet,
   $size,
   $imageName,	
   $subnetNames,
   $password,
   $adminUserName,	
   [string[]]$dataDisks,			
   $vnetName,	
   $netBiosDomainName,	
   $dcInstallMode, 	
   $dnsDomain,
   $createVNET,
   $scriptFolder
)


################## Functions ##############################

function UpdateVNetDNSEntry()
{
	param([string] $dnsServerName, [string] $domainControllerIP)
	
	Write-Host "DC IP is : $domainControllerIP" 
	Write-Host "Adding Active Directory DNS to VNET"

	#Get the NetworkConfig.xml path
	$vnetConfigurationPath =  "$env:temp\spvnet.xml"
	
	Write-Host "   Exporting existing VNet..." -NoNewline
	Get-AzureVNetConfig -ExportToFile  $vnetConfigurationPath | Out-Null
   Write-Host -ForegroundColor Green " Complete"

	$namespace = "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration"

	# Read the configuration file into memory	
	Write-Host "   Read the configuration file into memory..." -NoNewline
	[xml]$doc =  Get-Content $vnetConfigurationPath
   Write-Host -ForegroundColor Green " Complete"

	if($doc.NetworkConfiguration.VirtualNetworkConfiguration.Dns.DnsServers -eq $null) 
	{
		Write-Host "   Adding Dns Server node..." -NoNewline
		$dnsServersNode = $doc.CreateElement("DnsServers", $namespace);
		$dnsServerNode = $doc.CreateElement("DnsServer", $namespace);
	    $dnsServerNode.SetAttribute('name', $dnsServerName);
		$dnsServerNode.SetAttribute('IPAddress', $domainControllerIP);
	    $dnsServersNode.AppendChild($dnsServerNode);	 
		$doc.NetworkConfiguration.VirtualNetworkConfiguration.GetElementsByTagName('Dns')[0].AppendChild($dnsServersNode);
	}
	else 
	{ 
		Write-Host "   Updating existing Dns Server node..." -NoNewline
		$dnsServerNode = $doc.NetworkConfiguration.VirtualNetworkConfiguration.Dns.DnsServers.SelectSingleNode("descendant::*[name()='DnsServer'][@name='" + $dnsServerName +"']");
		if($dnsServerNode -eq $null)
		{
			$dnsServerNode = $doc.CreateElement("DnsServer", $namespace);
		    $dnsServerNode.SetAttribute('name', $dnsServerName);
			$dnsServerNode.SetAttribute('IPAddress',$domainControllerIP);	    
		    $doc.NetworkConfiguration.VirtualNetworkConfiguration.Dns.DnsServers.AppendChild($dnsServerNode);
		}
		else
		{
			$dnsServerNode.SetAttribute('IPAddress',$domainControllerIP);	    
		}
	}
	Write-Host -ForegroundColor Green " Complete"
   
	$vnetSite = $doc.SelectSingleNode("/*/*/*[name()='VirtualNetworkSites']/*[name()='VirtualNetworkSite'][@name='" + $vnetName + "']");
	if($vnetSite.DnsServersRef -eq $null) 
	{
		Write-Host "   Adding Dns Servers Ref node..." -NoNewline
		$dnsServersRefNode = $doc.CreateElement("DnsServersRef", $namespace);
		$dnsServerRefNode = $doc.CreateElement("DnsServerRef", $namespace);
	    $dnsServerRefNode.SetAttribute('name', $dnsServerName);
	    $dnsServersRefNode.AppendChild($dnsServerRefNode);	 
		$vnetSite.AppendChild($dnsServersRefNode);
	}
	else 
	{
		Write-Host "   Updating existing Dns Servers Ref node..." -NoNewline
		$dnsServerRefNode = $vnetSite.DnsServersRef.SelectSingleNode("descendant::*[name()='DnsServerRef'][@name='" + $dnsServerName +"']");
		if($dnsServerRefNode -eq $null)
		{
			$dnsServerRefNode = $doc.CreateElement("DnsServerRef", $namespace);
		    $dnsServerRefNode.SetAttribute('name', $dnsServerName);
		    $vnetSite.DnsServersRef.AppendChild($dnsServerRefNode);
		}
	}
   Write-Host -ForegroundColor Green " Complete"
   
	Write-Host "   Writing the configuration file to disk..." -NoNewline
	$doc.Save($vnetConfigurationPath)
	Write-Host -ForegroundColor Green " Complete"
   
	Write-Host "   Updating VNet with Dns Server entry..." -NoNewline
	Set-AzureVNetConfig -ConfigurationPath $vnetConfigurationPath
   Write-Host -ForegroundColor Green " Complete"

   Write-Host "Completed Adding Active Directory DNS to VNET"

}

################## Functions ##############################

################## Script execution begin ###########

#Import-Module Azure
#Select-AzureSubscription -SubscriptionName $subscriptionName -verbose
Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccount $storageAccount -verbose -WarningAction SilentlyContinue

#$scriptFolder = Split-Path -parent $MyInvocation.MyCommand.Definition
$secPassword = ConvertTo-SecureString $password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($adminUserName, $secPassword)
$domainCredential = New-Object System.Management.Automation.PSCredential("$netBiosDomainName\$adminUserName", $secPassword)

CreateAzureVmIfNotExists `
   -serviceName $serviceName  `
   -vmName $vmName  `
   -size $size  `
   -imageName $imageName  `
   -availabilitySetName $availabilitySet  `
   -dataDisks  ($dataDisks) `
   -vnetName $vnetName  `
   -subnetNames $subnetNames  `
   -affinityGroup $affinityGroupName  `
   -adminUsername $adminUserName  `
   -adminPassword $password  `
   -location $location  `
   -dcInstallMode $dcInstallMode `
   -dnsDomain $dnsDomain `
   -netBiosDomainName $netBiosDomainName `
   -scriptFolder $scriptFolder

##CreateAzureVmIfNotExists `
##   -serviceName $serviceName  `
##   -vmName $vmName  `
##   -size $size  `
##   -imageName $imageName  `
##   -availabilitySetName $availabilitySet  `
##   -dataDisks  ($dataDisks) `
##   -vnetName $vnetName  `
##   -subnetNames $subnetNames  `
##   -affinityGroup $affinityGroupName  `
##   -adminUsername $adminUserName  `
##   -adminPassword $password  `
##   -location $location  `
##   -dcInstallMode $dcInstallMode `
##   -dnsDomain $dnsDomain `
##   -netBiosDomainName $netBiosDomainName `
##   -scriptFolder $scriptFolder

Write-Host
#Get the hosted service WinRM Uri
[System.Uri]$uris = (GetVMConnection -ServiceName $serviceName -vmName $vmName)
if ($uris -eq $null){return}

FormatDisk `
   -uris $uris `
   -Credential $Credential


Invoke-Command -ConnectionUri $URIS.ToString() -Credential $Credential -OutVariable $Result -ErrorVariable $ErrResult -ErrorAction SilentlyContinue -ScriptBlock { 
	Param([string]$dcInstallMode,[string]$adminUserName,[string]$password,[string]$domain,[string]$netBiosDomainName)
      
   Set-ExecutionPolicy Unrestricted -Force
     
   #Hide green status bar
   $ProgressPreference = "SilentlyContinue"
	
	#initialize DCPromo/ADDSDeployment arguments
	$computer = $env:COMPUTERNAME
	$dcPromoAnswerFile = $Env:TEMP + '\dcpromo.ini'
	
	$locationNTDS = "F:\DATA"		
	$locationNTDSLogs = "F:\LOGS"	
	$locationSYSVOL = "F:\SYSVOL"		
			
	#Create output files
	[IO.Directory]::CreateDirectory($locationNTDSLogs) 
	[IO.Directory]::CreateDirectory($locationSYSVOL) 
		
	#check if server 2012
	$is2012 = [Environment]::OSVersion.Version -ge (new-object 'Version' 6,2,9200,0)
		
	if(!$is2012) {exit}
   
   #use ADDSDeployment module		
   Write-Host "Running AD-DS Deployment module to install AD DS..."
   $locationNTDS = "F:\NTDS"

   #Create output file
   [IO.Directory]::CreateDirectory($locationNTDS) 

   #Add AD-DS Role
   Install-windowsfeature -name AD-Domain-Services –IncludeManagementTools -OutVariable $Result

   Write-Host "DC Install mode is $($dcInstallMode)"
   if($dcInstallMode -eq "NewForest")
   {
      #Installing a new forest root domain
      #Install-ADDSForest –DomainName $domain –DomainMode Win2012 –ForestMode Win2012 -Force -SafeModeAdministratorPassword (convertto-securestring $password -asplaintext -force) –DatabasePath $locationNTDS –SYSVOLPath $locationSYSVOL –LogPath $locationNTDSLogs -verbose
      Install-ADDSForest –DomainName $domain –DomainMode Win2012 –ForestMode Win2012 -Force `
      -SafeModeAdministratorPassword (convertto-securestring $password -asplaintext -force) `
      –DatabasePath $locationNTDS –SYSVOLPath $locationSYSVOL –LogPath $locationNTDSLogs `
      -WarningAction SilentlyContinue -OutVariable $Result
   }		
   elseif($dcInstallMode -eq "Replica")
   {
      #Installing a Replica domain
      $secPassword = ConvertTo-SecureString $password -AsPlainText -Force
      $domainCredential = New-Object System.Management.Automation.PSCredential("$domain\$adminUserName", $secPassword)
      Install-ADDSDomainController –Credential $domainCredential –DomainName $domain -Force -SafeModeAdministratorPassword (convertto-securestring $password -asplaintext -force) –DatabasePath $locationNTDS –SYSVOLPath $locationSYSVOL –LogPath $locationNTDSLogs -verbose
   }

   Write-Host "AD-DS Deployment completed..."

} -ArgumentList $dcInstallMode, $adminUserName, $password, $dnsDomain, $netBiosDomainName
   
# 60 Second pause to help with the services in Azure being ready
wait -msg "Waiting on Azure" -InSeconds 60 ; Write-Host

# Get the DC IP 
$vm = Get-AzureVM -ServiceName $serviceName -Name $vmName
$domainControllerIP = $vm.IpAddress

Write-Host "Configuring $vmName with a static internal IP, $domainControllerIP. This will allow stopping the VM later and still retain the IP."

# Set the IP as a static internal IP for the DC, to avoid losing it later. 
Set-AzureStaticVNETIP -IPAddress $domainControllerIP -VM $vm | Update-AzureVM | Out-Null

#Call UpdateVNetDNSEntry with the static internal IP.
if(-not [String]::IsNullOrEmpty($domainControllerIP))
{
	UpdateVNetDNSEntry $vmName $domainControllerIP | Out-Null
}

################## Script execution end ##############
