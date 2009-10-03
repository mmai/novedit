require 'yaml'

# Simple application settings class
# Usage : 
#    @mysettings = Settings.new(File.expand_path('~/.settings.yaml'))
#    @mysettings['test'] =  'testvalue'
#    puts @mysettings['test']
#    @mysettings.save
class Settings

  def initialize(settings_file)
    @settings_file = settings_file
     if File.exist? @settings_file
       @settings = YAML.load(File.open(@settings_file))
     else
       @settings = Hash.new
     end
  end

  def save
    File.open(@settings_file, "w")do|f|
      f.puts @settings.to_yaml
    end
  end

  def [](name)
    return @settings[name]
  end

  def []=(name, value)
    @settings[name] = value
  end

end
