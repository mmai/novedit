#
# Novedit
#

require "viewNovedit.rb"

class ControlerNovedit
  @model
  @view
  
  def initialize(model)
    @model = model
    @view = ViewNovedit.new(self, model) 
    @view.add_document
    @view.update_appbar 
     
    #Boites de dialogues
    pathgladeDialogs = File.dirname($0) + "/noveditDialogs.glade"
    gladeDialogs = GladeXML.new(pathgladeDialogs) {|handler| method(handler)}
    @fileselection = gladeDialogs.get_widget("fileselection")
    @find_dialog = gladeDialogs.get_widget("find_dialog")
    @replace_dialog = gladeDialogs.get_widget("replace_dialog")
    @about_dialog = gladeDialogs.get_widget("aboutdialog1")
  end
  
  def on_find_quit(widget)
    @find_dialog.hide
  end
  def on_find_execute(widget)
    find_and_select("find_entry", "backwards_checkbutton", @find_dialog)
  end
  
    def on_replace_quit(widget)
    @replace_dialog.hide
  end
  def on_replace_execute(widget)
    iter = @currentDocument.buffer.get_iter_at_mark(@buffer.get_mark("insert"))
    sel_bound = @currentDocument.buffer.get_iter_at_mark(@buffer.get_mark("selection_bound"))
    unless iter == sel_bound
      replace_selected_text(@glade.get_widget("replace_replace_entry").text, 
                            iter, sel_bound)
    end
    find_and_select("replace_find_entry", 
                    "replace_backwards_checkbutton", @replace_dialog)
  end
  
  def new_file(widget)
    modelDocument = @model.add_document
    viewDocument = @view.add_document
    viewDocument.on_clear()
  end
  
  def open_file()
    filename = select_file
    if filename
        #Le fichier est-il dj ouvert ?
        if doc = @tab_docs.find { |doc| doc.filename == filename}
            @currentDocument = doc 
            @tabs.page=@tab_docs.index(@currentDocument)
        else
            #Premier onglet vide ?
            if @currentDocument.filename.nil?
                undoc = @glade.get_widget("scrolledwindow")
            else
              add_document
            end
            
            @currentDocument.filename = filename
            @appwindow.set_title(filename + " - " + TITLE)
            @tabs.set_tab_label(undoc, Gtk::Label.new(File.basename(filename)))
            text = read_file
            @currentDocument.buffer.set_text(text)
        end
    end
    @currentDocument.buffer.place_cursor(@currentDocument.buffer.start_iter)
    @currentDocument.textview.has_focus = true
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
end





