#
# Novedit model
#

require 'observer'

class NoveditNode
  attr_accessor :name, :undopool, :redopool, :buffer, :text, :nodes
  
  def initialize(name, text='')
    @nodes = Array.new  
    @name = name
    @text = text
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
  
  attr_accessor :currentNode, :nodes, :filename
    
  def initialize(filename)
    @filename = filename
    @nodes = Array.new
    if (not filename.nil?)
      read_file
    else
      addNode
    end
    @currentNode = @nodes[0]
    changed
    notify_observers
  end
  
  def addNode(nodeName = $DEFAULT_NODE_NAME)
    @nodes << NoveditNode.new(nodeName)
    changed
    notify_observers
  end
  
  def insert_node(parent_path, node)
    parent = self
    path = parent_path.split(':')
    path_inserted = path.pop.to_i
    path.each{|nodePos| parent = parent.nodes[nodePos.to_i]}
    parent.nodes = parent.nodes.slice(0..(path_inserted-1)) + [node] + parent.nodes.slice(path_inserted..-1)
  end
  
  def getNode(pathNode)
    node = self
    path = pathNode.split(':')
    path.each {|nodePos| node = node.nodes[nodePos.to_i]}
    return node
  end
  
  #
  # File access
  #
  def save_file
    File.open(@filename, "w")do|f|
      Marshal.dump(@nodes, f) 
#      f.write(@text) 
    end
  end

  def read_file
    if (not @filename.nil?) and File.exists?(@filename)
      File.open(@filename) do |f| 
        @nodes = Marshal.load(f)
      end
    end
  end
  
  def open_file(filename)
    if @filename != filename
        initialize(filename)
    end
  end
end