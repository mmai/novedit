require 'lib/tree.rb'

class TreeXml < TreeNode
  attr_accessor :name, :attrs, :text
  def initialize(name)
    @name = name
    @attrs = Hash.new
    @text = ""
  end

  def to_s
    str = ""
    #On ouvre l'élément
#    if (name!="t")
      str += "<"+name
      @attrs.each do |key, value|
        str += " "+key+"='"+value+"'"
      end
      str += ">"
#    end
    
    #Contenu texte de l'élément
    str += @text

    #Sous-éléments
    childs.each do |child|
      str += child.to_s
    end

    #On ferme l'élément
#    if (name!="t")
      str += "</"+@name+">"
#    end

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
    while @tab_nodes.length > 0
      WriteEndElement()
    end
    @xml.to_s
  end

  def close_text
    if @tab_nodes.length>1 && (@tab_nodes.last.name == "t")
      lastNode = @tab_nodes.pop
      @tab_nodes.last.addNode(lastNode)
    end
  end


  def WriteStartElement(euh, name, euh2)
    close_text()
    @tab_nodes << TreeXml.new(name)
  end

  def WriteString(str)
    #    @tab_nodes.last['node'].text += str
    if (@tab_nodes.length > 0)
      if (@tab_nodes.last.name != "t")
        WriteStartElement(nil, "t", nil)
      end
    else
        WriteStartElement(nil, "t", nil)
    end
    @tab_nodes.last.text += str
  end

  def WriteEndElement()
    close_text()
    lastNode = @tab_nodes.pop
    if @tab_nodes.length == 0
      @xml = lastNode if !lastNode.nil?
    else
      @tab_nodes.last.addNode(lastNode)
    end
  end

  def WriteAttributeString(cle, valeur)
    @tab_nodes.last.attrs[cle] = valeur
  end

  def WriteFullEndElement()
    lastNode = @tab_nodes.pop
    if @tab_nodes.length == 0
      puts "pppu rien!"
      @xml = lastNode if !lastNode.nil?
    else
      @tab_nodes.last.addNode(lastNode)
    end
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


