require 'lib/novedit_io_base.rb'

class NoveditIOHtml < NoveditIOBase
  def read(location)
    if File.exists?(location)
      begin
        raise "novedit:modules:io:HTML:Todo"
      rescue
        raise "novedit:modules:io:Bad format"
      end
    end
    return rootNode
  end

  def write(noveditModel, location)
    level = 1
    html = ""
    noveditModel.rootNode.childs.each do |elementBase| 
      elementBase.nodes_do do |node|
        level = node.path.split(':').size.to_s
        html = html + "<h"+level+">" + node.name + "</h"+level+">\n" + node.text + "\n"
      end
    end

    #Saving
    File.open(location, "w")do|f|
      f.puts html
    end
  end
end
