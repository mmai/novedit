#
# Novedit
#

require "viewNovedit.rb"

require "modules/io/novedit_io_yaml.rb"
require "lib/undo_redo.rb"

class ControlerNovedit < UndoRedo
  @model
  @view
  @treemodel
  
  def initialize(model)
    super()
    @model = model
    @model.set_io(NoveditIOYaml.new)
    @view = ViewNovedit.new(self, model)
    
    #Initialisation de l'arbre 
    @treestore = Gtk::TreeStore.new(String)
    @view.treeview.model = @treestore
    
    populateTree(@model, nil)
    new_file
     
    #Boites de dialogues
    pathgladeDialogs = File.dirname($0) + "/glade/noveditDialogs.glade"
    gladeDialogs = GladeXML.new(pathgladeDialogs) {|handler| method(handler)}
    @fileselection = gladeDialogs.get_widget("fileselection")
    @find_dialog = gladeDialogs.get_widget("find_dialog")
    @replace_dialog = gladeDialogs.get_widget("replace_dialog")
    @about_dialog = gladeDialogs.get_widget("aboutdialog1")
  end
  
  def populateTree(nodeModel, nodeView)
    nodeModel.childs.each do |node|
      iter = @treestore.append(nodeView)
      iter[0] = node.name
      populateTree(node, iter)
    end
  end
  
  def open_file()
    filename = select_file
    if filename
      @model.open_file(filename)
    end
    @view.buffer.place_cursor(@view.buffer.start_iter)
    @view.textview.has_focus = true
  end
  
  def select_file
    filename = nil
    @fileselection.set_filename(Dir.pwd + "/")
    ret = @fileselection.run
    if ret == Gtk::Dialog::RESPONSE_OK
      if File.directory?(@fileselection.filename)
        dialog = Gtk::MessageDialog.new(@appwindow, Gtk::Dialog::MODAL, 
                                        Gtk::MessageDialog::ERROR, 
                                        Gtk::MessageDialog::BUTTONS_CLOSE, 
                                        "Directory was selected. Select a text file.")
        dialog.run
        dialog.destroy
        @fileselection.hide
        select_file
      else
        filename = @fileselection.filename
        @fileselection.hide
      end
    else
      @fileselection.hide
    end
    return filename
  end
  
  def new_file()
    @model.open_file(nil)
  end
  
  def on_save_file
      @model.currentNode.text = @view.buffer.text
      @model.filename = select_file() unless @model.filename
      @model.save_file if @model.filename
  end
  
  #About Dialog
  def on_about()
    @about_dialog.show
  end
  
  ##############################
  # Évènements sur l'arbre
  #############################
  def on_tree_key_pressed(keyval)
      case keyval
      when 65379 #Ins
        on_insert_child
      when 65293 #Enter
        on_insert_sibling
      when 65535 #Suppr
        on_delete_node
      when 122 # z
        undo_command
      when 121 # y
        redo_command
      end
    end
 
  #Insertion d'un nouveau sous-élément
  def on_insert_child()
    selectedIter = @view.treeview.selection.selected
    if not selectedIter.nil?
      newnode = NoveditNode.new($DEFAULT_NODE_NAME)
      parent = @model.getNode(selectedIter.path.to_s)
      todo = lambda {
        parent.addNode(newnode)
        parent.is_open = true
        @view.update
      }
      toundo = lambda {
        newnode.detach
        @view.update
      }
      todo.call
      @tabUndo << Command.new(todo, toundo)
      @view.treeview.set_cursor(Gtk::TreePath.new(newnode.path), @view.treeview.get_column(0), true)
    end
  end
  
  #Insertion d'un nouveau frère
  def on_insert_sibling()
    selectedIter = @view.treeview.selection.selected
    if not selectedIter.nil?
      selectedIter = selectedIter.parent
      if selectedIter.nil?
        pathparent = ""
      else 
        pathparent = selectedIter.path.to_s
      end
        
      newnode = NoveditNode.new($DEFAULT_NODE_NAME)
      todo = lambda {
        @model.insert_node(pathparent, newnode)
        @view.update
      }
      toundo = lambda{
        newnode.detach
        @view.update
      }
      todo.call
      @tabUndo << Command.new(todo, toundo)
      @view.treeview.set_cursor(Gtk::TreePath.new(newnode.path), @view.treeview.get_column(0), true)
    end
  end
  
  #Suppression d'un noeud
  def on_delete_node
    selectedIter = @view.treeview.selection.selected
    if not selectedIter.nil?
      node = @model.getNode(selectedIter.path.to_s)
      nodepos = node.path.split(":").last.to_i
      nodeparent = node.parent
      todo = lambda {
  #      @model.remove_node(selectedIter.path.to_s)
        node.detach
        @view.update
      }
      toundo = lambda {
        nodeparent.addNode(node, nodepos)
        @view.update
      }
      todo.call
      @tabUndo << Command.new(todo, toundo)
    end
  end
  
  #Sélection d'un noeud de l'arbre
  def on_select_node(selectionWidget)
    @model.currentNode.text = @view.buffer.get_text
    iter = selectionWidget.selected
    @model.currentNode = @model.getNode(iter.path.to_s) unless iter.nil?
    @view.buffer.set_text @model.currentNode.text
  end
  
  #Édition d'un élément de l'arbre
  def on_cell_edited(path, newtext)
    node = @model.getNode(path)
    iter = @treestore.get_iter(path)
    iterpath = iter.path
    itertxt = iter[0]
    if (newtext!=itertxt)
      todo = lambda {
        node.name = newtext
        @view.update
      }
      toundo = lambda {
        node.name = itertxt
        @view.update
      }
      todo.call
      @tabUndo << Command.new(todo, toundo)
      
      @view.treeview.set_cursor(iterpath, @view.treeview.get_column(0), false)
    end
  end
  
  #Drag and drop
  def on_drag_data_get(treeview, context, selection, info, timestamp)
      iter = treeview.selection.selected
      selection.text = iter.to_s
  end
  
  def on_drag_data_received(treeview, context, x, y, selection, info, timestamp)
    drop_info = treeview.get_dest_row_at_pos(x, y)
    if drop_info
      path, position = drop_info
      pathDest = path.to_s
      pathOrig = selection.text
      
      node = @model.getNode(pathOrig)
      node_pos = pathOrig.split(":").last.to_i
      node_parent = node.parent
      node_newparent = @model.getNode(pathDest)
      node_rightbrother = node.rightbrother
      
      node_newpos = nil
      if position == Gtk::TreeView::DROP_BEFORE
        node_newpos = node_newparent.pos
        node_newparent = node_newparent.parent
      elsif position == Gtk::TreeView::DROP_AFTER
        node_newpos = node_newparent.pos + 1
        node_newparent = node_newparent.parent
      end
      
      #On met à jour le modèle
      todo = lambda {
        node.move_to(node_newparent, node_newpos)
        @view.update
      }
      toundo = lambda {
        node.move_to(node_parent, node_pos)
        @view.update
      }
      begin
        todo.call
        @tabUndo << Command.new(todo, toundo)
      rescue TreeNodeException
        @view.write_appbar "Mouvement interdit!"
      end
     end
  end
  
  def on_expand_node(path)
    @model.getNode(path.to_s).is_open = true
  end
  
  def on_collapse_node(path)
    @model.getNode(path.to_s).is_open = false
  end
  
  ########################
  # Actions sur le texte
  ########################
          
  def on_insert_text(iter, text)
    @model.currentNode.undopool <<  ["insert_text", iter.offset, iter.offset + text.scan(/./).size, text]
    @model.currentNode.redopool.clear
  end
  
  def on_delete_range(start_iter, end_iter)
    text = @view.buffer.get_text(start_iter, end_iter)
    @model.currentNode.undopool <<  ["delete_range", start_iter.offset, end_iter.offset, text]
  end
  
  def on_undo(widget)
    return if @model.currentNode.undopool.size == 0
    action = @model.currentNode.undopool.pop 
    case action[0]
    when "insert_text"
      start_iter = @view.buffer.get_iter_at_offset(action[1])
      end_iter = @view.buffer.get_iter_at_offset(action[2])
      @view.buffer.delete(start_iter, end_iter)
    when "delete_range"
      start_iter = @view.buffer.get_iter_at_offset(action[1])
      @view.buffer.insert(start_iter, action[3])
    end
    @view.iter_on_screen(start_iter, "insert")
    @model.currentNode.redopool << action
  end

  def on_redo(widget)
    return if @model.currentNode.redopool.size == 0
    action = @model.currentNode.redopool.pop 
    case action[0]
    when "insert_text"
      start_iter = @view.buffer.get_iter_at_offset(action[1])
      end_iter = @view.buffer.get_iter_at_offset(action[2])
      @view.buffer.insert(start_iter, action[3])
    when "delete_range"
      start_iter = @view.buffer.get_iter_at_offset(action[1])
      end_iter = @view.buffer.get_iter_at_offset(action[2])
      @view.buffer.delete(start_iter, end_iter)
    end
    @view.iter_on_screen(start_iter, "insert")
    @model.currentNode.undopool << action
  end
  
  private
  
  #Find Dialog
  def on_find_quit(widget)
    @find_dialog.hide
  end
  def on_find_execute(widget)
    find_and_select("find_entry", "backwards_checkbutton", @find_dialog)
  end
  
  #Replace Dialog
  def on_replace_quit(widget)
    @replace_dialog.hide
  end
  def on_replace_execute(widget)
    iter = @buffer.get_iter_at_mark(@buffer.get_mark("insert"))
    sel_bound = @buffer.get_iter_at_mark(@buffer.get_mark("selection_bound"))
    unless iter == sel_bound
      replace_selected_text(@glade.get_widget("replace_replace_entry").text, iter, sel_bound)
    end
    find_and_select("replace_find_entry", "replace_backwards_checkbutton", @replace_dialog)
  end
  
end