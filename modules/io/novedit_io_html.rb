require 'lib/novedit_io_base.rb'

class NoveditIOHtml < NoveditIOBase
  def initialize
    @ext = "html"
    @name = "HTML"
  end

  def read(location)
    if File.exists?(location)
      rootNode = NoveditNode.new("root")
      lastnode = rootNode
      curnode = nil
      node_level = 1
      begin
        IO.readlines(location).each do |line|
          next if line =~ /<!--.*/
          matched = line.match(/<h([1-9])>([^<]*)<\/h[1-9]>/)
          if matched
            curnode_level = node_level
            node_level = matched[1].to_i
            node_title = matched[2]

            while curnode_level <=  lastnode.path.split(':').length
              lastnode = lastnode.parent
            end
            if not curnode.nil?
              curnode.text = html_to_nov(curnode.text)
              lastnode.addNode(curnode)
              lastnode = curnode
            end
            curnode = NoveditNode.new(node_title)
          else
            curnode.text << line
          end
        end
        #Last node
        while node_level <=  lastnode.path.split(':').length
          lastnode = lastnode.parent
        end
        curnode.text = html_to_nov(curnode.text)
        lastnode.addNode(curnode)
      rescue
        puts $!.inspect
        raise "novedit:modules:io:Bad format"
      end
    end
    return rootNode
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

  def nov_to_html(text)
#    text = del_tag("note-content version='[^']*'", text)
    text = trans_tag("note-content version='[^']*'", "p", text)
#    text = del_tag("t", text)
    text = trans_tag("t", "span class='text'", text)
    text = trans_tag("italic", "i", text)
    text = trans_tag("bold", "b", text)
    text = trans_tag("list", "ul", text)
    text = trans_tag("list-item", "li", text)
    text = trans_tag("strikethrough", "del", text)
    text = trans_tag("highlight", "span style='background:yellow;'", text)
    text = trans_tag("justify-right", "div style='text-align:right;'", text)
    text = trans_tag("justify-left", "div style='text-align:left;'", text)
    text = trans_tag("centered", "div style='text-align:center;'", text)
    return text
  end

  def html_to_nov(text)
    text = trans_tag("p", "note-content", text)
    text = trans_tag("span class='text'", "t", text)
    text = trans_tag("i", "italic", text)
    text = trans_tag("b", "bold", text)
    text = trans_tag("ul", "list", text)
    text = trans_tag("li", "list-item", text)
    text = trans_tag("del", "strikethrough", text)
    text = trans_tag("span style='background:yellow;'", "highlight", text)
    text = trans_tag("div style='text-align:right;'", "justify-right", text)
    text = trans_tag("div style='text-align:left;'", "justify-left", text)
    text = trans_tag("div style='text-align:center;'", "centered", text)
    return text
  end


  def write(noveditModel, location)
    level = 1
    html = ""
    noveditModel.rootNode.childs.each do |elementBase| 
      elementBase.nodes_do do |node|
        level = node.path.split(':').size.to_s
        html = html + "<h"+level+">" + node.name + "</h"+level+">\n" + nov_to_html(node.text) + "\n"
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
      f.puts html
    end
  end
end
