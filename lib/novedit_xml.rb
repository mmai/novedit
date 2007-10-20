class NoveditXml
  def WriteStartElement(euh, name, euh2)
    puts "<"+name+">"
  end

  def WriteEndElement()
    puts "</>"
  end

  def WriteFullEndElement()
    puts "</full>"
  end

  def WriteAttributeString(euh, cle, euh2, valeur)
    puts " "+cle+"='"+valeur+"' "
  end

  def MoveToNextAttribute()
    puts "tonextattr"
  end

  def ReadAttributeValue()
    puts "readattrvalue"
  end

  def Value()
    puts "value"
  end
end

