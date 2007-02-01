#
# Novedit model
#

require 'observer'
require 'yaml'
require 'lib/tree'

class NoveditNode < TreeNode
  attr_accessor :name, :undopool, :redopool, :buffer, :text, :is_open
  
  def initialize(name, text='', is_open=false) 
    super()
    @name = name
    @text = text
    @is_open = is_open
    @undopool = Array.new
    @redopool = Array.new
  end
  
  def to_s
    @name + ": [" + childs.map{|child| child.to_s}.join(',') + "]"
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
  
  attr_accessor :rootNode, :currentNode, :filename
    
  def initialize(filename)
    @novedit_io = NoveditIOBase.new
    @filename = filename
    fill_tree
  end
  
  def fill_tree
    @rootNode = NoveditNode.new("root")
    if (not @filename.nil?)
      read_file
    else
      @rootNode.addNode(NoveditNode.new($DEFAULT_NODE_NAME))
    end
    @currentNode = @rootNode.getNode("O")
    changed
    notify_observers
  end
  
  def set_io(novedit_io)
    @novedit_io = novedit_io
  end
  
#  def addNode(nodeName = $DEFAULT_NODE_NAME)
#    @rootNode.add
#    @nodes << NoveditNode.new(nodeName)
#    changed
#    notify_observers
#  end

  def childs
    @rootNode.childs
  end
  
  def insert_node(parent_path, node)
    @rootNode.getNode(parent_path).addNode(node)
#    parent = self
#    path = parent_path.split(':')
#    path_inserted = path.pop.to_i
#    path.each{|nodePos| parent = parent.nodes[nodePos.to_i]}
#    parent.nodes = parent.nodes.slice(0..(path_inserted-1)) + [node] + parent.nodes.slice(path_inserted..-1)
  end
  
  def getNode(pathNode)
#    node = self
#    path = pathNode.split(':')
#    path.each {|nodePos| node = node.nodes[nodePos.to_i]}
    node = self
    node = @rootNode.getNode(pathNode) if not pathNode.nil?
    return node
  end
  
  def move_node(pathIni, pathFin)
    @rootNode.move_node(pathIni, pathFin)
    changed
    notify_observers
  end
  
  #
  # File access
  #
  def save_file
#    File.open(@filename, "w")do|f|
##      Marshal.dump(@rootNode, f) 
#      f.puts @rootNode.to_yaml 
#    end
    @novedit_io.write(self, @filename)
  end

  def read_file
    if (not @filename.nil?)
        @rootNode = @novedit_io.read(@filename)
    end
  end
  
  def open_file(filename)
    if @filename != filename
      @filename = filename
      fill_tree
    end
  end
end