#
# Novedit
#

require "viewNovedit.rb"

class ControlerNovedit
  @model
  @view
  
  def initialize(model)
    @model = model
    @view = ViewNovedit.new(this, model)    
  end

end





