#
# Novedit model
#

require 'observer'
require 'novedit/lib/tree'

require 'novedit/lib/novedit_io_base'

class NoveditNode < TreeNode
  attr_accessor :name, :undopool, :redopool, :text, :is_open, :metas
  
  def initialize(name, text='', is_open=false, metas=Hash.new) 
    super()
    @name = name
    @text = text
    @metas = metas
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
  
  attr_accessor :rootNode, :currentNode, :filename, :is_saved, :modes, :available_modes
    
  def initialize(filename)
    @novedit_io = NoveditIOBase.instance
    @filename = filename
    @is_saved = true
    @available_modes = []
    @modes = []
    fill_tree
  end
 
  def metas=(metas)
    @rootNode.metas = metas
  end

  def metas
    @rootNode.metas
  end 

  def init_metas(metas)
    metas.each_key do |metakey|
      init_meta(@rootNode.metas, metakey, metas[metakey])
    end
  end

  def init_meta(meta_root, metakey, meta)
    if not meta_root.has_key?(metakey)
      meta_root[metakey] = meta
#    elsif meta.class == Hash
    else
      puts meta_root.inspect
      puts metakey.inspect
      puts meta.inspect
      meta.each_key do |key|
        init_meta(meta_root[metakey], key, meta[key])
      end
    end
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
    
    notify_observers()
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

  def insert_brother_node(path, node)
    @rootNode.getNode(path).add_rightbrother_node(node)
  end
   
  def insert_node(parent_path, node)
    @rootNode.getNode(parent_path).addNode(node)
  end
  
  def getNode(pathNode)
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
        parsed = @novedit_io.parse_file_head(@filename)
        @modes = parsed['modes']
      rescue
        errmes=$!.to_s
        case errmes
        when "novedit:modules:io:Bad format"
          err_message = _("Bad file format")
        end
      end

      # Next condition commented out in order to allow the opening of new files at startup (resolve http://code.google.com/p/novedit/issues/detail?id=43)
#      if lu.nil?
#        dialog = Gtk::MessageDialog.new(@appwindow, Gtk::Dialog::MODAL, 
#                                        Gtk::MessageDialog::ERROR, 
#                                        Gtk::MessageDialog::BUTTONS_CLOSE, 
#                                              "Cannot open " + @filename + ((err_message.nil?)?errmes:err_message))
#        dialog.run
#        dialog.destroy
#
#        raise("Cannot open " + @filename + ((err_message.nil?)?(errmes.to_s):err_message))
#      end
      @rootNode = lu
      if not @rootNode
        @rootNode = NoveditNode.new("root")
        @rootNode = @rootNode.addNode(NoveditNode.new($DEFAULT_NODE_NAME))
      end
      @is_saved = true
    end
  end
  
  def open_file(filename)
    if @filename != filename
      @filename = filename
      fill_tree
    end
  end
end
