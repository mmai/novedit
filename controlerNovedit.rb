#
# Novedit
#

require "viewNovedit.rb"

class ControlerNovedit
  @model
  @view
  @treemodel
  
  def initialize(model)
    @model = model
    @view = ViewNovedit.new(self, model)
    
    #Initialisation de l'arbre 
    @treestore = Gtk::TreeStore.new(String)
    @view.treeview.model = @treestore
    @view.treeview.signal_connect("drag_data_received"){ |dest, selection_data| on_drag_data_received(dest, selection_data) }
    @view.treeview.signal_connect("drag_end"){ |widget, drag_context| on_drag_end(widget, drag_context) }
    
    populateTree(@model, nil)
    new_file
     
    #Boites de dialogues
    pathgladeDialogs = File.dirname($0) + "/noveditDialogs.glade"
    gladeDialogs = GladeXML.new(pathgladeDialogs) {|handler| method(handler)}
    @fileselection = gladeDialogs.get_widget("fileselection")
    @find_dialog = gladeDialogs.get_widget("find_dialog")
    @replace_dialog = gladeDialogs.get_widget("replace_dialog")
    @about_dialog = gladeDialogs.get_widget("aboutdialog1")
  end
  
  def populateTree(nodeModel, nodeView)
    nodeModel.nodes.each do |node|
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
 
  #Insertion d'un nouvel élément dans l'arbre
  def on_insert()
    selectedIter = @view.treeview.selection.selected
    iter = @treestore.append(selectedIter)
    @model.insert_node(iter.path.to_s, NoveditNode.new($DEFAULT_NODE_NAME))
    
    iter[0] = $DEFAULT_NODE_NAME
    @view.treeview.expand_row(selectedIter.path,false)
    @view.treeview.set_cursor(iter.path, @view.treeview.get_column(0), true)
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
  def on_drag_data_received(dest, selection_data)
#    puts "DRAG DATA RECEIVED"
#    p dest
#    p selection_data
  end
  def on_drag_end(widget, context)
    puts "DRAG END"
    p widget
    p context
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