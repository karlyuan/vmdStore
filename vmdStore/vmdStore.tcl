package provide vmdStore 0.1

#### INIT ############################################################
namespace eval vmdStore:: {
	namespace export vmdStore
	
		#### Load Packages				
		package require Tk

        ## GUI
        package require vmdStoreTopGui                      0.1
		package require vmdStoreLoadingGui 					0.1
		package require vmdStoreInstalling					1.0

        ## Theme
        package require vmdStoreTheme                       0.1

        ## Lib
        package require vmdStoreReadExternalPackage         0.1
		package require vmdStoreBrowser						1.0
		package require vmdStoreSearch  					0.1
		package require vmdStoreInstallPlugins				0.1
		package require tar									0.7.1


		
		#### Program Variables
		## General
		variable version	    	"0.3"

		#GUI
        variable topGui             ".vmdStore"
		variable loadingGui			".vmdStoreLoading"
		variable installing 		".vmdStoreInstalling"
		variable askDir				".vmdStoreAskDir"
        
        #Read External Package
        variable server				"http://www.compbiochem.org/Software/vmdStore"
		variable externalPackage    "$::vmdStorePath/temp/repository"
		variable installLink		""
		variable webPageLink		""
		variable citationLink		""
		variable citationText		""
		variable pluginVersion		""
		variable installedPlugins	{}
		variable installingProgress	5

		#Markdown
		variable markdown			[list \
									[list "<h1>" "Helvetica 24 bold"] \
									[list "<h2>" "Helvetica 22 bold"] \
									[list "<h3>" "Helvetica 20 bold"] \
									[list "<h4>" "Helvetica 16 bold"] \
									[list "<b>" "-weight bold"] \
									[list "<i>" "-slant italic"] \
									[list "<bi>" "-weight bold -slant italic"] \
									]
		
}


proc vmdStore::start {} {
	## Open loading GUI
	vmdStore::loadingGui

	## Save a backup of vmdrc
	if {[string first "Windows" $::tcl_platform(os)] != -1} {
		file copy -force ./vmd.rc ./vmd.rc.bak.vmdStore
	} else {
		file copy -force ~/.vmdrc ~/.vmdrc.bak.vmdStore
	}


	## Check for updates on repository content
	set openVersionFile [open $::vmdStorePath/temp/version.txt r]
	set localVersion [split [read $openVersionFile] "\n"]
	close $openVersionFile
	vmdhttpcopy "$vmdStore::server/version.txt" "$::vmdStorePath/temp/version.txt"
	set openVersionFile [open $::vmdStorePath/temp/version.txt r]
	set onlineVersion [split [read $openVersionFile] "\n"]
	close $openVersionFile

	if {[lindex $localVersion 1] != [lindex $onlineVersion 1]} {
		## Update repository
		vmdhttpcopy "$vmdStore::server/repository.tar" "$::vmdStorePath/temp/repository.tar"
		file delete -force "$::vmdStorePath/temp/repository"
		::tar::untar "$::vmdStorePath/temp/repository.tar" -dir "$::vmdStorePath/temp"
	} else {
		## Ignore
	}

	## Read VMDRC to check installed plugins
	if {[string first "Windows" $::tcl_platform(os)] != -1} {
		set vmdrcPath "./vmd.rc"
	} else {
		set vmdrcPath "~/.vmdrc"
	}
	
    set vmdrcLocal [open $vmdrcPath r]
    set vmdrcLocalContent [split [read $vmdrcLocal] "\n"]
	close $vmdrcLocal
	set i 0
	foreach line $vmdrcLocalContent {
		if {[regexp "####vmdStore#### START" $line] == 1} {
			regexp {####vmdStore####\sSTART\s(\S+)} $line -> plugin
			regexp {##\sVersion\s(\S+)} [lindex $vmdrcLocalContent [expr $i + 1]] -> version
			set installedPlugin [list $plugin $version]
			lappend vmdStore::installedPlugins $installedPlugin
		}
		incr i
	}


	## Update vmdStore
	if {[lindex $localVersion 3] != [lindex $onlineVersion 3]} {
		puts "Updating vmdStore..."
		set plugin "vmdStore"
		set path "$vmdStore::server/plugins/$plugin"
    	set installPath [file dirname $::vmdStorePath]

    	set fileName ""
    	set fileName [append fileName $plugin "_V" [lindex $onlineVersion 3]]

    	## Download Plugin
    	vmdhttpcopy "$path/$fileName.tar" "$::vmdStorePath/temp/plugin.tar"

    	## Untar the plugin
    	::tar::untar "$::vmdStorePath/temp/plugin.tar" -dir $installPath


    	## Download VMDRC information to install
    	vmdhttpcopy "$path/vmdrc.txt" "$::vmdStorePath/temp/vmdrc.txt"


    	set vmdrcFile [open "$::vmdStorePath/temp/vmdrc.txt" r]
    	set vmdrcFileContent [read $vmdrcFile]
    	close $vmdrcFile

    	set initDelimiter ""
    	set finalDelimiter ""

    	foreach line [split $vmdrcFileContent "\n"] {
    	    if {[regexp "####vmdStore#### START" $line] == 1} {
    	        set initDelimiter $line
    	    } elseif {[regexp "####vmdStore#### END" $line] == 1} {
    	        set finalDelimiter $line
    	    }
    	}
	
		if {[string first "Windows" $::tcl_platform(os)] != -1} {
			set vmdrcPath "./vmd.rc"
		} else {
			set vmdrcPath "~/.vmdrc"
		}

	    set vmdrcLocal [open $vmdrcPath r]
	    set vmdrcLocalContent [split [read $vmdrcLocal] "\n"]
	    close $vmdrcLocal

	    file delete -force $vmdrcPath
	    set vmdrcLocal [open $vmdrcPath w]

	    set printOrNot 1
	    set printOrNotA 0
	    set i 0
	    foreach line [split $vmdrcFileContent "\n"] {
	        if {[regexp "none" $line] == 1} {
	            set path [subst $::vmdStorePath]
	            regexp {(.*.) none} $line -> newLine
	            puts $vmdrcLocal "$newLine $path"
	        } else {
	            puts $vmdrcLocal $line
	        }
	    }

	    foreach line $vmdrcLocalContent {
	        if {[regexp $initDelimiter $line] == 1} {
	            set printOrNot 0
	        } elseif {[regexp $finalDelimiter $line] == 1} {
	            set printOrNotA 1
	        }

	        if {$printOrNot == 1 && $line != ""} {
	            puts $vmdrcLocal $line
	        }

	        if {$printOrNotA == 1} {
	            set printOrNot 1
	        }

	        incr i
	    }
	

	    close $vmdrcLocal

	}

	## Chech vmdStore update

	destroy $::vmdStore::loadingGui
	
	if {[winfo exists $::vmdStore::topGui]} {wm deiconify $::vmdStore::topGui ;return $::vmdStore::topGui}
	### Open the GUI
	vmdStore::topGui
	update
	return $::vmdStore::topGui

}