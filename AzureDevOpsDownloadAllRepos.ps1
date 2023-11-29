$Organization = ""  #organization name
$Project = ""  #project name
$UserName = ""   # devops user name with out domain name
$PAT = ""   # devops personal access token
$ArchiveLocation = "c:\ProjectArchive"   # local drive path with drive letter 
 

$ADOHeaders = @{
  Authorization = 'Basic ' + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$PAT"))
  Accept = 'application/zip' 
}

new-item  $ArchiveLocation\$Project -itemtype directory
Set-Location -Path $ArchiveLocation\$Project

# download the TFVC repository if it exists


$tfvc = Invoke-RestMethod -Uri "https://dev.azure.com/$Organization/$Project/_apis/tfvc/items?api-version=7.0"  -Method Get -ContentType "application/json" -Headers $ADOHeaders 

if ($tfvc.count -ne "0")
{
    Invoke-WebRequest `
    -Uri "https://dev.azure.com/$Organization/$Project/_apis/tfvc/items?path=/&download=true&api-version=7.0" `
    -Headers $ADOHeaders `
    -OutFile $ArchiveLocation\$Project\TFVC-Repo-$Project.zip

}
else
{
   Write-output "** No TFVC repository found in the project $project **"
}

# Iterate through the repos

$repos = Invoke-RestMethod -Uri "https://dev.azure.com/$Organization/$Project/_apis/git/repositories?api-version=7.0" `
     -Headers $ADOHeaders 

if ($repos.value -eq $null)
{
    Write-Error 'No Repos in $project were found.' 
}
else
{

    foreach ($repo in $repos.value) {
      Write-output "* Processing GIT Repo:$repo.remoteUrl *"
      
      $projectName = $repo.project.name -replace '[^a-zA-Z0-9]', '-'
      $repoName = $repo.name -replace '[^a-zA-Z0-9]', '-'
      
      cd $ArchiveLocation\$Project
      git clone --quiet https://${UserName}:${PAT}@dev.azure.com/$Organization/$projectName/_git/$repoName  
 
      Compress-Archive -Path $ArchiveLocation\$Project\$repoName -DestinationPath $ArchiveLocation\$Project\GIT-Repo-$repoName.zip
      Remove-Item -LiteralPath $ArchiveLocation\$Project\$repoName  -Force -Recurse
    }

}

cd $ArchiveLocation
Write-output "* Zipping Project Folder *"
Compress-Archive -Path $ArchiveLocation\$Project  -DestinationPath $ArchiveLocation\$Project.zip -Force

Write-output "* Removing Project Folder *"
Remove-Item -LiteralPath $ArchiveLocation\$Project  -Force -Recurse

Write-output "* Finished *"


