require 'yaml'
require 'lib/novedit_io_base.rb'

class NoveditExportYaml < NoveditExportBase
  def read(location)
    File.open(location, "r")do|f|
      noveditModel = ""
    end
  end

  def write(noveditModel, location)
    File.open(location, "w")do|f|
      f.puts noveditModel.rootNode.to_yaml
    end
  end
end
