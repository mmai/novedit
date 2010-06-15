#Plugin system by Mauricio Fernández
#cf. http://eigenclass.org/hiki.rb?ruby+plugins

module PluginSugar
  def def_field(*names)
    class_eval do 
      names.each do |name|
        define_method(name) do |*args| 
          case args.size
          when 0: instance_variable_get("@#{name}")
          else    instance_variable_set("@#{name}", *args)
          end
        end
      end
    end
  end
end

class Plugin
  @registered_plugins = {}
  class << self
    attr_reader :registered_plugins
    private :new
  end

  def self.define(name, &block)
    p = new
    p.instance_eval(&block)
    Plugin.registered_plugins[name] = p
  end

  extend PluginSugar
  def_field :title, :author, :site, :version, :description, :dependencies
end

### this under PLUGIN_DIR/
#Plugin.define "foo" do
#  author "Tsukishiro M."
#  version "1.0.0"
#  
#  # stuff
#  def do_it(x)  # becomes a singleton method
#    x * 2
#  end
#end
###
#
#Plugin.registered_plugins.keys                     # => ["foo"]
#plugin = Plugin.registered_plugins["foo"]          # => #<Plugin:0xb7de9934 @author="Tsukishiro M.", @version="1.0.0">
#plugin.author                                      # => "Tsukishiro M."
#plugin.do_it "foo "                                # => "foo foo "
#
