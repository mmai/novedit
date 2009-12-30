#
# Novedit model
#

require 'observer'
require 'lib/tree'

require 'lib/novedit_io_base'

class NoveditNode < TreeNode
  attr_accessor :name, :undopool, :redopool, :text, :is_open
  
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
end

class NoveditModel
  include Observable
  
  attr_accessor :rootNode, :currentNode, :filename, :is_saved
    
  def initialize(filename)
    @novedit_io = NoveditIOBase.instance
    @filename = filename
    @is_saved = true
    fill_tree
  end
  
  def fill_tree
    @rootNode = NoveditNode.new("root")
    if (not @filename.nil?)
      read_file
    else
      @rootNode.addNode(NoveditNode.new($DEFAULT_NODE_NAME))
    end
    @currentNode = @rootNode.getNode("0")
    changed
    notify_observers
  end
  
  def set_io(novedit_io)
    @novedit_io = novedit_io
  end

  def get_io
    return @novedit_io
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
  
  def remove_node(path)
    @rootNode.remove(path)
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
    @is_saved = true
  end

  def read_file
    if (not @filename.nil?)
      begin
        lu = @novedit_io.read(@filename)
      rescue
        errmes=$!.to_s
        case errmes
        when "novedit:modules:io:Bad format"
          err_message = _("Bad file format")
        end
      end

      if lu.nil?
#        dialog = Gtk::MessageDialog.new(@appwindow, Gtk::Dialog::MODAL, 
#                                        Gtk::MessageDialog::ERROR, 
#                                        Gtk::MessageDialog::BUTTONS_CLOSE, 
#                                        "Cannot open " + @filename + ((err_message.nil?)?errmes:err_message))
#        dialog.run
#        dialog.destroy
        raise("Cannot open " + @filename + ((err_message.nil?)?(errmes.to_s):err_message))
        open_file(nil)
      else
        @rootNode = lu
        if not @rootNode
          @rootNode = NoveditNode.new("root")
          @rootNode = @rootNode.addNode(NoveditNode.new($DEFAULT_NODE_NAME))
        end
        @is_saved = true
      end
    end
  end
  
  def open_file(filename)
    if @filename != filename
      @filename = filename
      fill_tree
    end
  end
end
