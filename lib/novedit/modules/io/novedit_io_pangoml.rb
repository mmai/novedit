require 'novedit/lib/novedit_io_base.rb'

class NoveditIOPangoml < NoveditIOBase
  attr_reader :known_tags

  def initialize
    @ext = "pangoml"
    @name = "Pango Text Attribute Markup Language"
    @known_tags = {
      't' =>"span",
      'italic' =>"i",
      'bold' =>"b",
#      'list' =>"ul",
#      'list-item' =>"li",
      'strikethrough' =>"s",
      'highlight' =>'span background="yellow"',
#      'justify-right' =>"span style='text-align:right;'",
#      'justify-left' =>"div style='text-align:left;'",
#      'centered' =>"div style='text-align:center;'"
    }
  end

  def read(location)
   #Not implemented (no need : it's for printing only!) 
  end

  def trans_tag(tagini, tagnew, text)
    text.gsub!(Regexp.new("<" + tagini + ">"), "<" + tagnew + ">")
    text.gsub!(Regexp.new("</" + tagini.split.first + ">"), "</" + tagnew.split.first + ">")
    return text
  end

  def del_tag(tag, text)
    text.gsub!(Regexp.new("<" + tag + ">"), "")
    text.gsub!(Regexp.new("</" + tag + ">"), "")
    return text
  end

  def nov_to_pangoml(text)
    @known_tags.each_index {|tag| text = trans_tag(tag, @know_tags[tag], text) }
    return text
  end

  def write(noveditModel, location)
    level = 1
    html = ""
    noveditModel.rootNode.childs.each do |elementBase| 
      elementBase.nodes_do do |node|
        nodetext = node.text.dup
        level = node.path.split(':').size.to_s
        html = html + "<h"+level+">" + node.name + "</h"+level+">\n" + nov_to_html(nodetext) + "\n"
      end
    end

    #Saving
    File.open(location, "w")do|f|
      #First line : a comment with the program name, ie 'Novedit
      #at the 6th caracter in order to ease MIME type support
      #exemple in freedesktop.org.xml : <match value="Novedit" type="string" offset="5" />
      #
      f.puts "<!-- Novedit -->"
      # version & file format 
      f.puts "<!-- " + $VERSION + " -->"
      f.puts "<!-- HTML -->"
      f.puts "<html>"
      f.puts "<head>"
      f.puts "<meta http-equiv='Content-Type' content='text/html; charset=utf-8' />"
      f.puts "</head>\n<body>\n"
      f.puts html
      f.puts "</body>\n</html>"
    end
  end
end
