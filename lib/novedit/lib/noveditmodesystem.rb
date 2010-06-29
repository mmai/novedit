module NoveditModeSugar
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

class NoveditMode
  @registered_modes = {}
  class << self
    attr_reader :registered_modes
    private :new
  end

  def self.define(name, &block)
    p = new
    p.instance_eval(&block)
    NoveditMode.registered_modes[name] = p
  end

  extend NoveditModeSugar
  def_field :title, :author, :site, :version, :description, :dependencies
end

