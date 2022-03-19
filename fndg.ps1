
###########################################
#   Freifunk Nodes Docu Generator (FNDG)  #
#  powered by www.freifunk-nordhessen.de  #
###########################################

# include your personal settings - use template provided at config_example.ps1
. .\config_example.ps1

Add-Type -AssemblyName System.Web

# forked some functions from the MediaWiki API
# credits to https://en.wikiversity.org/wiki/MediaWiki_API/PowerShell

# ****

function Get-CsrfToken()
{
    if($csrftoken -eq $null)
    {
        $uri = $protocol + $wiki + $api

        if((Get-Version) -lt '1.24')
        {
            $uri = $protocol + $wiki + $api

            $body = @{}
            $body.action = 'query'
            $body.format = 'json'
            $body.prop = 'info'
            $body.intoken = 'edit'
            $body.titles = 'User:' + $username

            $object = Invoke-WebRequest $uri -Method Get -Body $body -WebSession (Get-WebSession)
            $json = $object.Content
            $object = ConvertFrom-Json $json

            $pages = $object.query.pages
            $page = ($pages | Get-Member -MemberType NoteProperty).Name
            $csrftoken = $pages.($page).edittoken
        }
        else
        {
            $body = @{}
            $body.action = 'query'
            $body.format = 'json'
            $body.meta = 'tokens'
            $body.type = 'csrf'

            $object = Invoke-WebRequest $uri -Method Get -Body $body -WebSession (Get-WebSession)
            $json = $object.Content
            $object = ConvertFrom-Json $json

            $csrftoken = $object.query.tokens.csrftoken
        }
    }

    return $csrftoken
}

function Get-Version()
{
    if($wikiversion -eq $null)
    {
        $uri = $protocol + $wiki + $api

        $body = @{}
        $body.action = 'query'
        $body.format = 'json'
        $body.meta = 'siteinfo'
        $body.siprop = 'general'

        $object = Invoke-WebRequest $uri -Method Get -Body $body -WebSession (Get-WebSession)
        $json = $object.Content
        $object = ConvertFrom-Json $json

        $wikiversion = $object.query.general.generator
        $wikiversion = $wikiversion -replace 'MediaWiki ', ''
    }

    return $wikiversion
}

function Get-WebSession()
{
    if($websession -eq $null)
    {
        Invoke-LogIn $username $password
    }
    return $websession
}

function Invoke-Login($username, $password)
{
    $uri = $protocol + $wiki + $api

    $body = @{}
    $body.action = 'login'
    $body.format = 'json'
    $body.lgname = $username
    $body.lgpassword = $password

    $object = Invoke-WebRequest $uri -Method Post -Body $body -SessionVariable global:websession
    $json = $object.Content
    $object = ConvertFrom-Json $json

    if($object.login.result -eq 'NeedToken')
    {
        $uri = $protocol + $wiki + $api

        $body.action = 'login'
        $body.format = 'json'
        $body.lgname = $username
        $body.lgpassword = $password
        $body.lgtoken = $object.login.token

        $object = Invoke-WebRequest $uri -Method Post -Body $body -WebSession $global:websession
        $json = $object.Content
        $object = ConvertFrom-Json $json
    }
    if($object.login.result -ne 'Success')
    {
        throw ('Login.result = ' + $object.login.result)
    }
}

function Invoke-Logout()
{
    $uri = $protocol + $wiki + $api
    
    $body = @{}
    $body.action = 'logout'
    $body.format = 'json'

    $object = Invoke-WebRequest $uri -Method Get -Body $body -WebSession (Get-WebSession)
    
    Clear-Session
}

function Get-AllPages($prefix, $namespace)
{
    $uri = $protocol + $wiki + $api
    
    $body = @{}
    $body.action = 'query'
    $body.format = 'json'
    $body.list = 'allpages'
    $body.aplimit = 'max'
    $body.apfilterredir = 'nonredirects'

    if($prefix.length -gt 0)
    {
        $body.apprefix = $prefix
    }    
    if($namespace.length -gt 0)
    {
        $body.apnamespace = $namespace
    }

    $result = @()

    $object = Invoke-WebRequest $uri -Method Get -Body $body -WebSession (Get-WebSession)
    $json = $object.Content
    $object = ConvertFrom-Json $json
    $allpages = $object.query.allpages

    foreach($entry in $allpages)
    {
        $result += $entry | Select-Object title
    }

    return $result
}

function Add-Section($title, $summary, $text)
{
    $uri = $protocol + $wiki + $api

    if (($Text -eq $FALSE) -or ($Text -eq '')) {$Text = 'n/a'}
    
    $body = @{}
    $body.action = 'edit'
    $body.format = 'json'
    $body.bot = ''
    $body.title = $title
    $body.section = 'new'
    $body.summary = $summary
    $body.text = $text
    $body.token = Get-CsrfToken

    $object = Invoke-WebRequest $uri -Method Post -Body $body -WebSession (Get-WebSession)
    $json = $object.Content
    $object = ConvertFrom-Json $json
    if($object.edit.result -ne 'Success')
    {
        throw('Error adding section:' + $object + ',' + $object.error)

    }
}

function Get-Page($title)
{
    $uri = $protocol + $wiki + 'index.php'
    
    $body = @{}
    $body.action = 'raw'
    $body.title = $title

    try
    {
        $object = Invoke-WebRequest $uri -Method Get -Body $body -WebSession (Get-WebSession)
        $result = $object.Content
    }
    catch [Net.WebException] 
    {
        if($error.Exception.ToString().IndexOf('404') -lt 0)
        {
            #throw('Unexpected message returned from Get-Page ' + $title + ': ' + $error.Exception.ToString())
            return $FALSE
        }
        $result = ''
    }
    return $result
}

function Edit-Page($title, $summary, $text)
{
    $uri = $protocol + $wiki + $api

    $body = @{}
    $body.action = 'edit'
    $body.format = 'json'
    $body.bot = ''
    $body.title = $title
    $body.summary = $summary
    $body.text = $text
    $body.token = Get-CsrfToken

    $object = Invoke-WebRequest $uri -Method Post -Body $body -WebSession (Get-WebSession)
    $json = $object.Content
    $object = ConvertFrom-Json $json

    if($object.edit.result -ne 'Success')
    {
        throw('Error editing page:' + $object + ',' + $object.error)
    }
}

# ****

Function Get-Section($type, $content)
{
    $Parse = $FALSE    
    $Result = New-Object System.Collections.ArrayList  
    $Splitted_Content = $content.Split([Environment]::NewLine)

    ForEach ($Line in $Splitted_Content)
    {

        if ($Line -like "==*") 
        {
            #if ($Line -like $MatchString) {$Parse = $TRUE}
            if ($Line -like "*$Type*") 
            {
                # start saving the next coming lines
                $Parse = $TRUE
                
                # skip current line
                continue
            }
            else 
            {
                # do not parse anymore
                $Parse = $FALSE
            }
        }

        if ($Parse -eq $TRUE)
        {
            $Result += $Line
        }
    }
    
    if ($Result.Count -eq 0) {Return $FALSE}
    else {Return $Result}      
}



# A Powershell Excel Module is available for free for Windows, Linux & macOS
# Use PS Admin account and install it if needed: 
# Install-module PSExcel

Import-Module PSExcel

# tidy up console
Clear-Host

# send welcome messange
Write-Host "*********************************************"
Write-Host "Starting Freifunk Nodes Docu Generator (FNDG)"
Write-Host "*********************************************"
Write-Host ""
Write-Host "Path to Routerfile  = $RouterFile"

# Import Routerlist
$Excelfile = Import-XLSX -Path "$RouterFile"

# Generate Router Pages in Wiki
# one page per router
ForEach ($Item in $Excelfile)
{
    # set page ID       
    $Title = $Wikimedia_RouterID_Prefix+$Item.DeviceID               

    # message to the user
    Write-Host "Now parsing router $Title"

    # backup current page
    $Backup = Get-Page $Title

    # if page is available, remember sections Bilder and Notizen
    if ($Backup -ne $FALSE)
    {
        $Backup_Local_Pictures = Get-Section "Bilder" "$Backup"
        $Backup_Local_Notes = Get-Section "Notizen" "$Backup"
    }
      
    # clear page in wiki
    Edit-Page "$Title" "" ""

    # ##########################################
    # Section: == verantwortlicher Admin ==        
    # ##########################################
    $Summary = '== verantwortlicher Admin =='
    $Text = $Wikimedia_Admin_String       
    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Gerät ==
    # ##########################################
    $Summary = '== Gerät =='
    $Text = '<ul>'
    $Text = $Text + '<li>'+$Title+' - '+$Item.Type+'</li>'
    $Text = $Text + '<li>'+$Item.Name+'</li>'   
    $Text = $Text + '</ul>'
    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Eigentümer / Sponsor ==
    # ##########################################
    $Summary = '== Eigentümer / Sponsor =='
    $Text = $Item.Owner
    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Kontakt vor Ort ==
    # ##########################################
    $Summary = '== Kontakt vor Ort =='
    $Text = '<ul>'
    $Text = $Text + '<li>'+$Item.LocalContactName+'</li>'
    $Text = $Text + '<li>'+$Item.LocalContactPhone+'</li>'
    $Text = $Text + '<li>'+$Item.LocalContactMail+'</li>'
    $Text = $Text + '</ul>'
    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Standort ==
    # ##########################################
    $Summary = '== Standort =='
    $Text = '[['+$Item.Location+', '+$Item.District+']]'
    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Kartenlink ==
    # ##########################################
    $Summary = '== Kartenlink =='
    $Text = '['+$Item.MapLink+']'
    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Konfiguration ==
    # ##########################################
    $Summary = '== Konfiguration =='
    $Text = '<ul>'
    $Text = $Text + '<li>Domain: '+$Item.Domain+'</li>'
    $Text = $Text + '<li>Speedlimit: '+$Item.Speedlimit+'</li>'
    $Text = $Text + '<li>Branch: '+$Item.Branch+'</li>'
    $Text = $Text + '<li>Autoupdater: '+$Item.Autoupdater+'</li>'
    $Text = $Text + '<li>SSHKeys: '+$Item.SSHKeys+'</li>'
    $Text = $Text + '<li>Release: '+$Item.Release+'</li>'
    $Text = $Text + '<li>VLAN: '+$Item.VLAN+'</li>'       
    $Text = $Text + '</ul>'
    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Beschreibung ==
    # ##########################################
    $Summary = '== Beschreibung =='
    $Text = $Item.Notes
    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Bilder ==
    # ##########################################
    $Summary = '== Bilder =='
        
    # if we've got some pictures in our backup variable, we'll deploy that content here
    # otherwise we'll put a text hint here
    if ($Backup_Local_Pictures -eq $FALSE)
    {
        $Text = 'Hier können Fotos als Galerie oder Einzelbilder zum Gerät hinterlegt werden. Die Sektion ist updatefest.'
    }
    else
    {
        $Text = $Backup_Local_Pictures | Out-String
    }        
    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Notizen ==
    # ##########################################
    $Summary = '== Notizen =='

    # if we've got some notes in our backup variable, we'll deploy that content here
    # otherwise we'll put a text hint here        
    if ($Backup_Local_Notes -eq $FALSE)
    {
        $Text = 'Hier können Notizen zum Gerät hinterlegt werden. Die Sektion ist updatefest.'
    }
    else
    {
        $Text = $Backup_Local_Notes | Out-String
    }        
    Add-Section "$Title" "$Summary" "$Text"

}

# Now we've got one page per router in our excelfile
# Next: let's create one per location, based on our excelfile

# Generate Location pages
$AllLocations = New-Object System.Collections.ArrayList

# get all locations from excelfile
ForEach ($Item in $Excelfile)
{
    # check this location
    $Candidate = $Item.Location+', '+$Item.District
    
    # add unknown location
    if (!($AllLocations -contains $Candidate))
    {
        $NULL = $AllLocations.add($Candidate)
    }
}

# parse location list
ForEach ($Location in $AllLocations)
{
    
    # set page ID       
    $Title = $Location

    # message to the user
    Write-Host "Now parsing location $Title"

    # backup current page
    $Backup = Get-Page $Title

    # do we have pictures or notes?
    if ($Backup -ne $FALSE)
    {
        $Backup_Local_Pictures = Get-Section "Bilder" "$Backup"
        $Backup_Local_Notes = Get-Section "Notizen" "$Backup"
    }

    # clear page
    Edit-Page "$Title" "" ""

    # ##########################################
    # Section: == verantwortlicher Admin ==        
    # ##########################################
    $Summary = '== verantwortlicher Admin =='
    $Text = $Wikimedia_Admin_String       
    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Gerät/Geräte ==
    # ##########################################
    $Summary = '== Gerät/Geräte =='
    $Text = '<ul>'

    # list all routers on this location
    ForEach ($Item in $Excelfile)
    {
        $Candidate = $Item.Location+', '+$Item.District

        if ($Candidate -match $Location)
        {
            $Text = $Text + '<li>[['+$Wikimedia_RouterID_Prefix+$Item.DeviceID+'|'+$Wikimedia_RouterID_Prefix+$Item.DeviceID+' - '+$Item.Type+']]</li>'
        }             
    }
        
    $Text = $Text + '</ul>'
    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Standort / Anschrift ==
    # ##########################################
    $Summary = '== Standort / Anschrift =='
    $Text = $Title
    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Kontakt vor Ort ==
    # ##########################################
    $Summary = '== Kontakt vor Ort =='
    $Text = '<ul>'

    # get all local contacts 
    $AllLocalContacts = New-Object System.Collections.ArrayList

    # in very rare cases, we might have more than one contact at a location
    # this is to list them all - but: do not list duplicates        
    ForEach ($Item in $Excelfile)
    {
        $Candidate = $Item.Location+', '+$Item.District

        # if this router is at our current $location
        if ($Candidate -match $Location)
        {

            # get contact data
            $LocalContactData = New-Object -TypeName PSObject -Property @{
                LocalContactName = $Item.LocalContactName
                LocalContactMail = $Item.LocalContactMail
                LocalContactPhone = $Item.LocalContactPhone
            }

            # check if we've already printed this contact data
            if (!($AllLocalContacts.LocalContactName -contains $LocalContactData.LocalContactName))
            {
                # add contact to list - so we know we don't have to show this data set again
                $NULL = $AllLocalContacts.add($LocalContactData)                                      
            }

        }
    }

    # list all contacts - without duplicates
    ForEach ($Contact in $AllLocalContacts)
    {
        $Text = $Text + '<li>'+$Contact.LocalContactName+'</li>'
        $Text = $Text + '<li>'+$Contact.LocalContactMail+'</li>'
        $Text = $Text + '<li>'+$Contact.LocalContactPhone+'</li>'
    }
    $Text = $Text + '</ul>'

    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Bilder ==
    # ##########################################
    $Summary = '== Bilder =='

    # deploy pictures on location        
    if ($Backup_Local_Pictures -eq $FALSE)
    {
        $Text = 'Hier können Fotos als Galerie oder Einzelbilder hinterlegt werden. Die Sektion ist updatefest.'
    }
    else
    {
        $Text = $Backup_Local_Pictures | Out-String
    }
        
    Add-Section "$Title" "$Summary" "$Text"

    # ##########################################
    # Section: == Notizen ==
    # ##########################################
    $Summary = '== Notizen =='
        
    # deploy notes section on location
    if ($Backup_Local_Notes -eq $FALSE)
    {
        $Text = 'Hier können Notizen zum Standort hinterlegt werden. Die Sektion ist updatefest.'
    }
    else
    {
        $Text = $Backup_Local_Notes | Out-String
    }
        
    Add-Section "$Title" "$Summary" "$Text"


}


# Generate location overview page

# do we have to generate a overview page containing all locations
if (($Wikimedia_Overview_Page -ne $FALSE) -or ($Wikimedia_Overview_Page.Length -ne 0))
{
    # set page ID       
    $Title = $Wikimedia_Overview_Page

    # message to user
    Write-Host "Now generating overview page $Title"

    # backup current page
    $Backup = Get-Page $Title

    if ($Backup -ne $FALSE)
    {
        $Backup_Local_Pictures = Get-Section "Bilder" "$Backup"
        $Backup_Local_Notes = Get-Section "Notizen" "$Backup"
    }

    # clear page
    Edit-Page "$Title" "" ""

    # Section: == Notizen ==
    $Summary = '== Notizen =='

    # deploy notes        
    if ($Backup_Local_Notes -eq $FALSE)
    {
        $Text = 'Hier können Notizen zur Übersichtsseite hinterlegt werden. Die Sektion ist updatefest.'
    }
    else
    {
        $Text = $Backup_Local_Notes | Out-String
    }
        
    Add-Section "$Title" "$Summary" "$Text"


    # ##########################################
    # Section: == Bilder ==
    # ##########################################
    $Summary = '== Bilder =='

    # deploy pictures        
    if ($Backup_Local_Pictures -eq $FALSE)
    {
        $Text = 'Hier können Fotos als Galerie oder Einzelbilder hinterlegt werden. Die Sektion ist updatefest.'
    }
    else
    {
        $Text = $Backup_Local_Pictures | Out-String
    }
        
    Add-Section "$Title" "$Summary" "$Text"



    # Generate Districts List
    $AllDistricts = New-Object System.Collections.ArrayList

    # get all locations
    ForEach ($Item in $Excelfile)
    {

        $Candidate = $Item.District
    
        # add unknown location
        if (!($AllDistricts -contains $Candidate))
        {
            $NULL = $AllDistricts.add($Candidate)
        }
    }

    # sort all districs - it looks better on the overview page
    $AllDistricts = $AllDistricts | Sort

    # parse district list to show all locations at a district
    ForEach ($District in $AllDistricts)
    {
        $Summary = $District
        $text = '<ul>'

        # make sure we don't list duplicates
        $KnownLocation = New-Object System.Collections.ArrayList
        
        # this list is for sorting the locations - because it looks better
        $TargetLocation = New-Object System.Collections.ArrayList

        # sort list
        ForEach ($Item in $Excelfile)
        {
            if ($Item.District -like $District)
            {
                $Null = $TargetLocation.Add($Item)
            }
        }
        $TargetLocation = $TargetLocation | Sort-Object -Property Location

        # deploy list under current district
        ForEach ($Item in $TargetLocation)
        {
            $Location = $Item.Location+', '+$Item.District

            # just one entry per location
            if (!($KnownLocation -contains $Location))
            {
                $text = $text + '<li>[['+$Location+'|'+$Location+']]</li>'
                $NULL = $KnownLocation.Add($Location)
            }        
        }
        $text = $text + '</ul>'

        Add-Section "$Title" "$Summary" "$Text"
    
    }
}

