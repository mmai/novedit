class NoveditXml
  def WriteStartElement(euh, name, euh2)
    puts "WSE"
    puts "<"+name+">" unless name.nil?
  end

  def WriteString(str)
    print str
  end

  def WriteEndElement()
    puts "</>"
  end

  def WriteFullEndElement()
    puts "</full>"
  end

  def WriteAttributeString(cle, valeur)
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

