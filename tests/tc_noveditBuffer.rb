require 'test/unit/testcase'
require 'test/unit/autorunner'

require 'gtk2'
require 'lib/novedit/lib/novedit_textbuffer.rb'
require 'lib/novedit/lib/novedit_texttag.rb'

#for 
require 'lib/novedit/modules/io/novedit_io_html.rb'

class TestNoveditBuffer < Test::Unit::TestCase

  def setup
    location = 'tests/jeux/noveditbuffer.xml'
    @txt = File.read(location)
    @buffer = Gtk::TextBuffer.new(NoteTagTable.new)
    @buffer.extend(NoveditTextbuffer)
    @buffer.deserialize(@txt)
  end

  def showdiff(a, b)
    str = "-------Differents-------------"
    str += "\n" + a.to_s
    str += "\n-------------------------"
    str += "\n" + b.to_s
    return str
  end

  def showTags(iomodule)
    @buffer.tag_table.each do |tag|
      puts "Tag : " + iomodule.known_tags.key?(tag.element_name).to_s + " : " + tag.element_name
    end
  end

  def test_serializer
    txtser = @buffer.serialize 
    assert(txtser == @txt, showdiff(@txt, txtser))
  end

  def test_iotags
    iohtml = NoveditIOHtml.instance
    showTags(iohtml)
  end

end
