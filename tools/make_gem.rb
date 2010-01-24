require 'app_config'
require 'date'
require 'find'

$GEMSPEC_FILE = "novedit.gemspec"

required_gems = ['gettext']

excluded_dirs = ['bacasable', 'features', 'build', '.svn']
excluded_files = [$GEMSPEC_FILE]
included_files = []
Find.find('.') do |path|
  if FileTest.directory?(path)
    if excluded_dirs.include?(File.basename(path))
      Find.prune       # Don't look any further into this directory.
    else
      next
    end
  elsif not excluded_files.include?(File.basename(path))
    included_files << path[2..-1]
  end
end
 
puts "Writing gemspec file"
File.open($GEMSPEC_FILE, "w")do|f|
  f.puts "Gem::Specification.new do |s|
  s.name = %q{"+$NAME+"}
  s.version = '"+$VERSION+"'
  s.date = %q{" + Date.today.to_s + "}
  s.authors = ['"+$AUTHORS+"']
  s.email = %q{"+$EMAIL+"}
  s.summary = %q{"+$SUMMARY+"}
  s.homepage = %q{"+$HOMEPAGE+"}
  s.description = %q{"+$DESCRIPTION+"}
  s.executables = ['novedit']
  s.files = ['" + included_files.join("', '") + "']
  s.required_ruby_version = '>=1.8.6'"
  required_gems.each do |rgem|
    f.puts "  s.add_dependency('" + rgem + "')"
  end
  f.puts "  s.requirements = ['GTK+ 2.16', 'libglade2 for ruby (\"sudo apt-get install libglade2-ruby\" on Debian based systems)']
end"
end

exec "gem build " + $GEMSPEC_FILE + " && mv " + $NAME + "-" + $VERSION + ".gem build/"
