require 'yaml'
require 'lib/novedit_io_base.rb'

class NoveditIOYaml < NoveditIOBase
  def read(location)
    if File.exists?(location)
      begin
        rootNode = YAML.load(File.open(location)) 
      rescue
        raise "novedit:modules:io:Bad format"
      end
    end
    return rootNode
  end

  def write(noveditModel, location)
    #Deep copy of the document
    lightdoc = Marshal.load(Marshal.dump(noveditModel.rootNode))
    #Cleaning
    lightdoc.nodes_do do |node|
      node.undopool = []
      node.redopool = []
    end
    #Saving
    File.open(location, "w")do|f|
      #Première ligne : un commentaire avec le nom du programme, ie 'Novedit'
      #en 6ème caractère pour faciliter la gestion du type MIME
      #exemple dans freedesktop.org.xml : <match value="Novedit" type="string" offset="5" />
      f.puts "#    Novedit"
      f.puts lightdoc.to_yaml
    end
  end
end
