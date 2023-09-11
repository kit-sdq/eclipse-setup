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

[scriptblock] $func = {
    function CreateFolder {
        Param($path)
        if(-Not(Test-Path -Path $path)) {
            New-Item -Name $path -Type Directory
        } else {
            # add choice if folder content should be removed
            Get-ChildItem -Path $path -Recurse | Remove-Item -force -recurse}
    }
    function Writer {
        Param($output)
        Write-Host $output
    }
    function Download {
        Param($url, $dest)
        Invoke-WebRequest -Uri $url -OutFile $dest
        }
}

Invoke-Command -NoNewScope -ScriptBlock $func


function InstallEclipse {
    Param($eclipsedownloadurl)
    #  download eclipse
    if(-Not(Test-Path -Path "eclipse.zip" -PathType Leaf)) {
        Writer "Download eclipse from $eclipsedownloadurl"
        Download $eclipsedownloadurl "eclipse.zip"
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
    mvn clean verify -fae
    Set-Location ../..
}

function InstallPlugin {
    Param($repository, $installTargetFeatureGroup)
    $tag=$installTargetFeatureGroup + "Installation" -join "-"
    eclipse/eclipsec.exe -nosplash -application "org.eclipse.equinox.p2.director" -repository $repository -installIU $installTargetFeatureGroup -tag $tag
}

function FinishJob {
    Param($name)
    Wait-Job -Name $name
    $output = Receive-Job -Name $name
    Writer $output
    Remove-Job -Name $name
}

function ConvertToKeyStrokes {
    param([int[]]$indices)
    $return = "{TAB}{TAB}{TAB}{TAB}{TAB}{TAB}{ENTER}+{TAB}+{TAB}"
    for ($i = 0; $i -le $indices[$indices.Count-1]; $i++) {
        $a = $indices -contains $i
        if($indices -contains $i) {
            $return += " {DOWN}"
        } else {
            $return += "{DOWN}"
        }
    }
    $return += "{TAB}{TAB}{TAB}{ENTER}"
    return $return
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
$existingfolders = @()
$gitExists = Test-Path $git
$eclipseExists = Test-Path $eclipse
$eclipseworkspaceExists = Test-Path $eclipseworkspace
if($gitExists -eq 0){
    # CreateFolder $git
} else {
    $existingfolders += @($git)
}
if($eclipseExists -eq 0){
    # CreateFolder $eclipse
} else {
    $existingfolders += @($eclipse)
}
if($eclipseworkspaceExists -eq 0){
    # CreateFolder $eclipseworkspace
} else {
    $existingfolders += @($eclipseworkspace)
}

# Asks user if he wants to overwrite folders if they exist or if the existing folders should be used
if($existingfolders.length -gt 0){
    $question = 'The folder(s) ' + $existingfolders + ' already exist. Do you want do overwrite them? (All current content of these folders gets deleted!)'

    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
    if ($decision -eq 0) {
        # CreateFolder $git
        # CreateFolder $eclipse
        # CreateFolder $eclipseworkspace
    } else {
        $question = 'Should the content be written into the existing folders? Existing content will remain.'

        $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
    
        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
        
        if ($decision -eq 0) {
        } else {
            Writer 'Aborted'
            Exit
        }
    }
}


# Download eclipse
$downloadurl = $platform.eclipsedownloadurl
# Start-Job -ArgumentList $downloadurl -ScriptBlock $Function:InstallEclipse -Name "install-eclipse" -InitializationScript $func

# Download github repositories
Writer "Starting to download github repositories"
$projects = $config.projects
$counterproject = 1
foreach($project in $projects){
    # Start-Job -ArgumentList $project,$git -ScriptBlock $Function:CloneBuildRepo -Name "project$counterproject" -InitializationScript $func
    $counterproject = $counterproject+1
}

# await eclipse unzipping completion
FinishJob "install-eclipse"

# sets the new workspace as the default workspace
$absoluteworkspace = Resolve-Path -Path $eclipseworkspace
Write-Host $absoluteworkspace
$Content = get-content eclipse\configuration\config.ini
$NewContent = $Content -replace 'osgi.instance.area.default=.*', "osgi.instance.area.default=$absoluteworkspace"
$NewContent | Set-Content eclipse\configuration\config.ini

$Content = get-content eclipse\eclipse.ini
$NewContent = $Content -replace 'osgi.instance.area.default=.*', "osgi.instance.area.default=$absoluteworkspace"
$NewContent | Set-Content eclipse\eclipse.ini

# provision eclipse
$temp = $config.updatesites -Join ","
$updatesites = $platform.updatesite + "," + $temp
Write-Host $updatesites
$plugins = $config.plugins
$pluginstring = ""
$counter = 1
foreach($plugin in $plugins) {
    $name = $plugin.name
    $version = $plugin.version
    if ($version -eq "") {
        $pluginstring += "$name,"
    } else {
        $pluginstring += "$name/$version,"
    }
    $counter = $counter+1
}
# Start-Job -ArgumentList $updatesites,$pluginstring -ScriptBlock $Function:InstallPlugin -Name "plugin" -InitializationScript $func

# await plugin installation
FinishJob "plugin"

# Problems with the headlessbuild remain
# eclipse\eclipsec.exe -vm "C:/Program Files/Java/jdk-20/bin/server/jvm.dll" -vmargs -application "org.eclipse.cdt.managedbuilder.core.headlessbuild" -import "git\Vitruv-Change\bundles" -data "workspace"

# await project builds
for ($i = 1; $i -lt $counterproject; $i++) {
    FinishJob "project$i"
}

add-type -AssemblyName microsoft.VisualBasic
add-type -AssemblyName System.Windows.Forms
foreach($project in $projects){
    $projectplugins = $project.projectplugins
    $url = $project.url
    $folder = $project.url -replace '.*/'
    $folder = $folder -replace '.git'
    Writer "Clone $url into $git/$folder" 
    $localfolder = "$git/$folder"
    $WindowTitle = "workspace - Eclipse IDE"
    
    eclipse/eclipse.exe $localfolder
    Start-Sleep 5
    # only select the plugins to be imported
    start-sleep -Milliseconds 500
    $config = ConvertToKeyStrokes $projectplugins
    Write-Host $config
    [Microsoft.VisualBasic.Interaction]::AppActivate($WindowTitle)
    [System.Windows.Forms.SendKeys]::SendWait($config)
    Start-Sleep 10
    $counterproject = $counterproject+1
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