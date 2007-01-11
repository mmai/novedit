#
# Novedit model
#

require 'observer'

class NoveditNode
  attr_accessor :filename, :undopool, :redopool, :buffer, :text
  
  def initialize(filename)
    @nodes = Array.new  
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
    if not @filename.nil?
      File.open(@filename){|f| @text = f.readlines.join } if File.exists?(@filename)
    end
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
    
  def open_file(filename)
    if @filename != filename
        initialize(filename)
        changed
        notify_observers
    end
  end

  #
  # Undo, Redo
  #
  def on_undo()
    return if @undopool.size == 0
    action = @undopool.pop 
    case action[0]
    when "insert_text"
      start_iter = @buffer.get_iter_at_offset(action[1])
      end_iter = @buffer.get_iter_at_offset(action[2])
      @buffer.delete(start_iter, end_iter)
    when "delete_range"
      start_iter = @buffer.get_iter_at_offset(action[1])
      @buffer.insert(start_iter, action[3])
    end
    iter_on_screen(start_iter, "insert")
    @redopool << action
  end

  def on_redo()
    return if @redopool.size == 0
    action = @redopool.pop 
    case action[0]
    when "insert_text"
      start_iter = @buffer.get_iter_at_offset(action[1])
      end_iter = @buffer.get_iter_at_offset(action[2])
      @buffer.insert(start_iter, action[3])
    when "delete_range"
      start_iter = @buffer.get_iter_at_offset(action[1])
      end_iter = @buffer.get_iter_at_offset(action[2])
      @buffer.delete(start_iter, end_iter)
    end
    iter_on_screen(start_iter, "insert")
    @undopool << action
  end
end

class NoveditModel
  include Observable
  
  def initialize
    @nodes = Array.new
  end
  
  def addNode
    @nodes << NoveditNode.new(nil)
  end
  
  def getNode(pathNode)
    node = self
    path = pathNode.split('.')
    path.each {|nodePos| node = node.nodes[nodePos]}
    return node
  end
  
  def open_file(fichier)
  end
      
end