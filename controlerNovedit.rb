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
    
    treeparent = @treestore.append(nil)
    treeparent[0] = "Base"
    iter = @treestore.append(treeparent)
    iter[0] = "item1"
    iter = @treestore.append(treeparent)
    iter[0] = "item2"
    
    new_file
    #@view.add_document
    #@view.update_appbar 
     
    #Boites de dialogues
    pathgladeDialogs = File.dirname($0) + "/noveditDialogs.glade"
    gladeDialogs = GladeXML.new(pathgladeDialogs) {|handler| method(handler)}
    @fileselection = gladeDialogs.get_widget("fileselection")
    @find_dialog = gladeDialogs.get_widget("find_dialog")
    @replace_dialog = gladeDialogs.get_widget("replace_dialog")
    @about_dialog = gladeDialogs.get_widget("aboutdialog1")
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
    if @view.buffer.modified?
      @model.text = @view.buffer.text
      @model.filename = select_file() unless @model.filename
      @model.save_file if @model.filename
      @view.buffer.modified=false
    end
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
    iter = @treestore.append(@view.treeview.selection.selected)
    iter[0] = "new item"
    @view.treeview.set_cursor(iter.path, @view.treeview.get_column(0), true)
  end
  
  #Édition d'un élément de l'arbre
  def on_cell_edited(path, newtext)
    @treestore.get_iter(path)[0] = newtext
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




