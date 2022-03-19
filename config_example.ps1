    
    # adapt this on your local system

    # default settings for @ffnordhessen
    $protocol = 'https://'
    $wiki = 'wiki.freifunk-nordhessen.de/'
    $api = 'api.php'
    
    # ask wiki admin for own credentials
    $username = 'YourWikiUserName',
    $password = 'YourWikiPassword'

    # a prefix added on your RouterID in Mediawiki-Title (optional)
    $Wikimedia_RouterID_Prefix = 'XYZ'

    # your naming in the admin section in Mediawiki
    $Wikimedia_Admin_String = '[[Benutzer:MikeMueller|Mike Mueller]]'

    # all routers and districts are listed on this page
    # leave empty or $FALSE if overview is not needed
    $Wikimedia_Overview_Page = 'MyLocations'

    # use the excel template provided at https://github.com/andreaswditze/Freifunk-Config-Backup-Tool
    # this file should be the same xlsx you're using for FCBT https://github.com/andreaswditze/Freifunk-Config-Backup-Tool    
    [string]$RouterFile = "~/FF/routerfile.xlsx"
