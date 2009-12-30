class NoveditIOBase
  include Singleton

  attr_reader :ext, :name

  def get_filter
    if @filter.nil?
      @filter = Gtk::FileFilter.new
      @filter.name = @name
      @filter.add_pattern("*." + @ext)
    end
    return @filter
  end

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
