require 'test/unit/testcase'
require 'test/unit/autorunner'

require 'gtk2'
require 'lib/novedit_textbuffer.rb'
require 'lib/novedit_texttag.rb'

class TestNoveditBuffer < Test::Unit::TestCase

  def setup
    location = 'tests/noveditbuffer.xml'
    @txt = File.read(location)
    @buffer = Gtk::TextBuffer.new(NoteTagTable.new)
    @buffer.extend(NoveditTextbuffer)
    @buffer.deserialize(@txt)
  end

  def showdiff(a, b)
    puts "-----comparaison---------------"
    p a
    puts "EGAL ?"
    p b
  end

  def test_serializer
    txtser = @buffer.serialize 
    assert(txtser == @txt, showdiff(@txt, txtser))
  end

end
