require 'lib/tree.rb'

class TreeXml < TreeNode
  attr_accessor :name, :attrs, :text
  def initialize(name)
    @name = name
    @attrs = Hash.new
    @text = ""
  end

  def to_s
    #On ouvre l'élément
    str = "\n<"+name
    @attrs.each do |key, value|
      str += " "+key+"='"+value+"'"
    end
    str += ">"
    
    #Contenu texte de l'élément
    str += @text

    #Sous-éléments
    childs.each do |child|
      str += child.to_s
    end

    #On ferme l'élément
    str += "</"+@name+">\n"

    return str
  end
end

class NoveditXml
  def initialize
#    @xml = TreeXml.new("xml")
#    @xml.attrs['version']="1.0"
    @tab_nodes = Array.new
    @xml = nil
  end

  def to_s
    @xml.to_s
  end

  def WriteStartElement(euh, name, euh2)
#    @tab_nodes << {'node' => TreeXml.new(name), 'opened' => true}
    @tab_nodes << TreeXml.new(name)
  end

  def WriteString(str)
#    @tab_nodes.last['node'].text += str
    @tab_nodes.last.text += str
  end

  def WriteEndElement()
    lastNode = @tab_nodes.pop
    if @tab_nodes.length == 0
      @xml = lastNode
    else
      @tab_nodes.last.addNode(lastNode)
    end
  end

  def WriteAttributeString(cle, valeur)
    @tab_nodes.last.attrs[cle] = valeur
  end

  def WriteFullEndElement()
    puts "TODO:</full>"
  end

  def MoveToNextAttribute()
    puts "TODO:tonextattr"
  end

  def ReadAttributeValue()
    puts "TODO:readattrvalue"
  end

  def Value()
    puts "TODO:value"
  end
end

