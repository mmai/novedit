require 'test/unit/testcase'
require 'test/unit/autorunner'
require 'modelNovedit'

class TestNoveditModel < Test::Unit::TestCase

  def setup
    @model = NoveditModel.new("uu")
  end

  def test_create
    assert(@model.filename == "uu")
  end

end