#
# Novedit
#

require "viewNovedit.rb"

class ControlerNovedit
  @model
  @view
  
  def initialize(model)
    @model = model
    @view = ViewNovedit.new(self, model)    
  end
  
  def new_file(widget)
    modelDocument = @model.add_document
    viewDocument = @view.add_document
    viewDocument.on_clear()
  end
end





