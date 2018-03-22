<# 
#
#  EXAMPLE USAGE
#  -------------
#
#  Copy-VariableGroup -Uri "https://blah.visualstudio.com/Stuff%20and%20Bits/" `
#                   -VariableGroupFrom "KnightRider Load Environment Configuration" `
#                   -VariableGroupTo "KnightRider Special Test Environment Configuration" `
#                   -PersonalAccessToken "tbs55zas7c2yx2nhdjxwro5vieqq4hdcq4mgrpf6mtr5txlvxnmq"
#
#>


<# 
 .Synopsis
  Adds a new variable group variable to a VSTS project.

 .Description
  Adds a new variable group variable to a VSTS project. If the variable group doesn't exist, it will be created.
#>
function Add-VariableGroupVariable()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$Uri,
        [string][parameter(Mandatory = $true)]$VariableGroupName,
        [string]$VariableGroupDescription,
        [string][parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][Alias("name")]$VariableName,
        [string][parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][Alias("value")]$VariableValue,
        [bool][parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]$Secret,
        [string][parameter(Mandatory = $false)]$PersonalAccessToken = [String]::Empty,
        [switch]$Reset,
        [switch]$Force
    )
    BEGIN
    {
        $ErrorActionPreference = "Stop"

        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
 
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
        $method = "Post"
        $variableGroup = Get-VariableGroup $Uri $VariableGroupName $PersonalAccessToken
 
        if($variableGroup)
        {
            Write-Verbose "Variable group $VariableGroupName exists."
 
            if ($Reset)
            {
                Write-Verbose "Reset = $Reset : remove all variables."
                foreach($prop in $variableGroup.variables.PSObject.Properties.Where{$_.MemberType -eq "NoteProperty"})
                {
                    $variableGroup.variables.PSObject.Properties.Remove($prop.Name)
                }
            }
 
            $id = $variableGroup.id
            $restApi = "$($Uri)/_apis/distributedtask/variablegroups/$id"
            $method = "Put"
        }
        else
        {
            Write-Verbose "Variable group $VariableGroupName not found."
            if ($Force)
            {
                Write-Verbose "Create variable group $VariableGroupName."
                $variableGroup = @{name=$VariableGroupName;description=$VariableGroupDescription;variables=New-Object PSObject;}
                $restApi = "$($Uri)/_apis/distributedtask/variablegroups?api-version=3.2-preview.1"
            }
            else
            {
                throw "Cannot add variable to nonexisting variable group $VariableGroupName; use the -Force switch to create the variable group."
            }
        }
    }
    PROCESS
    {
        Write-Verbose "Adding $VariableName with value $VariableValue..."
        $variableGroup.variables | Add-Member -Name $VariableName -MemberType NoteProperty -Value @{value=$VariableValue;isSecret=$Secret} -Force
    }
    END
    {
        Write-Verbose "Persist variable group $VariableGroupName."
        $body = $variableGroup | ConvertTo-Json -Depth 10 -Compress
        $headers = @{"Accept" = "application/json;api-version=3.2-preview.1"}

        $response = Invoke-VSTSMethod -Uri $Uri -Method "PUT" -Body $body -Headers $headers
        
        return $response.id
    }
}

<# 
 .Synopsis
  Gets a variable group from VSTS given a project and name

 .Description
  Gets a variable group from VSTS given a project and name. The variable group will contain a collection of all of the contained parameters.
#>
function Get-VariableGroup()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$Uri,
        [string][parameter(Mandatory = $true)]$Name,
        [string][parameter(Mandatory = $false)]$PersonalAccessToken = [String]::Empty
    )
    BEGIN
    {
        $ErrorActionPreference = "Stop"

        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        $Uri = $Uri.TrimEnd("/")
        $Uri = "$($Uri)/_apis/distributedtask/variablegroups"

        $variableGroups = Invoke-VSTSMethod -Uri $Uri -PersonalAccessToken $PersonalAccessToken
        
        foreach($variableGroup in $variableGroups.value){
            if ($variableGroup.name -like $Name){
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
function Invoke-VSTSMethod()
{
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
        Method = $Method            
        ContentType = $ContentType  
        Headers = $Headers                  
    }        

    if ($Body)
    {
        $RestParams.Add("Body", $Body);
    }

    if ($PersonalAccessToken)
    {
        $SecurityContext = "PAT"
        $basicAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$PersonalAccessToken"))
        $RestParams.Headers["Authorization"] = ("Basic {0}" -f $basicAuth)
    }
    else
    {
        $SecurityContext = "Default"
        $RestParams.Add("UseDefaultCredentials", $true)
    }

    $Uri = $Uri.TrimEnd("/")

    Write-Verbose "Invoking VSTS API [$SecurityContext]: $variableGroup"
    $Result = Invoke-RestMethod $Uri @RestParams -ErrorVariable RestError -ErrorAction SilentlyContinue
        
    if ($RestError)
    {
        $HttpStatusCode = $RestError.ErrorRecord.Exception.Response.StatusCode.value__
        $HttpStatusDescription = $RestError.ErrorRecord.Exception.Response.StatusDescription
    
        Throw "Http Status Code: $($HttpStatusCode) `nHttp Status Description: $($HttpStatusDescription)"
    }

    return $Result
}

<# 
 .Synopsis
  Copies an existing variable group from VSTS to a new one given a project and variable group name.

 .Description
  Copies an existing variable group from VSTS to a new one given a project and variable group name. If the new variable group already exists it will be updated.
#>
function Copy-VariableGroup()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$Uri,
        [string][parameter(Mandatory = $true)]$VariableGroupFrom,
        [string][parameter(Mandatory = $true)]$VariableGroupTo,
        [string][parameter(Mandatory = $false)]$PersonalAccessToken = [String]::Empty
    )
    BEGIN
    {
        $ErrorActionPreference = "Stop"

        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        $basicAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$PersonalAccessToken"))
        
        $variableGroup = Get-VariableGroup $Uri $VariableGroupFrom $PersonalAccessToken

        Write-Host "`nCopying variable group from: $VariableGroupFrom"

        foreach ($variable in $variableGroup) 
        {
            $properties = $variable.variables | Get-Member -MemberType NoteProperty
            
            foreach ($property in $properties)
            {
                $propertyName = $property.Name
                $propValue = $variable.variables | Select-Object -ExpandProperty $property.Name

                Add-VariableGroupVariable -Uri $Uri `
                                            -VariableGroupName $VariableGroupTo `
                                            -VariableName $property.Name `
                                            -VariableValue $propValue.value `
                                            -PersonalAccessToken $PersonalAccessToken `
                                            -Force `
                                            | Out-Null

                Write-Host "Cloned child variable: $propertyName"
            }
        }

        Write-Host "Variable group copied to: $VariableGroupTo"
        Write-Host "Copy operation complete."
    }
    END { }
}

