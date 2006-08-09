#
# Novedit model
#

class NoveditDocumentModel
    attr_accessor :filename, :undopool, :redopool, :buffer
    def initialize()
        @filename = nil
        @undopool = Array.new
        @redopool = Array.new
    end
    
    def appendUndo(action, iter, text)    
        if (action==:insert_text) 
          @undopool <<  [action, iter.offset, iter.offset + text.scan(/./).size, text]
          @redopool.clear
        elsif (action == :delete_range)
          #text = @buffer.get_text(start_iter, end_iter)
          #@undopool <<  [action, start_iter.offset, end_iter.offset, text]
        end
     end
end

class NoveditModel
  def initialize()
    @tab_docs = Array.new  
  end
  
  def add_document()
    newdoc = NoveditDocumentModel.new
    @tab_docs << newdoc
    return newdoc
  end
    
  #
  # File access
  #
  def save_file
    File.open(@filename, "w"){|f| 
      f.write(@buffer.get_text(*@buffer.bounds)) 
    }
  end

  def read_file
    File.open(@currentDocument.filename){|f| ret = f.readlines.join }
  end

  #
  # Undo, Redo
  #
  def on_undo()
    return if @currentDocument.undopool.size == 0
    action = @currentDocument.undopool.pop 
    case action[0]
    when "insert_text"
      start_iter = @currentDocument.buffer.get_iter_at_offset(action[1])
      end_iter = @currentDocument.buffer.get_iter_at_offset(action[2])
      @currentDocument.buffer.delete(start_iter, end_iter)
    when "delete_range"
      start_iter = @currentDocument.buffer.get_iter_at_offset(action[1])
      @currentDocument.buffer.insert(start_iter, action[3])
    end
    iter_on_screen(start_iter, "insert")
    @currentDocument.redopool << action
  end

  def on_redo()
    return if @currentDocument.redopool.size == 0
    action = @currentDocument.redopool.pop 
    case action[0]
    when "insert_text"
      start_iter = @currentDocument.buffer.get_iter_at_offset(action[1])
      end_iter = @currentDocument.buffer.get_iter_at_offset(action[2])
      @currentDocument.buffer.insert(start_iter, action[3])
    when "delete_range"
      start_iter = @currentDocument.buffer.get_iter_at_offset(action[1])
      end_iter = @currentDocument.buffer.get_iter_at_offset(action[2])
      @currentDocument.buffer.delete(start_iter, end_iter)
    end
    iter_on_screen(start_iter, "insert")
    @currentDocument.undopool << action
  end    
end