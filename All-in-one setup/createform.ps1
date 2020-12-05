# Enforce TLS1.2 JK 20200722
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 
#HelloID variables
$PortalBaseUrl = "https://CUSTOMER.helloid.com"
$apiKey = "API_KEY"
$apiSecret = "API_SECRET"
$delegatedFormAccessGroupNames = @("Users", "HID_administrators")
 
# Create authorization headers with HelloID API key
$pair = "$apiKey" + ":" + "$apiSecret"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$key = "Basic $base64"
$headers = @{"authorization" = $Key}
# Define specific endpoint URI
if($PortalBaseUrl.EndsWith("/") -eq $false){
    $PortalBaseUrl = $PortalBaseUrl + "/"
}
 
 
function Write-ColorOutput($ForegroundColor) {
  $fc = $host.UI.RawUI.ForegroundColor
  $host.UI.RawUI.ForegroundColor = $ForegroundColor
  
  if ($args) {
      Write-Output $args
  }
  else {
      $input | Write-Output
  }

  $host.UI.RawUI.ForegroundColor = $fc
}


$variableName = "TeamsAdminUser"
$variableGuid = ""
try {
    $uri = ($PortalBaseUrl +"api/v1/automation/variables/named/$variableName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
 
    if([string]::IsNullOrEmpty($response.automationVariableGuid)) {
        #Create Variable
        $body = @{
            name = "$variableName";
            value = '<teamsadmin>@<customer>.onmicrosoft.com';
            secret = "false";
            ItemType = 0;
        }
 
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/automation/variable")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $variableGuid = $response.automationVariableGuid

        Write-ColorOutput Green "Variable '$variableName' created: $variableGuid"
    } else {
        $variableGuid = $response.automationVariableGuid
        Write-ColorOutput Yellow "Variable '$variableName' already exists: $variableGuid"
    }
} catch {
    Write-ColorOutput Red "Variable '$variableName'"
    $_
}

$variableName = "TeamsAdminPWD"
$variableGuid = ""
try {
    $uri = ($PortalBaseUrl +"api/v1/automation/variables/named/$variableName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
 
    if([string]::IsNullOrEmpty($response.automationVariableGuid)) {
        #Create Variable
        $body = @{
            name = "$variableName";
            value = '<Your Teams Admin Password>';
            secret = "true";
            ItemType = 0;
        }
 
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/automation/variable")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $variableGuid = $response.automationVariableGuid

        Write-ColorOutput Green "Variable '$variableName' created: $variableGuid"
    } else {
        $variableGuid = $response.automationVariableGuid
        Write-ColorOutput Yellow "Variable '$variableName' already exists: $variableGuid"
    }
} catch {
    Write-ColorOutput Red "Variable '$variableName'"
    $_
}


$taskName = "Teams-get-teams"
$taskGetTeamsGuid = ""
try {
    $uri = ($PortalBaseUrl +"api/v1/automationtasks?search=$taskName&container=1")
    $response = (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false) | Where-Object -filter {$_.name -eq $taskName}
 
    if([string]::IsNullOrEmpty($response.automationTaskGuid)) {
        #Create Task
 
        $body = @{
            name = "$taskName";
            useTemplate = "false";
            powerShellScript = @'
$filterDisplayName = $formInput.filterDisplayName
			
$connected = $false
try {
	Import-Module MicrosoftTeams
	$pwd = ConvertTo-SecureString -string $TeamsAdminPWD -AsPlainText –Force
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
		if([String]::IsNullOrEmpty($filterDisplayName) -eq $true) {
			$teams = Get-Team
		}
		else
		{
			$teams = Get-Team | where-object {$_.displayName -match $filterDisplayName}
		}

		if(@($teams).Count -gt 0){
		    foreach($team in $teams)
			{
				$addRow = @{DisplayName=$team.DisplayName; Description=$team.Description; MailNickName=$team.MailNickName; Visibility=$team.Visibility; Archived=$team.Archived; GroupId=$team.GroupId;}
				Hid-Add-TaskResult -ResultValue $addRow
			}
		}else{
			Hid-Add-TaskResult -ResultValue []
		}
	}
	catch
	{
		HID-Write-Status -Message "Error searching Teams. Error: $($_.Exception.Message)" -Event Error
		HID-Write-Summary -Message "Error searching Teams" -Event Failed
		Hid-Add-TaskResult -ResultValue []
	}
}
else
{
	Hid-Add-TaskResult -ResultValue []
}
'@;
            automationContainer = "1";
            variables = @()
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskGetTeamsGuid = $response.automationTaskGuid

        Write-ColorOutput Green "Powershell task '$taskName' created: $taskGetTeamsGuid"   
    } else {
        #Get TaskGUID
        $taskGetTeamsGuid = $response.automationTaskGuid
        Write-ColorOutput Yellow "Powershell task '$taskName' already exists: $taskGetTeamsGuid"
    }
} catch {
    Write-ColorOutput Red "Powershell task '$taskName'"
    $_
}


$dataSourceName = "Teams-get-teams"
$dataSourceGetTeamsGuid = ""
try {
    $uri = ($PortalBaseUrl +"api/v1/datasource/named/$dataSourceName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
 
    if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
        #Create DataSource
        $body = @{
            name = "$dataSourceName";
            type = "3";
            model = @(@{key = "DisplayName"; type = 0}, @{key = "Description"; type = 0}, @{key = "MailNickName"; type = 0}, @{key = "Visibility"; type = 0}, @{key = "Archived"; type = 0}, @{key = "GroupId"; type = 0});
            automationTaskGUID = "$taskGetTeamsGuid";
            input = @(@{description = "Filter for DisplayName"; translateDescription = "False"; inputFieldType = "1"; key = "filterDisplayName"; type = "0"; options = "0"})
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/datasource")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
         
        $dataSourceGetTeamsGuid = $response.dataSourceGUID
        Write-ColorOutput Green "Task data source '$dataSourceName' created: $dataSourceGetTeamsGuid"
    } else {
        #Get DatasourceGUID
        $dataSourceGetTeamsGuid = $response.dataSourceGUID
        Write-ColorOutput Yellow "Task data source '$dataSourceName' already exists: $dataSourceGetTeamsGuid"
    }
} catch {
    Write-ColorOutput Red "Task data source '$dataSourceName'"
    $_
} 


$taskName = "Teams-get-team-details"
$taskGetTeamsDetailsGuid = ""
try {
    $uri = ($PortalBaseUrl +"api/v1/automationtasks?search=$taskName&container=1")
    $response = (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false) | Where-Object -filter {$_.name -eq $taskName}
 
    if([string]::IsNullOrEmpty($response.automationTaskGuid)) {
        #Create Task
 
        $body = @{
            name = "$taskName";
            useTemplate = "false";
            powerShellScript = @'
$groupId = $formInput.selectedGroup.GroupId

$connected = $false
try {
	Import-Module MicrosoftTeams
	$pwd = ConvertTo-SecureString -string $TeamsAdminPWD -AsPlainText –Force
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
            automationContainer = "1";
            variables = @()
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskGetTeamsDetailsGuid = $response.automationTaskGuid

        Write-ColorOutput Green "Powershell task '$taskName' created: $taskGetTeamsDetailsGuid"   
    } else {
        #Get TaskGUID
        $taskGetTeamsDetailsGuid = $response.automationTaskGuid
        Write-ColorOutput Yellow "Powershell task '$taskName' already exists: $taskGetTeamsDetailsGuid"
    }
} catch {
    Write-ColorOutput Red "Powershell task '$taskName'"
    $_
}


$dataSourceName = "Teams-get-team-details"
$dataSourceGetTeamsDetailsGuid = ""
try {
    $uri = ($PortalBaseUrl +"api/v1/datasource/named/$dataSourceName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
 
    if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
        #Create DataSource
        $body = @{
            name = "$dataSourceName";
            type = "3";
            model = @(@{key = "DisplayName"; type = 0}, @{key = "Description"; type = 0}, @{key = "MailNickName"; type = 0}, @{key = "Visibility"; type = 0}, @{key = "Archived"; type = 0}, @{key = "GroupId"; type = 0});
            automationTaskGUID = "$taskGetTeamsDetailsGuid";
            input = @(@{description = ""; translateDescription = "False"; inputFieldType = "1"; key = "selectedGroup"; type = "0"; options = "0"})
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/datasource")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
         
        $dataSourceGetTeamsDetailsGuid = $response.dataSourceGUID
        Write-ColorOutput Green "Task data source '$dataSourceName' created: $dataSourceGetTeamsDetailsGuid"
    } else {
        #Get DatasourceGUID
        $dataSourceGetTeamsDetailsGuid = $response.dataSourceGUID
        Write-ColorOutput Yellow "Task data source '$dataSourceName' already exists: $dataSourceGetTeamsDetailsGuid"
    }
} catch {
    Write-ColorOutput Red "Task data source '$dataSourceName'"
    $_
} 



$taskName = "Teams-get-team-users"
$taskGetTeamsUsersGuid = ""
try {
    $uri = ($PortalBaseUrl +"api/v1/automationtasks?search=$taskName&container=1")
    $response = (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false) | Where-Object -filter {$_.name -eq $taskName}
 
    if([string]::IsNullOrEmpty($response.automationTaskGuid)) {
        #Create Task
 
        $body = @{
            name = "$taskName";
            useTemplate = "false";
            powerShellScript = @'
$groupId = $formInput.selectedGroup.GroupId
$role = $formInput.Role

$connected = $false
try {
	Import-Module MicrosoftTeams
	$pwd = ConvertTo-SecureString -string $TeamsAdminPWD -AsPlainText –Force
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
            automationContainer = "1";
            variables = @()
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskGetTeamsUsersGuid = $response.automationTaskGuid

        Write-ColorOutput Green "Powershell task '$taskName' created: $taskGetTeamsUsersGuid"   
    } else {
        #Get TaskGUID
        $taskGetTeamsUsersGuid = $response.automationTaskGuid
        Write-ColorOutput Yellow "Powershell task '$taskName' already exists: $taskGetTeamsUsersGuid"
    }
} catch {
    Write-ColorOutput Red "Powershell task '$taskName'"
    $_
}


$dataSourceName = "Teams-get-team-users"
$dataSourceGetTeamsUsersGuid = ""
try {
    $uri = ($PortalBaseUrl +"api/v1/datasource/named/$dataSourceName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
 
    if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
        #Create DataSource
        $body = @{
            name = "$dataSourceName";
            type = "3";
			model = @(@{key = "User"; type = 0}, @{key = "Name"; type = 0}, @{key = "Role"; type = 0}, @{key = "UserId"; type = 0});
            automationTaskGUID = "$taskGetTeamsUsersGuid";
            input = @(@{description = ""; translateDescription = "False"; inputFieldType = "1"; key = "selectedGroup"; type = "0"; options = "0"},
					@{description = ""; translateDescription = "False"; inputFieldType = "1"; key = "Role"; type = "0"; options = "0"})
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/datasource")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
         
        $dataSourceGetTeamsUsersGuid = $response.dataSourceGUID
        Write-ColorOutput Green "Task data source '$dataSourceName' created: $dataSourceGetTeamsUsersGuid"
    } else {
        #Get DatasourceGUID
        $dataSourceGetTeamsUsersGuid = $response.dataSourceGUID
        Write-ColorOutput Yellow "Task data source '$dataSourceName' already exists: $dataSourceGetTeamsUsersGuid"
    }
} catch {
    Write-ColorOutput Red "Task data source '$dataSourceName'"
    $_
} 


$formName = "Teams - Get Team Details"
$formGuid = ""
try
{
    try {
        $uri = ($PortalBaseUrl +"api/v1/forms/$formName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    } catch {
        $response = $null
    }
 
    if(([string]::IsNullOrEmpty($response.dynamicFormGUID)) -or ($response.isUpdated -eq $true))
    {
        #Create Dynamic form
        $form = @"
[
  {
    "label": "Select Team",
    "fields": [
      {
        "key": "filterDisplayName",
        "templateOptions": {
          "label": "Search for DisplayName",
          "required": false
        },
        "type": "input",
        "summaryVisibility": "Show",
        "requiresTemplateOptions": true
      },
      {
        "key": "teams",
        "templateOptions": {
          "label": "Select Team",
          "required": true,
          "grid": {
            "columns": [
              {
                "headerName": "Display Name",
                "field": "DisplayName"
              },
              {
                "headerName": "Description",
                "field": "Description"
              },
              {
                "headerName": "Mail Nick Name",
                "field": "MailNickName"
              },
              {
                "headerName": "Visibility",
                "field": "Visibility"
              },
              {
                "headerName": "Archived",
                "field": "Archived"
              },
              {
                "headerName": "Group Id",
                "field": "GroupId"
              }
            ],
            "height": 300,
            "rowSelection": "single"
          },
          "dataSourceConfig": {
            "dataSourceGuid": "$dataSourceGetTeamsGuid",
            "input": {
              "propertyInputs": [
                {
                  "propertyName": "filterDisplayName",
                  "otherFieldValue": {
                    "otherFieldKey": "filterDisplayName"
                  }
                }
			  ]
            }
          },
          "useFilter": false,
          "useDefault": false
        },
        "type": "grid",
        "summaryVisibility": "Show",
        "requiresTemplateOptions": true
      }
    ]
  },
  {
    "label": "Team Details",
    "fields": [
      {
        "key": "Details",
        "templateOptions": {
          "label": "Details",
          "required": false,
          "grid": {
            "columns": [
              {
                "headerName": "Name",
                "field": "name"
              },
              {
                "headerName": "Value",
                "field": "value"
              }
            ],
            "height": 300,
            "rowSelection": "single"
          },
          "dataSourceConfig": {
            "dataSourceGuid": "$dataSourceGetTeamsDetailsGuid",
            "input": {
              "propertyInputs": [
                {
                  "propertyName": "selectedGroup",
                  "otherFieldValue": {
                    "otherFieldKey": "teams"
                  }
                }
              ]
            }
          },
          "useDefault": false,
          "useFilter": false
        },
        "type": "grid",
        "summaryVisibility": "Show",
        "requiresTemplateOptions": true
      },
      {
        "key": "Members",
        "templateOptions": {
          "label": "Members",
          "required": false,
          "grid": {
            "columns": [
              {
                "headerName": "User",
                "field": "User"
              },
              {
                "headerName": "Name",
                "field": "Name"
              }
            ],
            "height": 300,
            "rowSelection": "single"
          },
          "dataSourceConfig": {
            "dataSourceGuid": "$dataSourceGetTeamsUsersGuid",
            "input": {
              "propertyInputs": [
                {
                  "propertyName": "Role",
                  "staticValue": {
                    "value": "Member"
                  }
                },
                {
                  "propertyName": "selectedGroup",
                  "otherFieldValue": {
                    "otherFieldKey": "teams"
                  }
                }
              ]
            }
          },
          "useFilter": true,
          "useDefault": false
        },
        "type": "grid",
        "summaryVisibility": "Show",
        "requiresTemplateOptions": true
      },
      {
        "key": "Owners",
        "templateOptions": {
          "label": "Members",
          "required": false,
          "grid": {
            "columns": [
              {
                "headerName": "User",
                "field": "User"
              },
              {
                "headerName": "Name",
                "field": "Name"
              }
            ],
            "height": 300,
            "rowSelection": "single"
          },
          "dataSourceConfig": {
            "dataSourceGuid": "$dataSourceGetTeamsUsersGuid",
            "input": {
              "propertyInputs": [
                {
                  "propertyName": "Role",
                  "staticValue": {
                    "value": "Owner"
                  }
                },
                {
                  "propertyName": "selectedGroup",
                  "otherFieldValue": {
                    "otherFieldKey": "teams"
                  }
                }
              ]
            }
          },
          "useFilter": true,
          "useDefault": false
        },
        "type": "grid",
        "summaryVisibility": "Show",
        "requiresTemplateOptions": true
      }
    ]
  }
]
"@
 
        $body = @{
            Name = "$formName";
            FormSchema = $form
        }
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/forms")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
 
        $formGuid = $response.dynamicFormGUID
        Write-ColorOutput Green "Dynamic form '$formName' created: $formGuid"
    } else {
        $formGuid = $response.dynamicFormGUID
        Write-ColorOutput Yellow "Dynamic form '$formName' already exists: $formGuid"
    }
} catch {
    Write-ColorOutput Red "Dynamic form '$formName'"
    $_
} 


$delegatedFormAccessGroupGuids = @()

foreach($group in $delegatedFormAccessGroupNames) {
    try {
        $uri = ($PortalBaseUrl +"api/v1/groups/$group")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
        $delegatedFormAccessGroupGuid = $response.groupGuid
        $delegatedFormAccessGroupGuids += $delegatedFormAccessGroupGuid
        
        Write-ColorOutput Green "HelloID (access)group '$group' successfully found: $delegatedFormAccessGroupGuid"
    } catch {
        Write-ColorOutput Red "HelloID (access)group '$group'"
        $_
    }
}


$delegatedFormName = "Teams - Show Team Details"
$delegatedFormGuid = ""
$delegatedFormCreated = $false
try {
    try {
        $uri = ($PortalBaseUrl +"api/v1/delegatedforms/$delegatedFormName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    } catch {
        $response = $null
    }
 
    if([string]::IsNullOrEmpty($response.delegatedFormGUID)) {
        #Create DelegatedForm
        $body = @{
            name = "$delegatedFormName";
            dynamicFormGUID = "$formGuid";
            isEnabled = "True";
            accessGroups = $delegatedFormAccessGroupGuids;
            useFaIcon = "True";
            faIcon = "fa fa-question-circle";
        }   
 
        $body = $body | ConvertTo-Json
 
        $uri = ($PortalBaseUrl +"api/v1/delegatedforms")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
 
        $delegatedFormGuid = $response.delegatedFormGUID
        Write-ColorOutput Green "Delegated form '$delegatedFormName' created: $delegatedFormGuid"
        $delegatedFormCreated = $true
    } else {
        #Get delegatedFormGUID
        $delegatedFormGuid = $response.delegatedFormGUID
        Write-ColorOutput Yellow "Delegated form '$delegatedFormName' already exists: $delegatedFormGuid"
    }
} catch {
    Write-ColorOutput Red "Delegated form '$delegatedFormName'"
    $_
}