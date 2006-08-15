#
# Novedit model
#

require 'observer'

class NoveditDocumentModel
  include Observable
  
  attr_accessor :filename, :undopool, :redopool, :buffer, :text
  def initialize(filename)
      @filename = filename
      @undopool = Array.new
      @redopool = Array.new
      read_file
  end
   
  #
  # File access
  #
  def save_file
    File.open(@filename, "w"){|f| 
      f.write(@text) 
    }
  end

  def read_file
    File.open(@filename){|f| @text = f.readlines.join } if not @filename.nil?
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
  include Observable
  
  attr_reader :currentDocument
  
  def initialize()
    @tab_docs = Array.new  
  end
  
  def add_document(filename = nil)
    newdoc = NoveditDocumentModel.new(filename)
    @tab_docs << newdoc
    @currentDocument = newdoc   
  end
    
  def open_file(filename)
    #Le fichier est-il dj ouvert ?
    if doc = @tab_docs.find { |doc| doc.filename == filename}
        @currentDocument = doc 
        changed
        notify_observers()
    else
        add_document(filename) unless filename.nil?
        changed
        notify_observers
        @currentDocument.changed
        @currentDocument.notify_observers
    end
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