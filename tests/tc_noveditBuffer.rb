require 'test/unit/testcase'
require 'test/unit/autorunner'

require 'gtk2'
require 'lib/novedit.rb'
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

  def test_serializer
    txtser = @buffer.serialize 
    assert(txtser == @txt, showdiff(@txt, txtser))
  end

  def test_iotags
    ignored = ['find-match']
    # Check if io_html module knows all tags used in textbuffer
    iohtml = NoveditIOHtml.instance
    @buffer.tag_table.each do |tag|
      if not ignored.include?(tag.element_name) and not tag.instance_of?(DepthNoteTag)
        assert iohtml.known_tags.key?(tag.element_name), "'" +tag.element_name + "' is not known by io_html"
      end
    end
  end

end
