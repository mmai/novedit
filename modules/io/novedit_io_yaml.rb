require 'yaml'
require 'lib/novedit_io_base.rb'

class NoveditIOYaml < NoveditIOBase
  def read(location)
    rootNode = YAML.load(File.open(location))
    return rootNode
  end

  def write(noveditModel, location)
    File.open(location, "w")do|f|
      f.puts noveditModel.rootNode.to_yaml
    end
  end
end
