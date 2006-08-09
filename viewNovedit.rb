#
# Vue Novedit
#

require 'libglade2'


class NoveditDocument
    attr_accessor :textview, :filename, :undopool, :redopool, :buffer
    def initialize(textviewWidget, main_app)
        @textview = textviewWidget
        @filename = nil
        @undopool = Array.new
        @redopool = Array.new
        
        @buffer = @textview.buffer
        @buffer.signal_connect("insert_text") do |w, iter, text, length|
          if @user_action
            @undopool <<  ["insert_text", iter.offset, iter.offset + text.scan(/./).size, text]
            @redopool.clear
          end
        end
        @buffer.signal_connect("delete_range") do |w, start_iter, end_iter|
          text = @buffer.get_text(start_iter, end_iter)
          @undopool <<  ["delete_range", start_iter.offset, end_iter.offset, text] if @user_action
        end
        @buffer.signal_connect("begin_user_action") do
          @user_action = true
        end
        @buffer.signal_connect("end_user_action") do
          @user_action = false
        end
        @buffer.signal_connect("changed") do |w|
          main_app.update_appbar
        end
        @buffer.signal_connect("mark-set") do |w, iter, mark|
          main_app.update_appbar
        end
        @textview.signal_connect("move-cursor") do
          main_app.update_appbar
        end
    end
    
  # Edit textbuffer
  def on_clear()
    @buffer.set_text("")
  end
  def on_cut(widget)
     @textview.signal_emit("cut_clipboard")
  end
  def on_paste(widget)
     @textview.signal_emit("paste_clipboard")
  end
  def on_copy(widget)
     @textview.signal_emit("copy_clipboard")
  end
end

class ViewNovedit

  #
  # Common
  #
  def iter_on_screen(iter, mark_str)
    @currentDocument.buffer.place_cursor(iter) 
    @currentDocument.textview.scroll_mark_onscreen(@currentDocument.buffer.get_mark(mark_str))
  end

  def update_appbar
    @appbar.pop(@appbar_context_id)
    iter = @currentDocument.buffer.get_iter_at_mark(@currentDocument.buffer.get_mark("insert"))
    @appbar.push(@appbar_context_id, "Line: #{iter.line + 1}, Column: #{iter.line_offset + 1}")
  end

  def initialize(controler, model)
    @controler = controler
    @model = model
    
    @tab_docs = Array.new
    
    @pathglade = File.dirname($0) + "/noveditBase.glade"
    @pathgladeDocument = File.dirname($0) + "/noveditDocument.glade"
    @glade = GladeXML.new(@pathglade) {|handler| method(handler)}
    @appwindow = @glade.get_widget("appwindow")
    @appbar = @glade.get_widget("statusbar")
    @appbar_context_id = @appbar.get_context_id('status_context')
    @fileselection = @glade.get_widget("fileselection")
    @find_dialog = @glade.get_widget("find_dialog")
    @replace_dialog = @glade.get_widget("replace_dialog")
    @about_dialog = @glade.get_widget("aboutdialog1")
    @tabs = @glade.get_widget('notebook1')
    
    add_document()
    #Onglet    par dfaut
    #@currentDocument = NoveditDocument.new(@glade.get_widget('textview'), self)
    #@tab_docs << @currentDocument

    update_appbar
  end

  def on_quit(*widget)
    Gtk.main_quit
  end

  def on_selectall(widget)
    @buffer.place_cursor(@buffer.end_iter)
    @buffer.move_mark(@buffer.get_mark("selection_bound"), @buffer.start_iter)
  end
    
  #
  # File access
  #
  def save_file
    File.open(@filename, "w"){|f| 
      f.write(@buffer.get_text(*@buffer.bounds)) 
    }
  end

  def read_file
    File.open(@currentDocument.filename){|f| ret = f.readlines.join }
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

  def on_open_file(widget) 
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

  def add_document
    glade_doc = GladeXML.new(@pathgladeDocument, 'scrolledwindow') {|handler| method(handler)}
    undoc = glade_doc.get_widget('scrolledwindow')
    @tabs.append_page(undoc)
    @currentDocument = NoveditDocument.new(glade_doc.get_widget('textview'), self)
    @tab_docs << @currentDocument 
    @tabs.page=@tab_docs.index(@currentDocument)
    return @currentDocument
  end

  def on_new_file(widget)
    @controler.new_file(widget)
  end

  def on_save_as_file(widget)
    select_file
    save_file if @currentDocument.filename
  end

  def on_save_file(widget)
    if @currentDocument.filename
      save_file
    else
      on_save_as_file(widget)
    end
  end
  
  def on_clear(widget)
    @currentDocument.on_clear
  end
  def on_cut(widget)
     @currentDocument.on_cut(widget)
  end
  def on_paste(widget)
     @currentDocument.on_paste(widget)
  end
  def on_copy(widget)
     @currentDocument.on_copy(widget)
  end
  #
  # Unfo, Redo
  #
  def on_undo(widget)
    return if @currentDocument.undopool.size == 0
    action = @currentDocument.undopool.pop 
    case action[0]
    when "insert_text"
      start_iter = @currentDocument.buffer.get_iter_at_offset(action[1])
      end_iter = @currentDocument.buffer.get_iter_at_offset(action[2])
      @currentDocument.buffer.delete(start_iter, end_iter)
    when "delete_range"
      start_iter = @currentDocument.buffer.get_iter_at_offset(action[1])
      @currentDocument.buffer.insert(start_iter, action[3])
    end
    iter_on_screen(start_iter, "insert")
    @currentDocument.redopool << action
  end

  def on_redo(widget)
    return if @currentDocument.redopool.size == 0
    action = @currentDocument.redopool.pop 
    case action[0]
    when "insert_text"
      start_iter = @currentDocument.buffer.get_iter_at_offset(action[1])
      end_iter = @currentDocument.buffer.get_iter_at_offset(action[2])
      @currentDocument.buffer.insert(start_iter, action[3])
    when "delete_range"
      start_iter = @currentDocument.buffer.get_iter_at_offset(action[1])
      end_iter = @currentDocument.buffer.get_iter_at_offset(action[2])
      @currentDocument.buffer.delete(start_iter, end_iter)
    end
    iter_on_screen(start_iter, "insert")
    @currentDocument.undopool << action
  end

  #
  # Find, Replace
  #
  def replace_selected_text(str, start_iter, end_iter)
    @currentDocument.buffer.begin_user_action
    @currentDocument.buffer.delete(start_iter, end_iter)
    @currentDocument.buffer.insert(start_iter, str)
    @currentDocument.buffer.end_user_action
    iter_on_screen(start_iter, "insert")
  end

  def find_and_select(find, backwards, parent)
    text = @glade.get_widget(find).text
    search_flags = Gtk::TextIter::SEARCH_TEXT_ONLY
    iter = @currentDocument.buffer.get_iter_at_mark(@currentDocument.buffer.get_mark("insert"))
    if @glade.get_widget(backwards).active?
      match_iters = iter.backward_search(text, search_flags)
      next_iter = match_iters if match_iters
    else
      match_iters = iter.forward_search(text, search_flags)
      next_iter = [match_iters[1], match_iters[0]] if match_iters
    end

    if match_iters
      iter_on_screen(next_iter[0], "insert")
      @currentDocument.buffer.move_mark("selection_bound", next_iter[1])
    else 
      dialog = Gtk::MessageDialog.new(parent, Gtk::Dialog::MODAL, 
                                      Gtk::MessageDialog::INFO, 
                                      Gtk::MessageDialog::BUTTONS_CLOSE, 
                                      "The string #{text} has not been found.")
      dialog.run
      dialog.destroy
    end
  end
    
  # Find dialog
  def on_find(widget)
    @find_dialog.show
  end
  def on_find_quit(widget)
    @find_dialog.hide
  end
  def on_find_execute(widget)
    find_and_select("find_entry", "backwards_checkbutton", @find_dialog)
  end

  #Replace dialog
  def on_replace(widget)
    @replace_dialog.show
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

  #
  # Misc
  #
  def on_about(widget)
    @about_dialog.show
  end
end




