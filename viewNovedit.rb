#
# Vue Novedit
#

require 'libglade2'

class ViewNovedit
  attr_accessor :treeview, :textview, :undopool, :redopool, :buffer
  
  #
  # Common
  #
  def iter_on_screen(iter, mark_str)
    @buffer.place_cursor(iter) 
    @textview.scroll_mark_onscreen(@buffer.get_mark(mark_str))
  end

  def update_appbar
    @appbar.pop(@appbar_context_id)
    iter = @buffer.get_iter_at_mark(@buffer.get_mark("insert"))
    @appbar.push(@appbar_context_id, "Line: #{iter.line + 1}, Column: #{iter.line_offset + 1}")
  end
  
  def write_appbar(text)
    @appbar.pop(@appbar_context_id)
    @appbar.push(@appbar_context_id, text)
  end

  def initialize(controler, model)
    #Liaison MVC
    @controler = controler
    @model = model
    @model.add_observer(self)
    
    #Construction de l'interface à partir du modèle Glade
    @pathglade = File.dirname($0) + "/glade/noveditBase.glade"
    @glade = GladeXML.new(@pathglade) {|handler| method(handler)}
    @appwindow = @glade.get_widget("appwindow")
    @appbar = @glade.get_widget("statusbar")
    @appbar_context_id = @appbar.get_context_id('status_context')
    
    #Arbre - composé de noeuds texte éditables
    @treeview = @glade.get_widget('treeview')
    cellrenderer = Gtk::CellRendererText.new
    cellrenderer.editable=true
    cellrenderer.signal_connect("edited"){ |cell, path, newtext| @controler.on_cell_edited(path, newtext) }
    col = Gtk::TreeViewColumn.new("élements", cellrenderer, :text=>0)
    @treeview.append_column(col)
    
    #Drag and drop
    #Source
    @treeview.enable_model_drag_source(Gdk::Window::BUTTON1_MASK, [['text/plain', 0, 0]], Gdk::DragContext::ACTION_DEFAULT | Gdk::DragContext::ACTION_MOVE)
    @treeview.signal_connect("drag-data-get") do |treeview, context, selection, info, timestamp|
       @controler.on_drag_data_get(treeview, context, selection, info, timestamp)
    end
    #Destination
    @treeview.enable_model_drag_dest([['text/plain', 0, 0]], Gdk::DragContext::ACTION_DEFAULT | Gdk::DragContext::ACTION_MOVE)
    @treeview.signal_connect("drag-data-received") do |treeview, context, x, y, selection, info, timestamp| 
      @controler.on_drag_data_received(treeview, context, x, y, selection, info, timestamp)
    end

    
    #Sélection d'un noeud
    @treeview.selection.signal_connect("changed"){ |widget| @controler.on_select_node(widget) }
    
    #Menu contextuel sur l'arbre
    tree_context_menu = Gtk::Menu.new
    item = Gtk::MenuItem.new("Insert element")
    item.signal_connect("activate") { @controler.on_insert }
    tree_context_menu.append(item)
    tree_context_menu.show_all
    # Popup the menu on right click
    @treeview.signal_connect("button_press_event") do |widget, event|
      if event.kind_of? Gdk::EventButton
        case event.button
        when 3
        	tree_context_menu.popup(nil, nil, event.button, event.time)
        end       
      end
    end
    # Popup the menu on Shift-F10
    @treeview.signal_connect("popup_menu") { tree_context_menu.popup(nil, nil, 0, Gdk::Event::CURRENT_TIME) }
    
    #Tabs document
    @tabs = @glade.get_widget('notebook1')
    undoc = @glade.get_widget('scrolledwindow')
    @textview = @glade.get_widget('textview')
    
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
      update_appbar
    end
    @buffer.signal_connect("mark-set") do |w, iter, mark|
      update_appbar
    end
    @textview.signal_connect("move-cursor") do
      update_appbar
    end
  end

  def insert_model_node(parent_node, model_node)
    iter = @treeview.model.append(parent_node)
    iter[0] = model_node.name
    model_node.childs.each{|node| insert_model_node(iter, node)}
  end

  def update
    @appwindow.set_title(@model.filename + " - " ) if not @model.filename.nil?
    
    @treeview.model.clear
    @model.childs.each do |modelNode|
      insert_model_node(nil, modelNode)
    end
    @buffer.set_text(@model.currentNode.text)
    
#    @tabs.set_tab_label(@tabs.children[@tabs.page], Gtk::Label.new(File.basename(@currentDocument.model.filename)))
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
    File.open(@filename){|f| ret = f.readlines.join }
  end
  
  private

  def on_open_file(widget) 
    @controler.open_file
  end

  def on_new_file(widget)
    @controler.new_file()
  end

  def on_save_as_file(widget)
    select_file
    @controler.save_file(self) if @model.filename
  end

  def on_save_file(widget)
    @controler.on_save_file()
  end
  
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
  #
  # Unfo, Redo
  #
  def on_undo(widget)
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

  def on_redo(widget)
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

  #
  # Find, Replace
  #
  def replace_selected_text(str, start_iter, end_iter)
    @buffer.begin_user_action
    @buffer.delete(start_iter, end_iter)
    @buffer.insert(start_iter, str)
    @buffer.end_user_action
    iter_on_screen(start_iter, "insert")
  end

  def find_and_select(find, backwards, parent)
    text = @glade.get_widget(find).text
    search_flags = Gtk::TextIter::SEARCH_TEXT_ONLY
    iter = @buffer.get_iter_at_mark(@buffer.get_mark("insert"))
    if @glade.get_widget(backwards).active?
      match_iters = iter.backward_search(text, search_flags)
      next_iter = match_iters if match_iters
    else
      match_iters = iter.forward_search(text, search_flags)
      next_iter = [match_iters[1], match_iters[0]] if match_iters
    end

    if match_iters
      iter_on_screen(next_iter[0], "insert")
      @buffer.move_mark("selection_bound", next_iter[1])
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

  #Replace dialog
  def on_replace(widget)
    @replace_dialog.show
  end

  #
  # Misc
  #
  def on_about(widget)
    @controler.on_about
  end
end




