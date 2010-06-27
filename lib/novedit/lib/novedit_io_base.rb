class NoveditIOBase
  include Singleton

  attr_reader :ext, :name

  def initialize
  end

  def parse_file_head(location)
    parsed = Hash.new
    if File.exists?(location)
      f = File.open(location)
      f.readline #1st line
      parsed['version'] = f.readline[5..-1].split()[0] #2nd line = version
      parsed['format'] = f.readline[5..-1].split()[0] #3rd line = format
      parsed['modes'] = f.readline[5..-1].split()[0].split(",") #4th line = modes
      f.close
    end
    return parsed
  end

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
