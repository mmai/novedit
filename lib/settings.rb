require 'singleton'
require 'yaml'

# Simple application settings class
# Usage : 
#    @settings = Settings.instance
#    @settings.set('test', 'testvalue')
#    puts @settings.get('test')
#    @settings.save
class Settings
  include Singleton

  def initialize
    @config_file = File.expand_path('~/.novedit_settings.yaml')
     if File.exist? @config_file
       @settings = YAML.load(File.open(@config_file))
     else
       @settings = Hash.new
     end
  end

  def save
    File.open(@config_file, "w")do|f|
      f.puts @settings.to_yaml
    end
  end

  def get(name)
    return @settings[name]
  end

  def set(name, value)
    @settings[name] = value
  end

end
