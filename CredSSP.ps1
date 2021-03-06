#Region Functions

##GP 6/10/2014
function local:LastStub($RegKey){
   if (($RegKey.Split("\").count) -gt 1)
   {$retunValue = $RegKey.Split("\")[($RegKey.Split("\").count)-1]}
   else {$retunValue = $RegKey}
return $retunValue
}

function local:CheckRegKey ($RegKey){
   Write-Host "   Checking" -NoNewline 
   if (!(Test-Path $RegKey)) {
      Write-Host -ForegroundColor Yellow " ...Adding" -NoNewline
      md $RegKey | Out-Null 
   } 
   Write-Host -ForegroundColor Green " ...Complete"
}

##GP 6/10/2014
##function local:FillKey($RegKey, $RegValue){
##   Write-Host "   Adding $($RegValue)"
##   $i = 1 ; $RegValue |% { New-ItemProperty -Path $RegKey -Name $i -Value $_ -PropertyType String -Force | Out-Null ; $i++ }
##}

function local:AddProperty()
{
   param ($RegKey, $KeyProperty, $KeyPropertyValue)
   
   Write-Host "   Checking property <$($KeyProperty)>" -NoNewline
   $Item = Get-Item $regKey
   
   if (!($Item.GetValue("$KeyProperty")) ){ Write-Host -ForegroundColor Yellow " ...Adding" -NoNewline }
   else { Write-Host -ForegroundColor Yellow " ...Updating" -NoNewline }
   
   Set-ItemProperty "$($regKey)" -Name $KeyProperty -Value $KeyPropertyValue
   Write-Host " ...Complete" -ForegroundColor Green
}

##GP 6/10/2014
function local:UpdateReg ()
{
   param ($PrimaryKey, $SubKey, $KeyProperty="WSMan", $KeyPropertyValue="WSMAN/*.cloudapp.net", $SetDefaultProperty=$false)

   if ($SetDefaultProperty){
      Write-Host "$($SubKey) <property>"
      Write-Host "   Checking" -NoNewline
      if ((Get-ItemProperty $PrimaryKey -Name $SubKey -ErrorAction SilentlyContinue)) 
      {
         if ((Get-Item $PrimaryKey).GetValue($SubKey) -ne 1) 
         {
            Write-Host -ForegroundColor Yellow "...Updating" -NoNewline
            Set-ItemProperty $Primkey -Name $SubKey -Value 1
         }
      }
      else 
      {
         Write-Host -ForegroundColor Yellow "...Adding" -NoNewline
         New-ItemProperty -Path $PrimaryKey -Name $SubKey -Value 1 -PropertyType Dword -Force | Out-Null
      }
      Write-Host -ForegroundColor Green "...Complete"
   }
 
   $SubKeyPath = Join-Path $PrimaryKey $SubKey

   ##Write Key
   Write-Host "$($SubKey) <key>"
   CheckRegKey -RegKey $SubKeyPath
   AddProperty -RegKey $SubKeyPath -KeyProperty $KeyProperty -KeyPropertyValue $KeyPropertyValue
#   FillKey -RegKey $SubKeyPath -RegValue $RegValue
}

##function local:UpdateReg2 ($PrimaryKey, $SubKey, $KeyProperty, $KeyPropertyValue){
##   $SubKeyPath = Join-Path $PrimaryKey $SubKey
##
##   ##Write Key
##   Write-Host "$($SubKey) <key>"
##   CheckRegKey -RegKey $SubKeyPath
##   AddProperty -RegKey $SubKeyPath -KeyProperty $KeyProperty -KeyPropertyValue $KeyPropertyValue
##}

#EndRegion

 <#
  * Enable the ByPass PowerShell execution policy by running Set-ExecutionPolicy ByPass. 
  * This will allow the downloaded scripts to run without individually prompting you
 #>

 Set-ExecutionPolicy ByPass

 <#
  * Enable Powershell Remoting
  * Note:  This command will fail if your client machine is connected to any networks defined as "Public network" in "Network and Sharing Center."
 #>

Enable-PSRemoting -Force 
 
 <#
   * Enable CredSSP on your client machine for delegation before executing any scripts
   * Note:  This command will fail if your client machine is connected to any networks defined as "Public network" in "Network and Sharing Center."
   * For more details on enabling CredSSP:
   *       http://msdn.microsoft.com/en-us/library/windows/desktop/ee309365(v=vs.85).aspx
   *       http://technet.microsoft.com/en-us/library/hh849872.asp
 #>
 
Write-Host "`nChecking Cred SSP" -NoNewline
if (!((Get-WSManCredSSP)[0].contains("cloudapp.net")))
{
   Write-Host -ForegroundColor Green "... Enabling"
   Enable-WSManCredSSP -role client -delegatecomputer "*.cloudapp.net" -Force | Out-Null
}
else {Write-Host -ForegroundColor Green "... Skipping"}

# $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults\AllowFreshCredentialsDomain"  
Write-Host "`nUpdating registry"
 
$regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults"
Write-Host "`n$($regKey)`n" -NoNewline
CheckRegKey "$($regKey)"
##UpdateReg -PrimaryKey $regKey -SubKey "AllowFreshCredentialsDomain" -KeyProperty "WSMan" -KeyPropertyValue 'WSMAN/*.cloudapp.net'
##UpdateReg -PrimaryKey $regKey -SubKey "AllowFreshCredentialsWhenNTLMOnly" -KeyProperty "WSMan" -KeyPropertyValue 'WSMAN/*.cloudapp.net'
##UpdateReg -PrimaryKey $regKey -SubKey "AllowFreshCredentialsWhenNTLMOnlyDomain" -KeyProperty "WSMan" -KeyPropertyValue 'WSMAN/*.cloudapp.net'
UpdateReg -PrimaryKey $regKey -SubKey "AllowFreshCredentialsDomain"
UpdateReg -PrimaryKey $regKey -SubKey "AllowFreshCredentialsWhenNTLMOnly"
UpdateReg -PrimaryKey $regKey -SubKey "AllowFreshCredentialsWhenNTLMOnlyDomain" 

Write-Host ""

$PrimaryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
Write-Host "`n$($PrimaryKey)`n" -NoNewline
CheckRegKey -RegKey $PrimaryKey

##UpdateReg -PrimaryKey $PrimaryKey -SubKey 'AllowFreshCredentials' -KeyProperty "1" -KeyPropertyValue 'WSMAN/*.cloudapp.net' -SetDefaultProperty $true
##UpdateReg -PrimaryKey $PrimaryKey -SubKey 'AllowFreshCredentialsWhenNTLMOnly' -KeyProperty "1" -KeyPropertyValue 'WSMAN/*.cloudapp.net'  -SetDefaultProperty $true

UpdateReg -PrimaryKey $PrimaryKey -SubKey 'AllowFreshCredentials' -KeyProperty "1" -SetDefaultProperty $true
UpdateReg -PrimaryKey $PrimaryKey -SubKey 'AllowFreshCredentialsWhenNTLMOnly' -KeyProperty "1" -SetDefaultProperty $true

Write-Host "`nRegistry update complete"
