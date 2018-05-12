<# 
#
#  EXAMPLE USAGE
#  -------------
#
#  Copy-VariableGroup -Uri "https://somecompany.visualstudio.com/SomeProject/" `
#                   -VariableGroupFrom "DeploymentVariables-Prod" `
#                   -VariableGroupTo "DeploymentVariables-Test" `
#                   -PersonalAccessToken "segizppinssssm3olvdccb2phj34ru7icdhm2utq6doyutyq"
#
#>

<# 
 .Synopsis
  Gets a variable group from VSTS given a project and name

 .Description
  Gets a variable group from VSTS given a project and name. The variable group will contain a collection of all of the contained parameters.
#>
function Get-VariableGroup() {
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$Uri,
        [string][parameter(Mandatory = $true)]$Name,
        [string][parameter(Mandatory = $false)]$PersonalAccessToken = [String]::Empty
    )
    BEGIN {
        $ErrorActionPreference = "Stop"

        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS {
        $Uri = "$($Uri.TrimEnd("/"))/_apis/distributedtask/variablegroups"

        $variableGroups = Invoke-VSTSMethod -Uri $Uri -PersonalAccessToken $PersonalAccessToken
        
        foreach ($variableGroup in $variableGroups.value) {
            if ($variableGroup.name -like $Name) {
                Write-Verbose "Variable group $Name found."
                return $variableGroup
            }
        }
        Write-Verbose "Variable group $Name not found."
        return $null
    }
    END { }
}

<# 
 .Synopsis
  A helper method for calling the VSTS REST API.

 .Description
  A helper method for calling the VSTS REST API.
#>
function Invoke-VSTSMethod() {
    param
    (
        [string][parameter(Mandatory = $true)]$Uri,
        [string][parameter(Mandatory = $false)]$Method = "GET",
        [string][parameter(Mandatory = $false)]$ContentType = "application/json",
        [string][parameter(Mandatory = $false)]$Body = [String]::Empty,
        [string][parameter(Mandatory = $false)]$PersonalAccessToken = [String]::Empty,
        [Hashtable][parameter(Mandatory = $false)]$Headers = @{}
    )

    $ErrorActionPreference = "Stop"

    $RestParams = @{      
        Uri         = $Uri.TrimEnd("/")      
        ContentType = $ContentType  
        Method      = $Method            
        Headers     = $Headers                  
    }        

    if ($Body) {
        $RestParams.Add("Body", $Body);
    }

    if ($PersonalAccessToken) {
        $SecurityContext = "PAT"
        $basicAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$PersonalAccessToken"))
        $RestParams.Headers["Authorization"] = ("Basic {0}" -f $basicAuth)
    }
    else {
        $SecurityContext = "Default"
        $RestParams.Add("UseDefaultCredentials", $true)
    }

    Write-Verbose "Invoking VSTS API [$SecurityContext]: $variableGroup"
    $Result = Invoke-RestMethod @RestParams

    return $Result
}

<# 
 .Synopsis
  Copies an existing variable group from VSTS to a new one given a project and variable group name.

 .Description
  Copies an existing variable group from VSTS to a new one given a project and variable group name. If the new variable group already exists it will be updated.
#>
function Copy-VariableGroup() {
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$Uri,
        [string][parameter(Mandatory = $true)]$VariableGroupFrom,
        [string][parameter(Mandatory = $true)]$VariableGroupTo,
        [string][parameter(Mandatory = $false)]$PersonalAccessToken = [String]::Empty
    )
    BEGIN {
        $ErrorActionPreference = "Stop"

        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS {
        # Get the variable group to copy
        Write-Host "`nCopying variable group from: $VariableGroupFrom"
        $variableGroup = Get-VariableGroup $Uri $VariableGroupFrom $PersonalAccessToken

        #Create the new variable group
        Write-Host "`nCopying variable group to: $VariableGroupTo"
        $newVariableGroup = @{name = $VariableGroupTo; description = $variableGroup.Description; variables = $variableGroup.variables; }

        Write-Verbose "Persist variable group $VariableGroupTo."
        $body = $newVariableGroup | ConvertTo-Json -Depth 10 -Compress
        $headers = @{ } #"Accept" = "application/json;api-version=5.0-preview.1"}
        $Uri = "$($Uri.TrimEnd("/"))/_apis/distributedtask/variablegroups?api-version=5.0-preview.1"        

        $response = Invoke-VSTSMethod -Uri $Uri -Method "POST" -Body $body -Headers $headers -PersonalAccessToken $PersonalAccessToken

        Write-Verbose "Variable group $VariableGroupTo created with id: $response.id."
        Write-Host "Copy operation complete."
    }
    END { }
}
