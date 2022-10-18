$groupId = $datasource.selectedgroup.GroupId

try {
    Write-Information -Message "Generating Microsoft Graph API Access Token user.."

    $baseUri = "https://login.microsoftonline.com/"
    $authUri = $baseUri + "$AADTenantID/oauth2/token"

    $body = @{
        grant_type      = "client_credentials"
        client_id       = "$AADAppId"
        client_secret   = "$AADAppSecret"
        resource        = "https://graph.microsoft.com"
    }

    $Response = Invoke-RestMethod -Method POST -Uri $authUri -Body $body -ContentType 'application/x-www-form-urlencoded'
    $accessToken = $Response.access_token;

    #Add the authorization header to the request
    $authorization = @{
        Authorization = "Bearer $accesstoken";
        'Content-Type' = "application/json";
        Accept = "application/json";
    }

    $baseSearchUri = "https://graph.microsoft.com/"
    $searchUri = $baseSearchUri + "v1.0/teams" + "/$groupId"        
    
    Write-Information -Message "Getting Team details."
    $teamsResponse = Invoke-RestMethod -Uri $searchUri -Method Get -Headers $authorization -Verbose:$false          

    $returnObject = @{DisplayName=$teamsResponse.DisplayName; Description=$teamsResponse.Description; Visibility=$teamsResponse.Visibility; Archived=$teamsResponse.IsArchived; GroupId=$teamsResponse.Id; MembershipLimitedToOwners=$teamsResponse.isMembershipLimitedToOwners; Classification = $teamsResponse.classification}
    Write-Output $returnObject        
    
}
catch
{
    Write-Error "Error getting Team Details. Error: $($_.Exception.Message)"
    Write-Warning -Message "Error getting Team Details"
    return
}

