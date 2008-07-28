class NoveditIOBase
  def read(location)
  end

  def write(noveditModel, location)
     #Première ligne : un commentaire avec le nom du programme, ie 'Novedit'
     #en 6ème caractère pour faciliter la gestion du type MIME
     #exemple dans freedesktop.org.xml : <match value="Novedit" type="string" offset="5" />
     #
     # f.puts "<!-- Novedit -->" ou "#    Novedit" ...
     # f.puts content
  end
end
