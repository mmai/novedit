require 'yaml'
require 'lib/novedit_io_base.rb'

class NoveditIOYaml < NoveditIOBase
  def initialize
    @ext = "nov"
    @name = "Novedit"
  end

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
      #First line : a comment with the program name, ie 'Novedit
      #at the 6th caracter in order to ease MIME type support
      #exemple in freedesktop.org.xml : <match value="Novedit" type="string" offset="5" />
      f.puts "#    Novedit"
      # version & file format 
      f.puts "# " + $VERSION
      f.puts "#    YAML"
      f.puts lightdoc.to_yaml
    end
  end
end
