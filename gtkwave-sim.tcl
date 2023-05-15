set nfacs [gtkwave::getNumFacs]

# Execute the find command
set command_output [exec find . -type f -name "*tb*vhd*" -print]

puts "\nTestbench file:"
puts $command_output

set result [exec cat $command_output]

#Extract the port map section and then extract the testbench signals
if {[regexp -nocase {port\s+map\s*\(([^)]+)\)} $result -> match]} {
	set tb_entity [gtkwave::getFacName 0]
	regexp {([^.]*)} $tb_entity -> tb_entity
	puts "\nFACNAME: $tb_entity"

	set new_match [exec sh -c "echo \"$match\" | grep -oP '\(.*\)' | tr -d '()'"]
	puts "\nTestbench port map section: $new_match\n"
	
	set command_output [exec sh -c [format {echo "%s" | grep -oE '([a-zA-Z0-9_]+)(\s*=>\s*[^,)]+)?' | sed -e 's/.*=>\s*//' -e 's/[() ]//g'} $new_match]]

	# Split the command output into a list of signal names
	set signal_names [regexp -all -inline -nocase {\S+} $command_output]
	
	set lcase_signal_names [lmap signal $signal_names {string tolower $signal}]

	set formatted_signal_names [lmap signal $lcase_signal_names {string cat $tb_entity "." $signal}]

	set signal_names $formatted_signal_names

	#Print the testbench signals
	puts "Testbench Signals:"
	foreach signal $signal_names {
		puts $signal
	}
} else {
    puts "Port map section not found in the testbench file. The signals were not automatically added."
}

set j 0
for {set i 0} {$i < $nfacs} {incr i} {
	set facname ""
	foreach signal $signal_names {
		if {[string match "$signal*" [gtkwave::getFacName $i]]} {
			set facname [gtkwave::getFacName $i]
			incr j
			break;
		}
	}

	if {$facname == ""} {
		continue;
	}

	#Insert blank each time after the first signal
	if {$j != 0} {
		gtkwave::/Edit/Insert_Blank
	}
	
	#Add the signal
	gtkwave::addSignalsFromList $facname
	puts "signal name is: $facname"

	#Change the color of the signal after the first, for better appearance	
	if {$j == 2} {
		gtkwave::/Edit/Color_Format/Red
	} elseif {$j == 3} {
		gtkwave::/Edit/Color_Format/Orange
	} elseif {$j == 4} {
		gtkwave::/Edit/Color_Format/Yellow
	} elseif {$j == 5} {
		gtkwave::/Edit/Color_Format/Blue
	}
	puts "j is $j"
}
#General info
puts "\nNumber of automatically added signals: $j"
puts "Total number of signals in the simulation file: $nfacs"
puts "\n"

#Zoom to Full
gtkwave::/Time/Zoom/Zoom_Best_Fit
