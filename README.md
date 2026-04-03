# HelloID-Conn-SA-Full-Teams-ShowTeamDetails

| :information_source: Information                                                                                                                                                                                                                                                                                                                                                          |
|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible for acquiring the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

## Description
_HelloID-Conn-SA-Full-Teams-ShowTeamDetails_ is a template designed for use with HelloID Service Automation (SA) Delegated Forms. It can be imported into HelloID and customized according to your requirements.

By using this delegated form, you can inspect Microsoft Teams details and memberships through Microsoft Graph. The delegated form supports the following flow:
1. Search for and select an existing Microsoft Team
2. Retrieve and display team metadata (name, description, visibility, archive state, classification)
3. Retrieve and display team members filtered by role (member, owner, guest)

## Getting started
### Requirements

- **Microsoft Entra application registration (certificate-based)**:
  The connector authenticates to Microsoft Graph using a certificate (client credentials flow).
- **Microsoft Graph application permissions**:
  Configure and grant admin consent for the following minimal application permissions:
  - `GroupMember.Read.All`
  - `TeamMember.Read.Group`
  - `TeamSettings.Read.Group`

### Connection settings

The following user-defined variables are used by the connector.

| Setting                        | Description                                                                | Mandatory |
|--------------------------------|----------------------------------------------------------------------------|-----------|
| EntraIdTenantId                | Microsoft Entra tenant ID                                                  | Yes       |
| EntraIdAppId                   | Application (client) ID of the app registration                            | Yes       |
| EntraIdCertificateBase64String | Base64 encoded certificate (including private key) used for authentication | Yes       |
| EntraIdCertificatePassword     | Password for the certificate                                               | Yes       |

## Remarks

### Microsoft Graph Query Behavior
- `ConsistencyLevel: eventual` is added on Graph requests where advanced query capabilities are used (for example filtering and searching result sets).

### Read-only form behavior
- This form does not create, update, or delete Teams resources.

## Development resources

### API endpoints

The following endpoints are used by the connector.

| Endpoint                                                    | Description                                                             |
|-------------------------------------------------------------|-------------------------------------------------------------------------|
| `https://login.microsoftonline.com/{tenantId}/oauth2/token` | Retrieve OAuth2 access token using certificate-based client credentials |
| `https://graph.microsoft.com/v1.0/groups`                   | Search Teams-enabled groups                                             |
| `https://graph.microsoft.com/v1.0/teams/{teamId}`           | Retrieve team details                                                   |
| `https://graph.microsoft.com/v1.0/teams/{teamId}/members`   | Retrieve members of the selected team                                   |

### API documentation

- https://learn.microsoft.com/graph/api/overview
- https://learn.microsoft.com/graph/api/group-list
- https://learn.microsoft.com/graph/api/team-get
- https://learn.microsoft.com/graph/api/team-list-members

## Getting help
> :bulb: **Tip:**  
> _For more information on Delegated Forms, please refer to our [documentation](https://docs.helloid.com/en/service-automation/delegated-forms.html) pages_.

## HelloID docs
The official HelloID documentation can be found at: https://docs.helloid.com/