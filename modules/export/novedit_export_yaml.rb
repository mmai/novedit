require 'yaml'
require 'lib/novedit_export_base.rb'

class NoveditExportYaml < NoveditExportBase
  def export(location)
    File.open(location, "w")do|f|
      f.puts @model.rootNode.to_yaml
    end
  end
end
