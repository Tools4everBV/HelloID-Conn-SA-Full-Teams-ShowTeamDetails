#HelloID variables
$script:PortalBaseUrl = "https://CUSTOMER.helloid.com"
$apiKey = "API_KEY"
$apiSecret = "API_SECRET"
$delegatedFormAccessGroupNames = @("Users", "HID_administrators")
$delegatedFormCategories = @("Teams") 
# Create authorization headers with HelloID API key
$pair = "$apiKey" + ":" + "$apiSecret"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$key = "Basic $base64"
$script:headers = @{"authorization" = $Key}
# Define specific endpoint URI
$script:PortalBaseUrl = $script:PortalBaseUrl.trim("/") + "/"
 
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    
    if ($args) {
        Write-Output $args
    } else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}
function Invoke-HelloIDGlobalVariable {
    param(
        [parameter(Mandatory)][String]$Name,
        [parameter(Mandatory)][String][AllowEmptyString()]$Value,
        [parameter(Mandatory)][String]$Secret
    )
    try {
        $uri = ($script:PortalBaseUrl + "api/v1/automation/variables/named/$Name")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
    
        if ([string]::IsNullOrEmpty($response.automationVariableGuid)) {
            #Create Variable
            $body = @{
                name     = $Name;
                value    = $Value;
                secret   = $Secret;
                ItemType = 0;
            }    
            $body = ConvertTo-Json -InputObject $body
    
            $uri = ($script:PortalBaseUrl + "api/v1/automation/variable")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $variableGuid = $response.automationVariableGuid
            Write-ColorOutput Green "Variable '$Name' created: $variableGuid"
        } else {
            $variableGuid = $response.automationVariableGuid
            Write-ColorOutput Yellow "Variable '$Name' already exists: $variableGuid"
        }
    } catch {
        Write-ColorOutput Red "Variable '$Name', message: $_"
    }
}
function Invoke-HelloIDAutomationTask {
    param(
        [parameter(Mandatory)][String]$TaskName,
        [parameter(Mandatory)][String]$UseTemplate,
        [parameter(Mandatory)][String]$AutomationContainer,
        [parameter(Mandatory)][String][AllowEmptyString()]$Variables,
        [parameter(Mandatory)][String]$PowershellScript,
        [parameter()][String][AllowEmptyString()]$ObjectGuid,
        [parameter()][String][AllowEmptyString()]$ForceCreateTask,
        [parameter(Mandatory)][Ref]$returnObject
    )
    
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/automationtasks?search=$TaskName&container=$AutomationContainer")
        $responseRaw = (Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false) 
        $response = $responseRaw | Where-Object -filter {$_.name -eq $TaskName}
    
        if([string]::IsNullOrEmpty($response.automationTaskGuid) -or $ForceCreateTask -eq $true) {
            #Create Task
            $body = @{
                name                = $TaskName;
                useTemplate         = $UseTemplate;
                powerShellScript    = $PowershellScript;
                automationContainer = $AutomationContainer;
                objectGuid          = $ObjectGuid;
                variables           = [Object[]]($Variables | ConvertFrom-Json);
            }
            $body = ConvertTo-Json -InputObject $body
    
            $uri = ($script:PortalBaseUrl +"api/v1/automationtasks/powershell")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $taskGuid = $response.automationTaskGuid
            Write-ColorOutput Green "Powershell task '$TaskName' created: $taskGuid"  
        } else {
            #Get TaskGUID
            $taskGuid = $response.automationTaskGuid
            Write-ColorOutput Yellow "Powershell task '$TaskName' already exists: $taskGuid"
        }
    } catch {
        Write-ColorOutput Red "Powershell task '$TaskName', message: $_"
    }
    $returnObject.Value = $taskGuid
}
function Invoke-HelloIDDatasource {
    param(
        [parameter(Mandatory)][String]$DatasourceName,
        [parameter(Mandatory)][String]$DatasourceType,
        [parameter(Mandatory)][String][AllowEmptyString()]$DatasourceModel,
        [parameter()][String][AllowEmptyString()]$DatasourceStaticValue,
        [parameter()][String][AllowEmptyString()]$DatasourcePsScript,        
        [parameter()][String][AllowEmptyString()]$DatasourceInput,
        [parameter()][String][AllowEmptyString()]$AutomationTaskGuid,
        [parameter(Mandatory)][Ref]$returnObject
    )
    $datasourceTypeName = switch($DatasourceType) { 
        "1" { "Native data source"; break} 
        "2" { "Static data source"; break} 
        "3" { "Task data source"; break} 
        "4" { "Powershell data source"; break}
    }
    
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/datasource/named/$DatasourceName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
      
        if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
            #Create DataSource
            $body = @{
                name               = $DatasourceName;
                type               = $DatasourceType;
                model              = [Object[]]($DatasourceModel | ConvertFrom-Json);
                automationTaskGUID = $AutomationTaskGuid;
                value              = [Object[]]($DatasourceStaticValue | ConvertFrom-Json);
                script             = $DatasourcePsScript;
                input              = [Object[]]($DatasourceInput | ConvertFrom-Json);
            }
            $body = ConvertTo-Json -InputObject $body
      
            $uri = ($script:PortalBaseUrl +"api/v1/datasource")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
              
            $datasourceGuid = $response.dataSourceGUID
            Write-ColorOutput Green "$datasourceTypeName '$DatasourceName' created: $datasourceGuid"
        } else {
            #Get DatasourceGUID
            $datasourceGuid = $response.dataSourceGUID
            Write-ColorOutput Yellow "$datasourceTypeName '$DatasourceName' already exists: $datasourceGuid"
        }
    } catch {
      Write-ColorOutput Red "$datasourceTypeName '$DatasourceName', message: $_"
    }
    $returnObject.Value = $datasourceGuid
}
function Invoke-HelloIDDynamicForm {
    param(
        [parameter(Mandatory)][String]$FormName,
        [parameter(Mandatory)][String]$FormSchema,
        [parameter(Mandatory)][Ref]$returnObject
    )
    
    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/forms/$FormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }
    
        if(([string]::IsNullOrEmpty($response.dynamicFormGUID)) -or ($response.isUpdated -eq $true)) {
            #Create Dynamic form
            $body = @{
                Name       = $FormName;
                FormSchema = [Object[]]($FormSchema | ConvertFrom-Json)
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100
    
            $uri = ($script:PortalBaseUrl +"api/v1/forms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
    
            $formGuid = $response.dynamicFormGUID
            Write-ColorOutput Green "Dynamic form '$formName' created: $formGuid"
        } else {
            $formGuid = $response.dynamicFormGUID
            Write-ColorOutput Yellow "Dynamic form '$FormName' already exists: $formGuid"
        }
    } catch {
        Write-ColorOutput Red "Dynamic form '$FormName', message: $_"
    }
    $returnObject.Value = $formGuid
}
function Invoke-HelloIDDelegatedForm {
    param(
        [parameter(Mandatory)][String]$DelegatedFormName,
        [parameter(Mandatory)][String]$DynamicFormGuid,
        [parameter()][String][AllowEmptyString()]$AccessGroups,
        [parameter()][String][AllowEmptyString()]$Categories,
        [parameter(Mandatory)][String]$UseFaIcon,
        [parameter()][String][AllowEmptyString()]$FaIcon,
        [parameter(Mandatory)][Ref]$returnObject
    )
    $delegatedFormCreated = $false
    
    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$DelegatedFormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }
    
        if([string]::IsNullOrEmpty($response.delegatedFormGUID)) {
            #Create DelegatedForm
            $body = @{
                name            = $DelegatedFormName;
                dynamicFormGUID = $DynamicFormGuid;
                isEnabled       = "True";
                accessGroups    = [Object[]]($AccessGroups | ConvertFrom-Json);
                useFaIcon       = $UseFaIcon;
                faIcon          = $FaIcon;
            }    
            $body = ConvertTo-Json -InputObject $body
    
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
    
            $delegatedFormGuid = $response.delegatedFormGUID
            Write-ColorOutput Green "Delegated form '$DelegatedFormName' created: $delegatedFormGuid"
            $delegatedFormCreated = $true
            $bodyCategories = $Categories
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$delegatedFormGuid/categories")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $bodyCategories
            Write-ColorOutput Green "Delegated form '$DelegatedFormName' updated with categories"
        } else {
            #Get delegatedFormGUID
            $delegatedFormGuid = $response.delegatedFormGUID
            Write-ColorOutput Yellow "Delegated form '$DelegatedFormName' already exists: $delegatedFormGuid"
        }
    } catch {
        Write-ColorOutput Red "Delegated form '$DelegatedFormName', message: $_"
    }
    $returnObject.value.guid = $delegatedFormGuid
    $returnObject.value.created = $delegatedFormCreated
}<# Begin: HelloID Global Variables #>
$tmpValue = "" 
$tmpName = @'
TeamsAdminUser
'@ 
Invoke-HelloIDGlobalVariable -Name $tmpName -Value $tmpValue -Secret "True" 
$tmpValue = "" 
$tmpName = @'
TeamsAdminPWD
'@ 
Invoke-HelloIDGlobalVariable -Name $tmpName -Value $tmpValue -Secret "True" 
<# End: HelloID Global Variables #>


<# Begin: HelloID Data sources #>
<# Begin: DataSource "Teams-get-team-users" #>
$tmpScript = @'
$groupId = $formInput.selectedGroup.GroupId
$role = $formInput.Role

$connected = $false
try {
	Import-Module MicrosoftTeams
	$pwd = ConvertTo-SecureString -string $TeamsAdminPWD -AsPlainText -Force
	$cred = New-Object System.Management.Automation.PSCredential $TeamsAdminUser, $pwd
	Connect-MicrosoftTeams -Credential $cred
    HID-Write-Status -Message "Connected to Microsoft Teams" -Event Information
    HID-Write-Summary -Message "Connected to Microsoft Teams" -Event Information
	$connected = $true
}
catch
{	
    HID-Write-Status -Message "Could not connect to Microsoft Teams. Error: $($_.Exception.Message)" -Event Error
    HID-Write-Summary -Message "Failed to connect to Microsoft Teams" -Event Failed
}

if ($connected)
{
	try {
		$teams = Get-TeamUser -GroupId $groupId -Role $role

		if(@($teams).Count -gt 0){
			foreach($teamuser in $teams)
			{
				$addRow = @{User=$teamuser.User; UserId=$teamuser.UserId; Name=$teamuser.Name; Role=$teamuser.Role; }
				Hid-Add-TaskResult -ResultValue $addRow
			}
		}else{
			Hid-Add-TaskResult -ResultValue []
		}
	}
	catch
	{
		HID-Write-Status -Message "Error getting Team Members. Error: $($_.Exception.Message)" -Event Error
		HID-Write-Summary -Message "Error getting Team Members" -Event Failed
		Hid-Add-TaskResult -ResultValue []
	}
}
else
{
	Hid-Add-TaskResult -ResultValue []
}
'@; 

$tmpVariables = @'

'@ 

$taskGuid = [PSCustomObject]@{} 
$dataSourceGuid_3_Name = @'
Teams-get-team-users
'@ 
Invoke-HelloIDAutomationTask -TaskName $dataSourceGuid_3_Name -UseTemplate "False" -AutomationContainer "1" -Variables $tmpVariables -PowershellScript $tmpScript -returnObject ([Ref]$taskGuid) 

$tmpInput = @'
[{"description":"","translateDescription":false,"inputFieldType":1,"key":"selectedGroup","type":0,"options":0},{"description":"","translateDescription":false,"inputFieldType":1,"key":"Role","type":0,"options":0}]
'@ 
$tmpModel = @'
[{"key":"Name","type":0},{"key":"Role","type":0},{"key":"UserId","type":0},{"key":"User","type":0}]
'@ 
$dataSourceGuid_3 = [PSCustomObject]@{} 
$dataSourceGuid_3_Name = @'
Teams-get-team-users
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_3_Name -DatasourceType "3" -DatasourceInput $tmpInput -DatasourceModel $tmpModel -AutomationTaskGuid $taskGuid -returnObject ([Ref]$dataSourceGuid_3) 
<# End: DataSource "Teams-get-team-users" #>

<# Begin: DataSource "Teams-get-team-details" #>
$tmpScript = @'
#Input: TeamsAdminUser
#Input: TeamsAdminPWD
$groupId = $formInput.selectedGroup.GroupId
#$groupId = '0293ec24-013d-4a3a-ba2b-7836ef8f15dd'

$connected = $false
try {
	Import-Module MicrosoftTeams
	$pwd = ConvertTo-SecureString -string $TeamsAdminPWD -AsPlainText �Force
	$cred = New-Object System.Management.Automation.PSCredential $TeamsAdminUser, $pwd
	Connect-MicrosoftTeams -Credential $cred
    HID-Write-Status -Message "Connected to Microsoft Teams" -Event Information
    HID-Write-Summary -Message "Connected to Microsoft Teams" -Event Information
	$connected = $true
}
catch
{	
    HID-Write-Status -Message "Could not connect to Microsoft Teams. Error: $($_.Exception.Message)" -Event Error
    HID-Write-Summary -Message "Failed to connect to Microsoft Teams" -Event Failed
}

if ($connected)
{
	try {
        $teams = Get-Team -GroupId $groupId
        
        if(@($teams).Count -eq 1){
         foreach($tmp in $teams.psObject.properties)
            {
                $returnObject = [ordered]@{name=$tmp.Name; value=$tmp.value}
                Hid-Add-TaskResult -ResultValue $returnObject
            }
        }else{
            Hid-Add-TaskResult -ResultValue []
        }
	}
	catch
	{
		HID-Write-Status -Message "Error getting Team Details. Error: $($_.Exception.Message)" -Event Error
		HID-Write-Summary -Message "Error getting Team Details" -Event Failed
		Hid-Add-TaskResult -ResultValue []
	}
}
else
{
	Hid-Add-TaskResult -ResultValue []
}

'@; 

$tmpVariables = @'

'@ 

$taskGuid = [PSCustomObject]@{} 
$dataSourceGuid_1_Name = @'
teams-get-team-details
'@ 
Invoke-HelloIDAutomationTask -TaskName $dataSourceGuid_1_Name -UseTemplate "False" -AutomationContainer "1" -Variables $tmpVariables -PowershellScript $tmpScript -returnObject ([Ref]$taskGuid) 

$tmpInput = @'
[{"description":"","translateDescription":false,"inputFieldType":1,"key":"selectedGroup","type":0,"options":0}]
'@ 
$tmpModel = @'
[{"key":"Visibility","type":0},{"key":"MailNickName","type":0},{"key":"DisplayName","type":0},{"key":"GroupId","type":0},{"key":"Archived","type":0},{"key":"Description","type":0}]
'@ 
$dataSourceGuid_1 = [PSCustomObject]@{} 
$dataSourceGuid_1_Name = @'
Teams-get-team-details
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_1_Name -DatasourceType "3" -DatasourceInput $tmpInput -DatasourceModel $tmpModel -AutomationTaskGuid $taskGuid -returnObject ([Ref]$dataSourceGuid_1) 
<# End: DataSource "Teams-get-team-details" #>

<# Begin: DataSource "Teams-get-team-users" #>
$tmpScript = @'
$groupId = $formInput.selectedGroup.GroupId
$role = $formInput.Role

$connected = $false
try {
	Import-Module MicrosoftTeams
	$pwd = ConvertTo-SecureString -string $TeamsAdminPWD -AsPlainText -Force
	$cred = New-Object System.Management.Automation.PSCredential $TeamsAdminUser, $pwd
	Connect-MicrosoftTeams -Credential $cred
    HID-Write-Status -Message "Connected to Microsoft Teams" -Event Information
    HID-Write-Summary -Message "Connected to Microsoft Teams" -Event Information
	$connected = $true
}
catch
{	
    HID-Write-Status -Message "Could not connect to Microsoft Teams. Error: $($_.Exception.Message)" -Event Error
    HID-Write-Summary -Message "Failed to connect to Microsoft Teams" -Event Failed
}

if ($connected)
{
	try {
		$teams = Get-TeamUser -GroupId $groupId -Role $role

		if(@($teams).Count -gt 0){
			foreach($teamuser in $teams)
			{
				$addRow = @{User=$teamuser.User; UserId=$teamuser.UserId; Name=$teamuser.Name; Role=$teamuser.Role; }
				Hid-Add-TaskResult -ResultValue $addRow
			}
		}else{
			Hid-Add-TaskResult -ResultValue []
		}
	}
	catch
	{
		HID-Write-Status -Message "Error getting Team Members. Error: $($_.Exception.Message)" -Event Error
		HID-Write-Summary -Message "Error getting Team Members" -Event Failed
		Hid-Add-TaskResult -ResultValue []
	}
}
else
{
	Hid-Add-TaskResult -ResultValue []
}
'@; 

$tmpVariables = @'

'@ 

$taskGuid = [PSCustomObject]@{} 
$dataSourceGuid_2_Name = @'
Teams-get-team-users
'@ 
Invoke-HelloIDAutomationTask -TaskName $dataSourceGuid_2_Name -UseTemplate "False" -AutomationContainer "1" -Variables $tmpVariables -PowershellScript $tmpScript -returnObject ([Ref]$taskGuid) 

$tmpInput = @'
[{"description":"","translateDescription":false,"inputFieldType":1,"key":"selectedGroup","type":0,"options":0},{"description":"","translateDescription":false,"inputFieldType":1,"key":"Role","type":0,"options":0}]
'@ 
$tmpModel = @'
[{"key":"Name","type":0},{"key":"Role","type":0},{"key":"UserId","type":0},{"key":"User","type":0}]
'@ 
$dataSourceGuid_2 = [PSCustomObject]@{} 
$dataSourceGuid_2_Name = @'
Teams-get-team-users
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_2_Name -DatasourceType "3" -DatasourceInput $tmpInput -DatasourceModel $tmpModel -AutomationTaskGuid $taskGuid -returnObject ([Ref]$dataSourceGuid_2) 
<# End: DataSource "Teams-get-team-users" #>

<# Begin: DataSource "Teams-get-teams" #>
$tmpScript = @'
#Input: TeamsAdminUser
#Input: TeamsAdminPWD

$connected = $false
try {
	Import-Module MicrosoftTeams
	$pwd = ConvertTo-SecureString -string $TeamsAdminPWD -AsPlainText �Force
	$cred = New-Object System.Management.Automation.PSCredential $TeamsAdminUser, $pwd
	Connect-MicrosoftTeams -Credential $cred
    HID-Write-Status -Message "Connected to Microsoft Teams" -Event Information
    HID-Write-Summary -Message "Connected to Microsoft Teams" -Event Information
	$connected = $true
}
catch
{	
    HID-Write-Status -Message "Could not connect to Microsoft Teams. Error: $($_.Exception.Message)" -Event Error
    HID-Write-Summary -Message "Failed to connect to Microsoft Teams" -Event Failed
}

if ($connected)
{
	try {
	    $teams = Get-Team

        if(@($teams).Count -gt 0){
         foreach($team in $teams)
            {
                $addRow = @{DisplayName=$team.DisplayName; Description=$team.Description; MailNickName=$team.MailNickName; Visibility=$team.Visibility; Archived=$team.Archived; GroupId=$team.GroupId;}
                Hid-Write-Status -Message "$addRow" -Event Information
                Hid-Add-TaskResult -ResultValue $addRow
            }
        }else{
            Hid-Add-TaskResult -ResultValue []
        }
	}
	catch
	{
		HID-Write-Status -Message "Error getting Teams. Error: $($_.Exception.Message)" -Event Error
		HID-Write-Summary -Message "Error getting Teams" -Event Failed
		Hid-Add-TaskResult -ResultValue []
	}
}
else
{
	Hid-Add-TaskResult -ResultValue []
}

'@; 

$tmpVariables = @'

'@ 

$taskGuid = [PSCustomObject]@{} 
$dataSourceGuid_0_Name = @'
Teams-Get-teams
'@ 
Invoke-HelloIDAutomationTask -TaskName $dataSourceGuid_0_Name -UseTemplate "False" -AutomationContainer "1" -Variables $tmpVariables -PowershellScript $tmpScript -returnObject ([Ref]$taskGuid) 

$tmpInput = @'
[{"description":"Filter for DisplayName","translateDescription":false,"inputFieldType":1,"key":"filterDisplayName","type":0,"options":0}]
'@ 
$tmpModel = @'
[{"key":"Archived","type":0},{"key":"Description","type":0},{"key":"GroupId","type":0},{"key":"DisplayName","type":0},{"key":"MailNickName","type":0},{"key":"Visibility","type":0}]
'@ 
$dataSourceGuid_0 = [PSCustomObject]@{} 
$dataSourceGuid_0_Name = @'
Teams-get-teams
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_0_Name -DatasourceType "3" -DatasourceInput $tmpInput -DatasourceModel $tmpModel -AutomationTaskGuid $taskGuid -returnObject ([Ref]$dataSourceGuid_0) 
<# End: DataSource "Teams-get-teams" #>
<# End: HelloID Data sources #>

<# Begin: Dynamic Form "Teams - Get Team Details" #>
$tmpSchema = @"
[{"label":"Select Team","fields":[{"key":"filterDisplayName","templateOptions":{"label":"Search for DisplayName","required":false},"type":"input","summaryVisibility":"Show","requiresTemplateOptions":true},{"key":"teams","templateOptions":{"label":"Select Team","required":true,"grid":{"columns":[{"headerName":"Display Name","field":"DisplayName"},{"headerName":"Description","field":"Description"},{"headerName":"Mail Nick Name","field":"MailNickName"},{"headerName":"Visibility","field":"Visibility"},{"headerName":"Archived","field":"Archived"},{"headerName":"Group Id","field":"GroupId"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_0","input":{"propertyInputs":[{"propertyName":"filterDisplayName","otherFieldValue":{"otherFieldKey":"filterDisplayName"}}]}},"useFilter":false,"useDefault":false},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true}]},{"label":"Team Details","fields":[{"key":"Details","templateOptions":{"label":"Details","required":false,"grid":{"columns":[{"headerName":"Name","field":"name"},{"headerName":"Value","field":"value"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_1","input":{"propertyInputs":[{"propertyName":"selectedGroup","otherFieldValue":{"otherFieldKey":"teams"}}]}},"useDefault":false,"useFilter":false},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true},{"key":"Members","templateOptions":{"label":"Members","required":false,"grid":{"columns":[{"headerName":"User","field":"User"},{"headerName":"Name","field":"Name"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_2","input":{"propertyInputs":[{"propertyName":"Role","staticValue":{"value":"Member"}},{"propertyName":"selectedGroup","otherFieldValue":{"otherFieldKey":"teams"}}]}},"useFilter":true,"useDefault":false},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true},{"key":"Owners","templateOptions":{"label":"Members","required":false,"grid":{"columns":[{"headerName":"User","field":"User"},{"headerName":"Name","field":"Name"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_3","input":{"propertyInputs":[{"propertyName":"Role","staticValue":{"value":"Owner"}},{"propertyName":"selectedGroup","otherFieldValue":{"otherFieldKey":"teams"}}]}},"useFilter":true,"useDefault":false},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true}]}]
"@ 

$dynamicFormGuid = [PSCustomObject]@{} 
$dynamicFormName = @'
Teams - Get Team Details
'@ 
Invoke-HelloIDDynamicForm -FormName $dynamicFormName -FormSchema $tmpSchema  -returnObject ([Ref]$dynamicFormGuid) 
<# END: Dynamic Form #>

<# Begin: Delegated Form Access Groups and Categories #>
$delegatedFormAccessGroupGuids = @()
foreach($group in $delegatedFormAccessGroupNames) {
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/groups/$group")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        $delegatedFormAccessGroupGuid = $response.groupGuid
        $delegatedFormAccessGroupGuids += $delegatedFormAccessGroupGuid
        
        Write-ColorOutput Green "HelloID (access)group '$group' successfully found: $delegatedFormAccessGroupGuid"
    } catch {
        Write-ColorOutput Red "HelloID (access)group '$group', message: $_"
    }
}
$delegatedFormAccessGroupGuids = (ConvertTo-Json -InputObject $delegatedFormAccessGroupGuids -Compress)
$delegatedFormCategoryGuids = @()
foreach($category in $delegatedFormCategories) {
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories/$category")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid
        
        Write-ColorOutput Green "HelloID Delegated Form category '$category' successfully found: $tmpGuid"
    } catch {
        Write-ColorOutput Yellow "HelloID Delegated Form category '$category' not found"
        $body = @{
            name = @{"en" = $category};
        }
        $body = ConvertTo-Json -InputObject $body
        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid
        Write-ColorOutput Green "HelloID Delegated Form category '$category' successfully created: $tmpGuid"
    }
}
$delegatedFormCategoryGuids = (ConvertTo-Json -InputObject $delegatedFormCategoryGuids -Compress)
<# End: Delegated Form Access Groups and Categories #>

<# Begin: Delegated Form #>
$delegatedFormRef = [PSCustomObject]@{guid = $null; created = $null} 
$delegatedFormName = @'
Teams - Show Team Details
'@
Invoke-HelloIDDelegatedForm -DelegatedFormName $delegatedFormName -DynamicFormGuid $dynamicFormGuid -AccessGroups $delegatedFormAccessGroupGuids -Categories $delegatedFormCategoryGuids -UseFaIcon "True" -FaIcon "fa fa-question-circle" -returnObject ([Ref]$delegatedFormRef) 
<# End: Delegated Form #>

