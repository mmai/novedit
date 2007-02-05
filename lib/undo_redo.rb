require 'lib/command'

class UndoRedo
  attr_accessor :tabUndo, :tabRedo
  
  def initialize()
    @tabUndo = []
    @tabRedo = []
  end
  
  def undo_command
    todo = @tabUndo.pop
    if not todo.nil?
      todo.undo_command
      @tabRedo << todo
    end
  end
  
  def redo_command
    todo = @tabRedo.pop
    if not todo.nil?
      todo.do_command
      @tabUndo << todo
    end
  end
end
