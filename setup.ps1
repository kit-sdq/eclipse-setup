# Invokes the command given and returns its output
function Get-Version {
Param([string]$Command)
Get-Command $Command | Select-Object Version
}

# Checks whether the given regex is matched by the given string. If not, prints the message and exits.
function Get-Condition {
Param($regex, $string, $message)
    if(-Not($string -match $regex)) {
        Writer $message
        Exit
    }
}

function Download {
Param($url, $dest)
Invoke-WebRequest -Uri $url -OutFile $dest
}


[scriptblock] $func = {
    function CreateFolder {
        Param($path)
        if(-Not(Test-Path -Path $path)) {
            New-Item -Name $path -Type Directory
        } else {Get-ChildItem -Path $path -Recurse | Remove-Item -force -recurse}
    }
    function Writer {
        Param($output)
        Write-Host $output
    }
}

Invoke-Command -NoNewScope -ScriptBlock $func


function InstallEclipse {
    Param($eclipsedownloadurl)
    #  download eclipse
    if(-Not(Test-Path -Path "eclipse.zip" -PathType Leaf)) {
        Writer "Download eclipse from $eclipsedownloadurl"
        Invoke-WebRequest -Uri $eclipsedownloadurl -OutFile "eclipse.zip"
    }
    Writer "Unzip eclipse. As a previous installation may already be configured, it is removed."
    Expand-Archive -LiteralPath eclipse.zip -DestinationPath .
    Writer "Unzipping completed"
}



function CloneBuildRepo {
    Param($project, $git)
    $url = $project.url
    $folder = $project.url -replace '.*/'
    $folder = $folder -replace '.git'
    $tag = $project.tag
    Writer "Clone $url into $git/$folder" 
    CreateFolder $git/$folder
    Set-Location $git
    git clone --branch $tag $url
    Set-Location $folder
    mvn clean verify
    Set-Location ../..
}

function FinishJob {
    Param($name)
    Wait-Job -Name $name
    $output = Receive-Job -Name $name
    Writer $output
    Remove-Job -Name $name
}
    



# Ask the user for consent, the script clears all information present in this folder
$title    = 'Setup eclipse'
$question = 'Are you sure you want to proceed? The setup will remove the contents of existing subfolders.'

$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 0) {
} else {
    Writer 'Aborted'
    Exit
}


# Main routine to check preconditions, install and configure eclipse
Writer "Installing Eclipse Modeling Tools, downloading and importing relevant plugins"
Get-Condition "17" (Get-Version "java") "Java 17 not found! Please ensure you have Java installed!"
Get-Condition "" (Get-Version "git") "Git not found!"
Get-Condition "" (Get-Version "mvn") "Maven not found! Please install maven, as the automatic installation is currently not supported"
$config = Get-Content -Raw -Path config.json | ConvertFrom-Json
$platform = Get-Content -Raw -Path platform.json | ConvertFrom-Json

#  create folders
$git = "git"
$eclipse = "eclipse"
$eclipseworkspace = "workspace"
CreateFolder $git
CreateFolder $eclipse
CreateFolder $eclipseworkspace


# Download eclipse
$downloadurl = $platform.eclipsedownloadurl
Start-Job -ArgumentList $downloadurl -ScriptBlock $Function:InstallEclipse -Name "install-eclipse"
# Start-Job -Name "install-eclipse" -ScriptBlock {}

# Download github repositories
Writer "Starting to download github repositories"
$projects = $config.projects
$counter = 1
foreach($project in $projects){
    Start-Job -ArgumentList $project,$git -ScriptBlock $Function:CloneBuildRepo -Name "project$counter" -InitializationScript $func
    $counter = $counter+1
}


# await eclipse unzipping completion
FinishJob "install-eclipse"

# provision eclipse
$eclipseExecutable = "$eclipse/eclipse.exe"
$updatesites = $platform.updatesite + "," + $config.updatesites -join ","
Write-Host $updatesites
$plugins = $config.plugins -join ","
Write-Host "Plugins $config.plugins"
Write-Host "Updatesites $updatesites $plugins"
# Start-Job -ArgumentList  -ScriptBlock $Function:CloneBuildRepo -Name "project$counter" -InitializationScript $func
# Invoke-Expression $eclipseExecutable




# await repository cloning and building
for ($i = 1; $i -lt $counter; $i++) {
    FinishJob "project$i"
}





# /usr/eclipse/eclipse \
#     -application org.eclipse.equinox.p2.director \
#     -repository https://download.eclipse.org/releases/2023-09/,"$2" \
#     -installIU "$1"

# Install Xtext from the Eclipse Marketplace.

# Install features required for your use case from the Vitruv nightly update site.

# Clone project
# build projects
# import projects into eclipse workspace

# A proper configuration especially concerns the workspace encoding, 
# which must be set to UTF-8 (especially important for windows users), and a proper Java compiler compliance level, which should be set to 17!!!
Write-Host "Finished"