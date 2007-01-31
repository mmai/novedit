#
# Novedit
#

require "viewNovedit.rb"

require "modules/io/novedit_io_yaml.rb"

class ControlerNovedit
  @model
  @view
  @treemodel
  
  def initialize(model)
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
 
  #Insertion d'un nouveau sous-élément
  def on_insert_child()
    selectedIter = @view.treeview.selection.selected
    iter = @treestore.append(selectedIter)
    @model.insert_node(selectedIter.path.to_s, NoveditNode.new($DEFAULT_NODE_NAME))
    
    iter[0] = $DEFAULT_NODE_NAME
    @view.treeview.expand_row(selectedIter.path,false)
    @view.treeview.set_cursor(iter.path, @view.treeview.get_column(0), true)
  end
  
  #Insertion d'un nouveau frère
  def on_insert_sibling()
    selectedIter = @view.treeview.selection.selected.parent
    
    iter = @treestore.append(selectedIter)
    @model.insert_node(selectedIter.path.to_s, NoveditNode.new($DEFAULT_NODE_NAME))
    
    iter[0] = $DEFAULT_NODE_NAME
    @view.treeview.expand_row(selectedIter.path,false)
    @view.treeview.set_cursor(iter.path, @view.treeview.get_column(0), true)
  end
  
  #Suppression d'un noeud
  def on_delete_node
    puts "delete"
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
    iter = @treestore.get_iter(path)
    iter[0] = newtext
    @model.getNode(path).name = newtext
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
      #On met à jour le modèle
      begin
        @model.move_node(pathOrig, pathDest)
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