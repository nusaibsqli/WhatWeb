#!/usr/bin/env ruby
# Use like this
# for i in `ls my-plugins/*.rb`
# do              
# echo $i; ./convert-plugin.rb $i
# done

require 'pp'
require 'colorize'
require 'tempfile'
require 'fileutils'

EDITOR="nano -Y ruby"

#Authors = [
#  'someone', # initial plugin
#  'someone else', # added XYZ functionality
#  'another' # refactored ABC
#]

##
# Version 0.2 # 2016-04-23 # Andrew Horton
# Moved patterns from passive function to matches[]
##

FNAME = ARGV.first	 #"movable_type.rb"

# check if file already converted
OLDFILE = File.read FNAME

if OLDFILE =~ /^\s*authors /
	puts "Already converted"
	exit
end

# clear screen
clear_code = %x{clear}
puts clear_code

puts FNAME.cyan

# show me the Versions block
puts "BEFORE".colorize(:color=>:black, :background => :yellow)
cmd = "cat #{FNAME} | egrep \"^\s*author \""
puts `#{cmd}`.strip.yellow
cmd = "cat #{FNAME} | egrep -B 9999 \"^Plugin.define\" | egrep -A 999 '# https://www.morningstarsecurity.com/research/whatweb' | sed '1d;$d'"
OLDCOMMENTS = `#{cmd}`

puts OLDCOMMENTS.yellow

# Convert the current author "" line into an authors array
# I started this with sed
cmd = %q{sed 's/^[ ]*author "\([^"]*"\)\(.*$\)/authors \[ "\1,\2\n]/g'} + " #{FNAME}"
# puts cmd
s = `#{cmd}`
#puts s
puts "AFTER".colorize(:color=>:black, :background => :green)
# show the first author
FIRSTAUTHOR = s.scan(/^[\s]*authors.*/).first
FIRSTAUTHOR.sub!('[',"[\n ")
puts FIRSTAUTHOR.green
# convert Version string
#sed 's/\# \(Version 0.[0-9]\) \# \([0-9\-]*\) \# \(.*$\)/\n"\3", # \1 \2/g'
# next lines until ^##$

versions = []

# get the Version 0.x until a line with ^##
res = s.scan(/^(#\s+Version[^\n]+)(.*?)(^##)/m)

res.each_with_index do | thisversion, i | 
	# discard the \n and ##
	x = thisversion.delete_if {|x| x =~/(^##\s*?$)|(#\s*?\n)/ }

	v, date, author, comment = nil

	thisversion.each_with_index do | line, i |

		# first
		if i == 0
			# puts "# first - #{line}"

			# Version 0.2 # 2016-04-23 # Andrew Horton
			if ret = line.scan(/^#\s+Version\s+([0-9.]+)\s+#\s+([0-9\-]+)[\s#]+(.*)/i).first
				v = ret[0]
				date = ret[1]
				author = ret[2]
				author.delete! '"'
				author.strip!
				author = nil if author.strip.empty?
			elsif ret = line.scan(/^#\s*?Version\s*([0-9.]+)\s*#\s*([0-9\-]+)/i).first
				# just the version and date
				#puts "just the version and date"
				v = ret[0]
				date = ret[1]
				#statements
			elsif ret = line.scan(/^#\s*Version\s*([0-9.]+)\s*/i).first
				# just the version
				#puts "just the version"
				v = ret[0]
			else
				puts "what's this? #{line}"
			end

		else
			# remaining lines in this version
			#puts "comment [#{i}]:"
#			pp line
			line.gsub!(/^\n/,'')
			line.gsub!(/#\s*/,'')
			line.gsub!("\n",'. ')
			#puts " - #{line}"
			if comment
				comment += line
			else
				comment = line
			end
		end

	end

	# FIX duplicate authors
	# MOVE output out of this loop
	if v
		newversion = {}

		if author
			#outblock = "\"#{author}\","
			newversion[:author] = author
		end

		# has to be v
		if v
			#outblock += " " if author 
			#outblock += "# v#{v}"
			newversion[:v] = v
		end
		if date
			#outblock += " # #{date}"
			newversion[:date] = date
		end
		if comment
			#outblock += " # #{comment}"
			newversion[:comment] = comment
		end

		versions << newversion

		#puts outblock.green
	else
		puts "# FAIL! Didn't find version"
		pp res
	end

#	pp x
end

# put versions in correct order
versions.reverse!
	

authors_seen = [FIRSTAUTHOR.scan(/"([^"]*)"/).flatten.first]
#pp authors_seen
outblock = []
versions.each do |thisversion|
	# MOVE output out of this loop
	if thisversion[:v]
		thisoutblock = ""
		
		if thisversion[:author]
			# check for duplicate authors
			if authors_seen.include? thisversion[:author]
				# prefix with hash
				thisoutblock = "# #{thisversion[:author]},"
			else
				thisoutblock = "\"#{thisversion[:author]}\","
				authors_seen << thisversion[:author]
			end
		end
		# has to be v
		if thisversion[:v]
			thisoutblock += " " if thisversion[:author] 
			thisoutblock += "# v#{thisversion[:v]}"
		end
		if thisversion[:date]
			thisoutblock += " # #{thisversion[:date]}"
		end
		if thisversion[:comment]
			thisoutblock += " # #{thisversion[:comment]}"
		end
		thisoutblock = "  " + thisoutblock # add indent
		outblock << thisoutblock
	else
		puts "# FAIL! Didn't find version"
		pp res.red
	end
end

# add closing ]
outblock << "]"
outblock = outblock.join("\n")

puts outblock.green

# build new file
newfile = OLDFILE
# add back ##

# wipe old commentss
newfile[OLDCOMMENTS] = ""

unless newfile.include? "##\nPlugin.define"
	newfile["Plugin.define"] = "##\nPlugin.define"
end

unless newfile.include? "##\n# This file"
	newfile["# This file"] = "##\n# This file" unless not newfile.include? "# This file"
end

# substitude first author line and add other authors
newfile.gsub!(/^[\s]*author.*/, FIRSTAUTHOR + "\n" + outblock)


response = ""
while response != "y" and response != "n"
	# is it OK?
	puts "Is it OK? y or n"
	response = STDIN.gets.strip
end

if response == "y"
  # replace the file
  file = Tempfile.new("whatweb-convert-plugin")
	file.write(newfile)
	file.close

	FileUtils.mv(file.path, FNAME)
else
	# edit file to fix
	# add comment block to top
	file = Tempfile.new("whatweb-convert-plugin")
	file.write(OLDCOMMENTS + "\n" + newfile)
	file.close


	cmd = "#{EDITOR} #{file.path}"
	puts cmd
	ret = system(cmd)

	puts "Save it now? y or n"
	response = STDIN.gets.strip

	if response == "y"
		FileUtils.mv(file.path, FNAME)
	end

end

puts "NEW".colorize(:color=>:black, :background => :cyan)
puts File.read(FNAME).cyan
puts "<press any key>"
STDIN.gets
