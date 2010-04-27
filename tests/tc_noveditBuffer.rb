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
    str += "\n" + a.to_s + "]"
    str += "\n-------------------------"
    str += "\n" + b.to_s + "]"
    return str
  end

  def test_serializer
    txtser = @buffer.serialize 
    assert(txtser.strip == @txt.strip, showdiff(@txt, txtser))
  end

  def test_html_trans
    iohtml = NoveditIOHtml.instance
    html = iohtml.nov_to_html(@buffer.serialize)
    assert(html == "<p><span class='text'>sdf<br /></span><ul><li><span class='text'>fdqs</span></li><li><span class='text'>fsdq</span></li><ul><li><span class='text'>sfdq</span></li><li><span class='text'>fsqd</span></li></ul></ul><span class='text'>sdqf<br /></span><ul><li><span class='text'>fsqd</span></li><ul><ul><li><span class='text'>fqsd</span></li><li><span class='text'>qsfd</span></li></ul></ul><li><span class='text'>qfsd</span></li><li><span class='text'>fqsd</span></li></ul></p>", "Obtained HTML : [" + html + "]")
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
