#
# Vue Novedit
#

require 'libglade2'
require 'novedit/lib/novedit_textbuffer.rb'

class ViewNovedit
  attr_accessor :treeview, :tabs, :textview, :buffer, :wordcount_value, :appwindow, :user_action, :is_fullscreen, :is_writeroom
  attr_reader :glade
  
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
    @is_fullscreen = false
    @is_writeroom = false
    #Liaison MVC
    @controler = controler
    @model = model
    @model.add_observer(self)
    
    #Construction de l'interface à partir du modèle Glade
    @pathglade = $INSTALL_PATH + "/glade/noveditBase.glade"
    @glade = Gtk::Builder.new() << @pathglade
#    @glade.translation_domain = File.join($INSTALL_PATH, "locale")
    @glade.translation_domain = "noveditGlade"
    @glade.connect_signals{|handler| method(handler)}
    @fileselection = @glade.get_object("fileselection")

#    @glade = GladeXML.new(@pathglade) {|handler| method(handler)}
    @appwindow = @glade.get_object("appwindow")
    @appbar = @glade.get_object("statusbar")
    @appbar_context_id = @appbar.get_context_id('status_context')
    
    #XXX Temporaire
    @wordcount_value = @glade.get_object("labelNbWordsValue")
    
    #Arbre - composé de noeuds texte éditables
    @treeview = @glade.get_object('treeview')
    cellrenderer = Gtk::CellRendererText.new
    cellrenderer.editable=true
    cellrenderer.signal_connect("edited"){ |cell, path, newtext| @controler.on_cell_edited(path, newtext) }
#    cellrenderer.signal_connect("editing-canceled") { |widget| @controler.on_cell_editing_canceled(widget)}  
    col = Gtk::TreeViewColumn.new("élements", cellrenderer, :text=>0)
    @treeview.append_column(col)
    
    #Treeview Drag and drop
    #Source
    @treeview.enable_model_drag_source(Gdk::Window::BUTTON1_MASK, [['text/plain', 0, 0]], Gdk::DragContext::ACTION_DEFAULT | Gdk::DragContext::ACTION_MOVE)
    @treeview.signal_connect("drag-data-get") do |treeview, context, selection, info, timestamp|
       @controler.on_drag_data_get(treeview, context, selection, info, timestamp)
    end
    #Destination
    @treeview.enable_model_drag_dest([['text/plain', Gtk::Drag::TARGET_SAME_WIDGET, 0]], Gdk::DragContext::ACTION_DEFAULT | Gdk::DragContext::ACTION_MOVE)
    @treeview.signal_connect("drag-data-received") do |treeview, context, x, y, selection, info, timestamp| 
      @controler.on_drag_data_received(treeview, context, x, y, selection, info, timestamp)
    end

    
    #Ouverture / Fermeture d'un noeud
    @treeview.signal_connect("row-collapsed"){ |widget, iter, path| @controler.on_collapse_node(path) }
    @treeview.signal_connect("row-expanded"){ |widget, iter, path| @controler.on_expand_node(path) }
    
    #Sélection d'un noeud
    @treeview.selection.signal_connect("changed"){ |widget| @controler.on_select_node(widget) }
    
    #Menu contextuel sur l'arbre
    tree_context_menu = Gtk::Menu.new
    item = Gtk::MenuItem.new("Insert element")
    item.signal_connect("activate") { @controler.on_insert_child }
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
    
    #Key pressed
    @treeview.signal_connect("key-press-event") { |widget, event| @controler.on_tree_key_pressed(event.keyval)}  

    
    #Tabs document
    @tabs = @glade.get_object('notebook1')
    undoc = @glade.get_object('scrolledwindow')
    @textview = @glade.get_object('textview')
    
    @filename = nil
      
    @textview.buffer = Gtk::TextBuffer.new(NoteTagTable.new)
    @buffer = @textview.buffer
    @buffer.extend(NoveditTextbuffer)
    @textview.signal_connect("key-press-event") do |widget, event|
#      @buffer.on_key_pressed(event.keyval)  #Pour les traitements de type gestion des puces
      @controler.on_key_pressed(event.keyval)  #Pour les traitements de type gestion des puces
    end

    @textview.signal_connect("drag-begin") do |widget, context|
      @controler.on_drag_begin(context)
    end

    @textview.signal_connect("drag-end") do |widget, context|
      @controler.on_drag_end(context)
    end

    @buffer.signal_connect("insert_text") do |w, iter, text, length|
      @controler.on_insert_text(iter, text) if @user_action
    end
    
    @buffer.signal_connect("delete_range") do |w, start_iter, end_iter|
      @controler.on_delete_range(start_iter, end_iter) if @user_action
    end

    @buffer.signal_connect("apply_tag") do |w, tag, start_iter, end_iter|
      @controler.on_apply_tag(tag, start_iter, end_iter) if @user_action
    end

    @buffer.signal_connect("remove_tag") do |w, tag, start_iter, end_iter|
      @controler.on_remove_tag(tag, start_iter, end_iter) if @user_action
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
  
  def check_opened_nodes(model_node)
    if (model_node.is_open)
      @treeview.expand_row(Gtk::TreePath.new(model_node.path), false) 
      model_node.childs.each {|node| check_opened_nodes(node)}
    end
  end

  def maj_title
    title = ""
    if @model.filename.nil?
      title = $TITLE
    else
      title = File.basename(@model.filename) + " (" + File.dirname(@model.filename) + ")"
    end
    title = title + " * " if not @model.is_saved
    @appwindow.set_title(title) 
  end

  def update
    maj_title 
    @treeview.model.clear
#    require 'ruby-debug';debugger
#    puts "\n\n\n=============\n" + @model.currentNode.text 
    puts "#######\n\n"
    puts @model.currentNode.object_id
    puts @model.currentNode.text
    @model.childs.each do |modelNode|
      insert_model_node(nil, modelNode)
      check_opened_nodes(modelNode)
    end
#    @buffer.set_text(@model.currentNode.text)
#    puts @model.currentNode.text
    @buffer.deserialize(@model.currentNode.text)
    
#    @tabs.set_tab_label(@tabs.children[@tabs.page], Gtk::Label.new(File.basename(@currentDocument.model.filename)))
  end

  def on_quit(*widget)
    @controler.on_quit
  end

  def on_selectall(widget)
    @buffer.place_cursor(@buffer.end_iter)
    @buffer.move_mark(@buffer.get_mark("selection_bound"), @buffer.start_iter)
  end
    
  private

  def on_open_file(widget) 
    @controler.open_file
  end

  def on_new_file(widget)
    @controler.new_file()
  end

  def on_save_as_file(widget)
    @controler.on_save_as()
  end

  def on_save_file(widget)
    @controler.on_save_file()
  end
  
  def on_notebook_switch_page(widget, page, page_num)
    @controler.on_notebook_switch_page(widget, page, page_num)
  end
  
  def on_clear()
    @buffer.set_text("")
  end
  def on_cut(widget)
     @textview.signal_emit("cut_clipboard")
  end
  def on_paste(widget)
    @controler.on_paste(widget)
  end
  def on_copy(widget)
     @textview.signal_emit("copy_clipboard")
  end
  def on_fullscreen_activate(widget)
     @controler.on_toggle_fullscreen()
  end
  def on_writeroom_activate(widget)
     @controler.on_toggle_writeroom()
  end
#
  # Unfo, Redo
  #
  def on_undo(widget)
    @controler.on_undo(widget)
  end

  def on_redo(widget)
    @controler.on_redo(widget)
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
    text = @glade.get_object(find).text
    search_flags = Gtk::TextIter::SEARCH_TEXT_ONLY
    iter = @buffer.get_iter_at_mark(@buffer.get_mark("insert"))
    if @glade.get_object(backwards).active?
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

  # Text formating toolbar
  def on_text_bold(widget)
    @controler.on_text_bold
  end

  def on_text_italic(widget)
    @controler.on_text_italic
  end

  def on_text_centered(widget)
    @controler.on_text_centered
  end

  def on_justify_right(widget)
    @controler.on_justify_right
  end


  def on_justify_left(widget)
    @controler.on_justify_left
  end


  def on_text_highlight(widget)
    @controler.on_text_highlight
  end

  def on_text_strikethrough(widget)
    @controler.on_text_strikethrough
  end

  def on_text_size_huge(widget)
    @controler.on_text_size('huge')
  end
 
  def on_bulleted_list(widget)
    @controler.on_bulleted_list
  end
   
  # Find dialog
  def on_find(widget)
    @controler.on_find
  end

  #Replace dialog
  def on_replace(widget)
    @controler.on_replace
  end

  #
  # Misc
  #
  def on_about(widget)
    @controler.on_about
  end

  def on_help(widget)
    @controler.on_help
  end

  def on_preferences_activate(widget)
    @controler.on_preferences
  end

  def on_edit_plugins(widget)
    @controler.on_edit_plugins
  end
end




