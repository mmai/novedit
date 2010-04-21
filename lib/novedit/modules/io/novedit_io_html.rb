require 'novedit/lib/novedit_io_base.rb'

class NoveditIOHtml < NoveditIOBase
  attr_reader :known_tags

  def initialize
    @ext = "html"
    @name = "HTML"
    @known_tags = {
      't' =>"span class='text",
      'italic' =>"i",
      'bold' =>"b",
      'list' =>"ul",
      'list-item' =>"li",
      'strikethrough' =>"del",
      'highlight' =>"span style='background:yellow;'",
      'justify-right' =>"div style='text-align:right;'",
      'justify-left' =>"div style='text-align:left;'",
      'centered' =>"div style='text-align:center;'"
    }
  end

  def read(location)
    if File.exists?(location)
      rootNode = NoveditNode.new("root")
      lastnode = rootNode
      curnode = nil
      node_level = 1
      reg_comment = /<!--.*/
      reg_ignore =  /<\/?(html|body)/
      begin
        in_header = false
        IO.readlines(location).each do |line|
          #Ignore html header and comments
          if line.strip == "<head>"
            in_header = true
            next
          elsif line.strip == "</head>"
            in_header = false
            next
          end
          next if in_header or line =~ reg_comment or line =~ reg_ignore 

          #Captures Headings as nodes
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
    @known_tags.each_index {|tag| text = trans_tag(tag, @know_tags[tag], text) }
    return text
  end

  def html_to_nov(text)
    text = trans_tag("p", "note-content", text)
    @known_tags.each do |html_val|
      nov_val = @known_tags.index(html_val)
      text = trans_tag(html_val, nov_val, text) 
    end
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
