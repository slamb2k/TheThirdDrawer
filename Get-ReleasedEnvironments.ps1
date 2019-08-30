# Requires installation of Donovan Brown's VS-Team
# https://github.com/DarqueWarrior/vsteam

# Account Details
$devopsAccount = "azure_devops_instance_name"
$devopsProject = "azure_devops_project_name"
$pat = "pat_key"

# Authenticate with a PAT
Set-VSTeamAccount -Account $devopsAccount -PersonalAccessToken $pat

# Get all of the releases from the SafeScript project and the stage/environments release
$Releases = Get-VSTeamRelease -ProjectName $devopsProject -expand environments

# Make some pretty headings
$ReleaseDefinition = @{l="Definition";e={$_.definitionName}}
$ReleaseName = @{l="Release Name";e={$_.name}}
$ReleaseDate = @{l="Release Date";e={$_.createdOn}}

# Get the furthest stage/environment that was successfully released
$Stage = @{
    l="Stage";
    e={
        For ($i=0; $i -le $_.environments.count; $i++) 
        { if( $_.environments[$i].status -ne "succeeded") {return $_.environments[$i].name} } 
      } 
    }

# Drop the phat dataz. The release uns are grouped by release definition and 
# sorted from latest to earliest. 
$Releases | Sort-Object definitionName, @{e={$_.createdOn}; a=0} `
| Select-Object $ReleaseDefinition, $ReleaseName, $ReleaseDate, $Stage

    
