class NoveditIOBase
  include Singleton
  def read(location)
  end

  def write(noveditModel, location)
    #First line : a comment with the program name, ie 'Novedit
    #at the 6th caracter in order to ease MIME type support
    #exemple in freedesktop.org.xml : <match value="Novedit" type="string" offset="5" />
    #
    # f.puts "<!-- Novedit -->" or "#    Novedit" ...
    # f.puts content
  end
end
