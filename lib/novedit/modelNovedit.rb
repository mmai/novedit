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
    @name + ": "+@text+" [" + childs.map{|child| child.to_s}.join(',') + "]"
  end
end

class NoveditDocument
  include Observable
  
  attr_accessor :rootNode, :modes
    
  def initialize()
    @rootNode = NoveditNode.new("root")
    @modes = []
  end
 
  def metas=(metas)
    @rootNode.metas = metas
  end

  def metas
    @rootNode.metas
  end 

  def update_last_metas(metas)
    metas.each_key do |metakey|
      update_last_meta(@rootNode.metas, metakey, metas[metakey])
    end
  end

  def update_last_meta(meta_root, metakey, meta)
    if not meta_root.has_key?(metakey)
      meta_root[metakey] = meta
    elsif meta.class == Hash
      meta.each_key do |key|
        update_last_meta(meta_root[metakey], key, meta[key])
      end
    else
      meta_root[metakey] = meta
    end
  end


  def init_metas(metas)
    metas.each_key do |metakey|
      init_meta(@rootNode.metas, metakey, metas[metakey])
    end
  end

  def init_meta(meta_root, metakey, meta)
    if not meta_root.has_key?(metakey)
      meta_root[metakey] = meta
    elsif meta.class == Hash
      meta.each_key do |key|
        init_meta(meta_root[metakey], key, meta[key])
      end
    end
  end

  def insert_brother_node(path, node)
    @rootNode.get_node(path).add_rightbrother_node(node)
  end
   
  def insert_node(parent_path, node)
    @rootNode.get_node(parent_path).addNode(node)
  end
  
  def get_node(pathNode)
    node = self
    node = @rootNode.get_node(pathNode) if not pathNode.nil?
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
end

class NoveditModel
  include Observable
  
  attr_accessor :filename, :is_saved, :current_node, :available_modes, :document, :status_funcs
    
  def initialize(filename)
    @novedit_io = NoveditIOBase.instance
    @filename = filename
    @is_saved = true
    @available_modes = []
    @status_funcs = []
    fill_tree
  end

  def modes=(docmodes)
    @document.modes = docmodes
  end

  def modes
    @document.modes
  end
 
  def metas=(metas)
    @document.rootNode.metas = metas
  end

  def metas
    @document.rootNode.metas
  end 

  def init_metas(metas)
    @document.init_metas(metas)
  end

  def get_node(path)
    @document.get_node(path)
  end

  def insert_brother_node(path, node)
    @document.insert_brother_node(path, node)
  end

  def childs
    @document.rootNode.childs
  end

  def fill_tree
    @document = NoveditDocument.new
    if (not @filename.nil?)
      read_file
    else
      @document.rootNode.addNode(NoveditNode.new($DEFAULT_NODE_NAME))
    end
    @current_node = @document.rootNode.get_node("0")
    changed
    
    notify_observers()
  end
  
  def set_io(novedit_io)
    @novedit_io = novedit_io
  end

  def get_io
    return @novedit_io
  end
  
  #
  # File access
  #
  def save_file
    @novedit_io.write(self, @filename)
    @is_saved = true
  end

  def read_file
    if (not @filename.nil?)
      begin
        lu = @novedit_io.read(@filename)
        parsed = @novedit_io.parse_file_head(@filename)
        @document.modes = parsed['modes']
      rescue
        errmes=$!.to_s
        case errmes
        when "novedit:modules:io:Bad format"
          err_message = _("Bad file format")
        end
      end

      @document.rootNode = lu
      if not @document.rootNode
        @document.rootNode = NoveditNode.new("root")
        @document.rootNode = @document.rootNode.addNode(NoveditNode.new($DEFAULT_NODE_NAME))
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
