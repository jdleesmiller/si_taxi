#
# This edits Eclipse's generated Makefiles to use the precompiled header.
# Note that you still only get to use the gch in one configuration. 
#

#
# Header file that you want to precompile.
# Path must be relative to the project root. 
# The directory containing the stdafx.h must contain at least one .cpp file.
#
PCH = 'si_taxi/stdafx.h'

# Look at existing makefile to see if it needs hacking; we will only rewrite
# it if necessary.
rewrite_makefile = false
makefile_lines = IO.readlines('makefile')
makefile_lines.each {|l| l.chomp!}

# Need to import dependency file for the pch. This has to happen after we've
# imported subdir.mk.
dep_line = "CPP_DEPS += #{PCH}.gch.d"
objects_line = makefile_lines.index("-include objects.mk")
raise "cannot find subdir.mk include line" unless objects_line
unless makefile_lines[objects_line+1] == dep_line
  makefile_lines.insert(objects_line+1, dep_line)
  rewrite_makefile = true
end

# Make all objects depend on the precompiled header (even if not all of them
# really do).
gch_o_rule = "$(OBJS):%.o:../#{PCH}.gch"
unless makefile_lines.member?(gch_o_rule)
  makefile_lines << ""
  makefile_lines << gch_o_rule
  makefile_lines << ""

  rewrite_makefile = true
end

# Look for the rule to build the gch. We need to use the same g++ arguments as
# everywhere else; we can get these from a subdir.mk file. The dependencies on
# the project files ensure that the PCH gets rebuilt when the project settings
# change; otherwise, this happens for all the other files, but not the PCH, for
# reasons I don't fully understand.
gch_rule = "../#{PCH}.gch: ../#{PCH} ../.cproject ../.project"
unless makefile_lines.find {|l| l =~ /^#{gch_rule}/}
  # Need to look up the command in the subdir.mk file.
  subdir_mk = File.new(File.join(File.dirname(PCH),'subdir.mk')).read
  subdir_mk =~ /^(\tg\+\+.*)$/ or raise "cannot find g++ command in subdir.mk"
  cmd = $1

  # Make the command do dependencies for the gch file.
  cmd.gsub! /-MF"[^"]*"/, "-MF\"#{PCH}.gch.d\""
  cmd.gsub! /-MT"[^"]*"/, "-MT\"#{PCH}.gch.d\""

  # Append a rule for building the precompiled header.
  makefile_lines<<""
  makefile_lines<<"#{gch_rule}"
  makefile_lines<<cmd

  # Must also import the dependencies for the precompiled header, because the
  # makefile won't do it by default.

  rewrite_makefile = true
end

# Add a command to the clean rule so we get rid of the gch-related files.
clean_line = (0...makefile_lines.size).find{|i| makefile_lines[i] =~ /^clean:/}
raise "couldn't find clean: line in makefile" unless clean_line
unless makefile_lines[clean_line+1] =~ /#{PCH}\.gch/
  makefile_lines.insert(clean_line+1,
    "\trm -f #{PCH}.gch.d ../#{PCH}.gch")
  rewrite_makefile = true
end

# Save changes, if any.
if rewrite_makefile
  File.open('makefile', 'w') do |f|
    f.write makefile_lines.join("\n")
  end
end

# My department machine has some issues; this line avoids a security warning.
$VERBOSE = nil

# Now run make.
exec "make", ARGV.join(' ')

