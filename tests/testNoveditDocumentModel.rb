require 'test/unit/testcase'
require 'test/unit/autorunner'
require 'modelNovedit'

class TestNoveditDocumentModel < Test::Unit::TestCase

  def setup
    @documentModel = NoveditDocumentModel.new("uu")
  end

  def test_create
    assert(@documentModel.filename == "uu")
  end

end