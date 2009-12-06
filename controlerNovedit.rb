#
# Novedit
#

require "rbconfig" #For launching another instance of Novedit (See on_help)
require "find" #For plugins detection
require "lib/pluginsystem.rb"

require "viewNovedit.rb"
require "lib/settings.rb"

require "modules/io/novedit_io_yaml.rb"
#require "modules/io/novedit_io_html.rb"
require "lib/undo_redo.rb"
require "lib/novedit_xml.rb"

bindtextdomain("controlerNovedit", "./locale")

#Ce module utilisé par le controleur fait office de proxy pour les plugins
#Il traduit les modifications de l'interface et les ajouts de fonctions demandées par les plugins
#dans l'implémentation du controlleur et de la vue. 
module NoveditPluginsProxy
  attr_accessor :model, :view

  def addTab(widget, title, on_click_handler)
    label = Gtk::Label.new(title)
    @view.tabs.append_page(widget, label)
    @view.tabs.show_tabs = @view.tabs.n_pages > 1
    page_num = @view.tabs.page_num(widget)
    @notebook_actions[page_num] = on_click_handler
    return page_num
  end

  def removeTab(widget)
    @view.tabs.remove_page(widget)
    @view.tabs.show_tabs = @view.tabs.n_pages > 1
  end

  #Menu
  #Add a menu entry leading to an action :
  # can't contain submenus (use addMenuContainer instead)
  def addMenu(name, function=nil, parent=nil)
    if parent.class == Gtk::MenuItem
      parent = parent.submenu
    end
    newmenu = Gtk::MenuItem.new(name)
    parent << newmenu
    parent.show_all
  end
  
  #Add a menu containing entries or submenus
  def addMenuContainer(name, parent=nil)
    parent = @view.appwindow.children[0].children[0] if parent.nil?
    top_menu = Gtk::MenuItem.new(name)
    parent << top_menu
    newmenu = Gtk::Menu.new
    top_menu.set_submenu( newmenu )
    parent.show_all
    return top_menu
  end

  #Remove menu container and all its submenus
  def removeMenuContainer(menu)
    removeWidget(menu.submenu) 
    removeWidget(menu)
  end

  def removeWidget(widget)
    if widget.class  == Gtk::Container
      widget.children.each { |widg| removeWidget(widg) }
    end
    widget.destroy
  end
end

class ControlerNovedit < UndoRedo
  include NoveditPluginsProxy
  
  @model
  @view
  
 
  def initialize(model)
    super()
    #Model association (MVC)
    @model = model
    @settings = Settings.new($SETTINGS_FILE)
#    @mysettings['test'] =  'testvalue'
    #Saving mode
    @model.set_io(NoveditIOYaml.new)
#    @model.set_io(NoveditIOHtml.new)
    #Visual interface linking (MVC)
    @view = ViewNovedit.new(self, model)

    if @settings['theme'].nil?
      @settings['theme'] = 'white' #Default theme
    else
      load_theme(@settings['theme'])  
    end

    #Add a recent projects menu item
    manager = Gtk::RecentManager.default
    #define a RecentChooserMenu object
    recent_menu_chooser = Gtk::RecentChooserMenu.new(manager)
    #define a file filter, otherwise all file types will show up
    filter = Gtk::RecentFilter.new()
    filter.add_application($PROGNAME) 
    recent_menu_chooser.add_filter(filter)
    #add a signal to open the selected file
    recent_menu_chooser.signal_connect('item-activated'){ recent_item_activated(recent_menu_chooser)}
    #Attach the RecentChooserMenu to the main menu item
    menu_recents = @view.glade.get_object("recents")
    menu_recents.set_submenu(recent_menu_chooser) 

    @view.tabs.show_tabs = @view.tabs.n_pages > 1

    #Association des fonctions de mise en forme à la barre d'outils texte
#    @text_tags = Hash.new
#    @text_tags['Bold'] = Gtk::TextTag.new;
#    @text_tags['Bold'].weight=Pango::FontDescription::WEIGHT_BOLD
#    @view.buffer.tag_table.add(@text_tags['Bold']);
#    @text_tags['Italic'] = Gtk::TextTag.new;
#    @text_tags['Italic'].style=Pango::FontDescription::STYLE_ITALIC
#    @view.buffer.tag_table.add(@text_tags['Italic']);

#    @view.buffer.tag_table = NoteTagTable.new

    #Tree initialisation
    @treestore = Gtk::TreeStore.new(String)
    @view.treeview.model = @treestore
    
    populateTree(@model, nil)
    
    #Load the file given as a parameter
    @model.open_file($*[0])

    #Notebook
    @notebook_actions = Array.new
     
    #Dialog windows
    pathgladeDialogs = File.dirname($0) + "/glade/noveditDialogs.glade"
    @gladeDialogs = Gtk::Builder.new()
    @gladeDialogs << pathgladeDialogs
    #@gladeDialogs.translation_domain = File.join($INSTALL_PATH, "locale")
    @gladeDialogs.translation_domain = "noveditGlade"
    @gladeDialogs.connect_signals{|handler| method(handler)}
    @find_dialog = @gladeDialogs.get_object("find_dialog")
    @replace_dialog = @gladeDialogs.get_object("replace_dialog")
    @about_dialog = @gladeDialogs.get_object("aboutdialog1")
    @edit_plugins_dialog = @gladeDialogs.get_object("edit_plugins")
    @preferences_dialog = @gladeDialogs.get_object("preferences_dialog")
    
    #Keyboard shortcuts : XXX ctrl-z and ctrl-y are not supported by glade menus (like ctrl-x for example) ?!?
    ag = Gtk::AccelGroup.new
    #Undo : Ctrl-Z
    ag.connect(Gdk::Keyval::GDK_Z, Gdk::Window::CONTROL_MASK, Gtk::ACCEL_VISIBLE) {
     on_undo(nil) 
    }
    #Redo : Ctrl-Y 
    ag.connect(Gdk::Keyval::GDK_Y, Gdk::Window::CONTROL_MASK, Gtk::ACCEL_VISIBLE) {
     on_redo(nil) 
    }
    #FullScreen : F11
    ag.connect(Gdk::Keyval::GDK_F11, 0, Gtk::ACCEL_VISIBLE) {
      on_toggle_fullscreen()
    }
    @view.appwindow.add_accel_group(ag)
    #End keyboard shortcuts

    init_plugins
  end

  def load_plugins(force=false)
    Find.find($DIR_PLUGINS) do |path|
      if FileTest.directory?(path)
        if File.basename(path)[0] == ?.
          Find.prune       # Don't look any further into this directory.
        else
          next
        end
      elsif File.basename(path) == "init.rb"
        require path
      end
    end
  end

  def init_plugins
    load_plugins
    #Plugins settings creation
    @settings['plugins'] = Hash.new if (@settings['plugins'].nil?) 

    #Initialisation des plugins : on exécute la fonction plugin_init() des fichiers 'init.rb'
    # de chaque dossier(=plugin) du répertoire 'plugins'.   
    Plugin.registered_plugins.keys.each do |plugin_name|
      if @settings['plugins'][plugin_name].nil?
        @settings['plugins'][plugin_name] = {'enabled' => false} 
      end
      #Initiate plugin if it is enabled in user settings
      begin
        if @settings['plugins'][plugin_name]['enabled']
          plugin = Plugin.registered_plugins[plugin_name]
          plugin.enable(self)
        end
      rescue NoMethodError
        #puts plugin_name + " plugin init : Undefined setting"
      end
    end
  end

  def populateTree(nodeModel, nodeView)
    nodeModel.childs.each do |node|
      iter = @treestore.append(nodeView)
      iter[0] = node.name
      populateTree(node, iter)
    end
  end
  
  def set_saved()
      @model.is_saved = true
      @view.maj_title
  end

  def set_not_saved()
      @model.is_saved = false
      @view.maj_title
  end

  def remember_file(filename)
    manager = Gtk::RecentManager.default()
    manager.add_item('file://' + filename)
  end

  def load_file(filename)
    if filename
      @model.open_file(filename)
      remember_file(filename)
    end
    @view.buffer.place_cursor(@view.buffer.start_iter)
    @view.textview.has_focus = true
    @view.update
    set_saved
  end

  def open_file()
    if @model.is_saved
      filename = select_file
      load_file(filename)
    end
  end
  
  def select_file
    filename = nil
    filedialog = Gtk::FileChooserDialog.new("Open File",
                                        nil,
                                        Gtk::FileChooser::ACTION_OPEN,
                                        nil,
                                        [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                        [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])

    filedialog.set_filename(Dir.pwd + "/")
    ret = filedialog.run
    if ret == Gtk::Dialog::RESPONSE_ACCEPT 
      if File.directory?(filedialog.filename)
        dialog = Gtk::MessageDialog.new(@appwindow, Gtk::Dialog::MODAL, 
                                        Gtk::MessageDialog::ERROR, 
                                        Gtk::MessageDialog::BUTTONS_CLOSE, 
                                        _("Directory was selected. Select a text file."))
        dialog.run
        dialog.destroy
        filedialog.hide
        select_file
      else
        filename = filedialog.filename
        filedialog.hide
      end
    else
      filedialog.hide
    end
    return filename
  end

  def show_message(message)
    dialog = Gtk::MessageDialog.new(@appwindow, Gtk::Dialog::MODAL, 
                                        Gtk::MessageDialog::INFO, 
                                        Gtk::MessageDialog::BUTTONS_CLOSE, 
                                        message)
    response = dialog.run
    dialog.destroy
  end
  
  def new_file()
    @model.open_file(nil)
  end
  
  def on_save_file
    @model.currentNode.text = @view.buffer.serialize()
    while not @model.filename
      selected_file = select_file()
      return false if selected_file.nil? #Annulation
      if File.exists?(selected_file)
        dialog = Gtk::MessageDialog.new(@appwindow, Gtk::Dialog::MODAL, 
                                        Gtk::MessageDialog::QUESTION, 
                                        Gtk::MessageDialog::BUTTONS_YES_NO, 
                                        _("File allready exists. Replace file ?"))
        response = dialog.run
        dialog.destroy
        @model.filename = selected_file if response == Gtk::Dialog::RESPONSE_YES
      else
        @model.filename = selected_file
        remember_file(@model.filename)
      end
    end
    @model.save_file
    set_saved
  end

  def on_save_as
      @model.currentNode.text = @view.buffer.text
      @model.filename = select_file()
      if @model.filename
        @model.save_file
        remember_file(@model.filename)
        set_saved
      end
#      @view.update
  end
  
  #Redraw plugins dialog window
  def edit_plugins_redraw()
    vbox = @gladeDialogs.get_object("checkbuttons_vbox")
    vbox.children.each {|checkbutton| checkbutton.destroy}
    first_done = false
    Plugin.registered_plugins.keys.each do |plugin_name|
      plugin = Plugin.registered_plugins[plugin_name]
      checkbutton = Gtk::CheckButton.new(plugin_name)
      checkbutton.active = @settings['plugins'][plugin_name]['enabled']
      checkbutton.signal_connect("clicked") {
        edit_plugins_show_plugin(plugin)
      }
      vbox << checkbutton
      if !first_done
        edit_plugins_show_plugin(plugin)
        first_done = true
      end
    end
    vbox.show_all
  end

  def edit_plugins_show_plugin(plugin)
    @gladeDialogs.get_object("plugin_title_label").label = plugin.title
    @gladeDialogs.get_object("plugin_authors_text").label = plugin.author
    @gladeDialogs.get_object("plugin_site_text").label = plugin.site
    @gladeDialogs.get_object("plugin_description_text").label = plugin.description
    @gladeDialogs.get_object("plugin_version_text").label = plugin.version
  end

  #Edit plugins Dialog
  def on_edit_plugins()
    edit_plugins_redraw() 
    ret = @edit_plugins_dialog.run
    @edit_plugins_dialog.hide
  end

  def on_edit_plugins_ok()
    #Save plugins status settings and enable / disable them
    vbox = @gladeDialogs.get_object("checkbuttons_vbox")
    vbox.children.each do |checkbutton|
      plugin_name = checkbutton.label
      if checkbutton.active?
        if  not @settings['plugins'][plugin_name]['enabled']
          Plugin.registered_plugins[plugin_name].enable(self)
        end
      else
        if @settings['plugins'][plugin_name]['enabled']
          Plugin.registered_plugins[plugin_name].disable(self)
        end
      end
      @settings['plugins'][plugin_name]['enabled'] = checkbutton.active?
    end
    @settings.save
  end

  #Preferences Dialog
  def preferences_dialog_redraw
    @combo_themes = Gtk::ComboBox.new()
    themes = (Dir.entries($DIR_THEMES).select {|elem| elem !~ /^\.+/}).map {|file| File.basename(file, '.yaml') }
    index = 0
    themes.each do |theme|
      @combo_themes.append_text(theme)
      @combo_themes.active = index if theme == @settings['theme']
      index = index + 1
    end
    @combo_themes.signal_connect('changed') do
      choosen_theme = @combo_themes.active_text 
      load_theme(choosen_theme)
    end

    hboxprefs = @gladeDialogs.get_object("hboxprefs")
    hboxprefs.add(@combo_themes)
    hboxprefs.show_all()
  end

  def on_preferences()
    preferences_dialog_redraw if @combo_themes.nil?
    ret = @preferences_dialog.run
    @preferences_dialog.hide
  end

  def on_preferences_ok()
    choosen_theme = @combo_themes.active_text 
#    load_theme(choosen_theme)

    #Save preferences settings 
    @settings['theme'] = choosen_theme
    @settings.save
  end


  #Help
  def new_instance(file)
    ruby_bin =  File.join(Config::CONFIG["bindir"], Config::CONFIG["ruby_install_name"])
    Thread.new do
      system(ruby_bin + " " + $0 + " " + file)
    end
  end

  def on_help()
    new_instance($HELP_FILE)
  end

  #About Dialog
  def on_about()
    ret = @about_dialog.run
    @about_dialog.hide
  end
  
  ##############################
  # Tree events
  #############################
  def on_tree_key_pressed(keyval)
#    puts "keypressed : "+keyval.to_s
    case keyval
    when 65471 #F2
      rename_node
    when 65379 #Ins
      on_insert_child
    when 65293 #Enter
      on_insert_sibling
    when 65535 #Suppr
      on_delete_node
    end
  end
 
  #Node edition
  def rename_node
    selectedIter = @view.treeview.selection.selected
    if not selectedIter.nil?
      node = @model.getNode(selectedIter.path.to_s)
      @view.treeview.set_cursor(Gtk::TreePath.new(node.path), @view.treeview.get_column(0), true)
      set_not_saved
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
        @view.treeview.set_cursor(Gtk::TreePath.new(newnode.path), @view.treeview.get_column(0), true)
      }
      toundo = lambda {
        nparent = newnode.parent
        newnode.detach
        @view.update
        @view.treeview.set_cursor(Gtk::TreePath.new(nparent.path), @view.treeview.get_column(0), false)
      }
      todo.call
      @tabUndo << Command.new(todo, toundo)
      set_not_saved
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
        @view.treeview.set_cursor(Gtk::TreePath.new(newnode.path), @view.treeview.get_column(0), true)
      }
      toundo = lambda{
        nsibling = newnode.leftbrother
        newnode.detach
        @view.update
        @view.treeview.set_cursor(Gtk::TreePath.new(nsibling.path), @view.treeview.get_column(0), false)
      }
      todo.call
      @tabUndo << Command.new(todo, toundo)
      set_not_saved
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
        node.detach
        @view.update

        #Focus on parent or brother
        node_focus = node.parent
        if node_focus.parent.nil? 
          node_focus = node_focus.leftchild
          @view.treeview.set_cursor(Gtk::TreePath.new(node_focus.path), @view.treeview.get_column(0), false) unless node_focus.nil?
        else
          @view.treeview.set_cursor(Gtk::TreePath.new(node_focus.path), @view.treeview.get_column(0), false)
        end
      }
      toundo = lambda {
        nodeparent.addNode(node, nodepos)
        @view.update
        @view.treeview.set_cursor(Gtk::TreePath.new(node.path), @view.treeview.get_column(0), false)
      }
      todo.call
      @tabUndo << Command.new(todo, toundo)

      set_not_saved
    end
  end
  
  #Sélection d'un noeud de l'arbre
  def on_select_node(selectionWidget)
    @model.currentNode.text = @view.buffer.serialize()
    iter = selectionWidget.selected
    @model.currentNode = @model.getNode(iter.path.to_s) unless iter.nil?
    @view.buffer.deserialize(@model.currentNode.text)
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
      set_not_saved
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
        node_newparent.is_open = true
        @view.update
        @view.treeview.set_cursor(Gtk::TreePath.new(node.path), @view.treeview.get_column(0), false)
      }
      toundo = lambda {
        node.move_to(node_parent, node_pos)
        @view.update
        @view.treeview.set_cursor(Gtk::TreePath.new(node.path), @view.treeview.get_column(0), false)
      }
      begin
        todo.call
        set_not_saved
        @tabUndo << Command.new(todo, toundo)
      rescue TreeNodeException
        @view.write_appbar _("Forbidden move!")
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
  # Text related actions
  ########################

  def on_paste(widget)
    #TODO : si on édite l'arborescence, copie dans le noeud édité, sinon copie dans la page
    @view.textview.signal_emit("paste_clipboard") if @view.textview.focus?
    if @view.treeview.focus?
      selectedIter = @view.treeview.selection.selected
      if not selectedIter.nil?
        selectedIter.set_value(0, 'toto est test')
#        node = @model.getNode(selectedIter.path.to_s)
#        @view.treeview.set_cursor(Gtk::TreePath.new(node.path), @view.treeview.get_column(0), true)
#        @view.treeview.signal_emit("paste_clipboard") 
      end
    end
  end

  def on_key_pressed(keyval)
    key_inserted = false
    insert_mark = @view.buffer.get_mark('insert')
    iter = @view.buffer.get_iter_at_mark(insert_mark)
#    puts "keypressed : "+keyval.to_s
    @view.user_action = true
    case keyval
    when 65293 #Enter
      @model.currentNode.undopool <<  ["action_begin"]
      key_inserted = @view.buffer.add_newline(iter)
      if key_inserted
        @model.currentNode.undopool <<  ["action_end"]
      else
        @model.currentNode.undopool.pop 
      end
    when 65289 #Tab
      @model.currentNode.undopool <<  ["action_begin"]
      key_inserted = @view.buffer.add_tab
      if key_inserted
        @model.currentNode.undopool <<  ["action_end"]
      else
        @model.currentNode.undopool.pop 
      end
    when 65288 #Backspace
      @model.currentNode.undopool <<  ["action_begin"]
      key_inserted = @view.buffer.remove_tab
      if key_inserted
        @model.currentNode.undopool <<  ["action_end"]
      else
        @model.currentNode.undopool.pop 
      end
    end
    @view.user_action = false
    return key_inserted
  end          

  def on_insert_text(iter, text)
    separators_list = [" ", "\n", "\t"]
#    puts text
    
    #On met toutes les lettres d'un même mot dans le même undo/redo
    if (not @model.currentNode.undopool.empty?) and (not separators_list.include?(text)) and (@model.currentNode.undopool.last[0] == "insert_text") and (@model.currentNode.undopool.last[2] == iter.offset)
      last_text = @model.currentNode.undopool.pop
#      @model.currentNode.undopool <<  ["insert_text", last_text[1], last_text[1] + last_text[2] + text.scan(/./).size, last_text[3] + text]
      # We use text.scan(/./) because of utf-8 characters
      @model.currentNode.undopool <<  ["insert_text", last_text[1], last_text[2] + text.scan(/./).size, last_text[3] + text]
    else
      @model.currentNode.undopool <<  ["insert_text", iter.offset, iter.offset + text.scan(/./).size, text]
    end

    #On appelle les traitements spécifiques novedit_textbuffer
#    @view.buffer.on_insert_text(iter, text)

    store_text_redo()
   
    @model.currentNode.redopool.clear
    set_not_saved
  end

  def on_apply_tag(tag, start_iter, end_iter)
#    start_mark = @view.buffer.create_mark(nil, debut, true)
#    end_mark = @view.buffer.create_mark(nil, fin, true)
    @model.currentNode.undopool <<  ["apply_tag", start_iter.offset, end_iter.offset, tag]
    store_text_redo()
  end

  def on_remove_tag(tag, start_iter, end_iter)
#    start_mark = @view.buffer.create_mark(nil, debut, true)
#    end_mark = @view.buffer.create_mark(nil, fin, true)
    @model.currentNode.undopool <<  ["remove_tag", start_iter.offset, end_iter.offset, tag]
    store_text_redo()
  end

  def on_delete_range(start_iter, end_iter)
    #XXX : le problème est qu'il faudrait appeler cette méthode AVANT d'effectuer la suppression et non après.
    
    #We remove all tags in order to call the on_remove_tag function which store the tags in the undopool array
    in_action = @model.currentNode.undopool.last[0] == "action_begin"
    @model.currentNode.undopool <<  ["action_begin"] if not in_action
#    @view.buffer.remove_all_tags(start_iter, end_iter)
    # Remove all tags, one by one
    current_iter = start_iter
    while current_iter.offset <= end_iter.offset
      current_iter.tags.each do |curtag|
        tagend_iter = @view.buffer.get_iter_at_tag_end(current_iter, curtag)
#        endoffset = [tagend_iter.offset, end_iter.offset].min
#        @view.buffer.remove_tag(curtag, current_iter, @view.buffer.get_iter_at_offset(endoffset))
        
        @view.buffer.remove_tag(curtag, current_iter, tagend_iter)
        if tagend_iter.offset > end_iter.offset
          @view.buffer.apply_tag(curtag, @view.buffer.get_iter_at_offset(end_iter.offset + 1), tagend_iter)
        end
      end
      break if not current_iter.forward_char
    end

    text = @view.buffer.get_text(start_iter, end_iter)
    @model.currentNode.undopool <<  ["delete_range", start_iter.offset, end_iter.offset, text]
    @model.currentNode.undopool <<  ["action_end"] if not in_action
    store_text_redo()
    set_not_saved
  end
  
  def store_text_redo()
   textnode = @model.currentNode
    todo = lambda {
      @model.currentNode = textnode
      redo_text
    }
    toundo = lambda {
      @model.currentNode = textnode
      undo_text
    }
    #todo.call
    @tabUndo << Command.new(todo, toundo)
  end

  def undo_text()
    return if @model.currentNode.undopool.size == 0
    action = @model.currentNode.undopool.pop 
    #puts @model.currentNode.undopool.inspect unless @in_action
    case action[0]
    when "action_end"
      @in_action = true
      @model.currentNode.redopool << action
      undo_text while @in_action
    when "action_begin"
      @in_action = false
    when "insert_text"
      start_iter = @view.buffer.get_iter_at_offset(action[1])
      end_iter = @view.buffer.get_iter_at_offset(action[2])
      @view.buffer.delete(start_iter, end_iter)
    when "delete_range"
      start_iter = @view.buffer.get_iter_at_offset(action[1])
      @view.buffer.insert(start_iter, action[3])
    when "remove_tag"
      @view.buffer.apply_tag(action[3], @view.buffer.get_iter_at_offset(action[1]), @view.buffer.get_iter_at_offset(action[2]))
    when "apply_tag"
      @view.buffer.remove_tag(action[3], @view.buffer.get_iter_at_offset(action[1]), @view.buffer.get_iter_at_offset(action[2]))
    when "toogle_bulleted_list"
      toogle_bulleted_list
#    when "apply_style_text"
#      start_iter = @view.buffer.get_iter_at_offset(action[1])
#      end_iter = @view.buffer.get_iter_at_offset(action[2])
#      @view.buffer.remove_tag(@view.buffer.tag_table[action[3]], start_iter, end_iter)
#    when "remove_style_text"
#      start_iter = @view.buffer.get_iter_at_offset(action[1])
#      end_iter = @view.buffer.get_iter_at_offset(action[2])
#      @view.buffer.apply_tag(@view.buffer.tag_table[action[3]], start_iter, end_iter)
    end
    @view.iter_on_screen(start_iter, "insert") if !start_iter.nil?
    @model.currentNode.redopool << action unless action[0] == "action_end"
  end

  def redo_text()
    return if @model.currentNode.redopool.size == 0
    action = @model.currentNode.redopool.pop 
    case action[0]
    when "action_end"
      @in_action = false
    when "action_begin"
      @in_action = true
      @model.currentNode.undopool << action
      redo_text while @in_action
    when "insert_text"
      start_iter = @view.buffer.get_iter_at_offset(action[1])
      end_iter = @view.buffer.get_iter_at_offset(action[2])
      @view.buffer.insert(start_iter, action[3])
    when "delete_range"
      start_iter = @view.buffer.get_iter_at_offset(action[1])
      end_iter = @view.buffer.get_iter_at_offset(action[2])
      @view.buffer.delete(start_iter, end_iter)
    when "remove_tag"
      @view.buffer.remove_tag(action[3], @view.buffer.get_iter_at_offset(action[1]), @view.buffer.get_iter_at_offset(action[2]))
    when "apply_tag"
      @view.buffer.apply_tag(action[3], @view.buffer.get_iter_at_offset(action[1]), @view.buffer.get_iter_at_offset(action[2]))
    when "toogle_bulleted_list"
      toogle_bulleted_list
#    when "apply_style_text"
#      start_iter = @view.buffer.get_iter_at_offset(action[1])
#      end_iter = @view.buffer.get_iter_at_offset(action[2])
#      @view.buffer.apply_tag(@view.buffer.tag_table[action[3]], start_iter, end_iter)
#    when "remove_style_text"
#      start_iter = @view.buffer.get_iter_at_offset(action[1])
#      end_iter = @view.buffer.get_iter_at_offset(action[2])
#      @view.buffer.remove_tag(@view.buffer.tag_table[action[3]], start_iter, end_iter)
    end
    @view.iter_on_screen(start_iter, "insert") if !start_iter.nil?
    @model.currentNode.undopool << action unless action[0] == "action_begin"
  end

  def on_undo(widget)
    undo_command
#    undo_text
  end

  def on_redo(widget)
#    redo_text
    redo_command
  end

  def on_toggle_fullscreen()
    if @view.is_fullscreen
      @view.appwindow.unfullscreen
      @view.is_fullscreen = false
    else
      @view.appwindow.fullscreen
      @view.is_fullscreen = true
    end
  end

  def get_theme_color(color)
#    Gdk::Color.new(color['Red'], color['Green'], color['Blue'])
    Gdk::Color.new(*color.split('-').map{|c| c.to_i})
  end

  def load_theme(theme)
#    states = [Gtk::STATE_NORMAL, Gtk::STATE_ACTIVE ,Gtk::STATE_PRELIGHT, Gtk::STATE_SELECTED, Gtk::STATE_INSENSITIVE]
#    states.each do |state|
#      puts state.to_s
#      puts 'fg : '+@view.textview.style.fg(state).to_a.join('-')
#      puts 'bg : '+@view.textview.style.bg(state).to_a.join('-')
#      puts 'text : '+@view.textview.style.text(state).to_a.join('-')
#      puts 'base : '+@view.textview.style.base(state).to_a.join('-')
#      puts 'font_desc : ' + @view.textview.style.font_desc()
#    end

    theme_file = $DIR_THEMES + theme + ".yaml"
    if File.exist? theme_file 
      theme_settings = YAML.load(File.open(theme_file))

#      color_fg = theme_settings['color']
#      color_bg = theme_settings['background']

      #Methode par modification directe du style : NOK
#      @view.textview.style.set_text(Gtk::STATE_NORMAL,color_fg['Red'], color_fg['Green'], color_fg['Blue'])
#      @view.textview.style.set_fg(Gtk::STATE_NORMAL,color_fg['Red'], color_fg['Green'], color_fg['Blue'])
#      @view.textview.style.set_base(Gtk::STATE_NORMAL,color_bg['Red'], color_bg['Green'], color_bg['Blue'])
#      @view.textview.style.set_bg(Gtk::STATE_NORMAL,color_bg['Red'], color_bg['Green'], color_bg['Blue'])

      #Methode par application d'un style modifié : NOK
#      new_style = @view.textview.modifier_style
#      new_style = Gtk::RcStyle.new
#      new_style.set_base(Gtk::STATE_NORMAL,color_bg['Red'], color_fg['Green'], color_fg['Blue'])
#      new_style.set_text(Gtk::STATE_NORMAL,color_fg['Red'], color_bg['Green'], color_bg['Blue'])
#      @view.textview.modify_style(new_style)
#      @view.treeview.modify_style(new_style)

      #Methode par fonctions  : OK
      color_fg = get_theme_color(theme_settings['normal']['color'])
      color_bg = get_theme_color(theme_settings['normal']['background'])
      @view.textview.modify_base(Gtk::STATE_NORMAL,color_bg)
      @view.treeview.modify_base(Gtk::STATE_NORMAL,color_bg)
      @view.textview.modify_text(Gtk::STATE_NORMAL,color_fg)
      @view.treeview.modify_text(Gtk::STATE_NORMAL,color_fg)

      color_fg = get_theme_color(theme_settings['selected']['color'])
      color_bg = get_theme_color(theme_settings['selected']['background'])
      @view.textview.modify_base(Gtk::STATE_SELECTED,color_bg)
      @view.treeview.modify_base(Gtk::STATE_SELECTED,color_bg)
      @view.textview.modify_text(Gtk::STATE_SELECTED,color_fg)
      @view.treeview.modify_text(Gtk::STATE_SELECTED,color_fg)

      color_fg = get_theme_color(theme_settings['active']['color'])
      color_bg = get_theme_color(theme_settings['active']['background'])
      @view.textview.modify_base(Gtk::STATE_ACTIVE,color_bg)
      @view.treeview.modify_base(Gtk::STATE_ACTIVE,color_bg)
      @view.textview.modify_text(Gtk::STATE_ACTIVE,color_fg)
      @view.treeview.modify_text(Gtk::STATE_ACTIVE,color_fg)
    else
      puts "Theme file does not exists"
    end
  end
  
  def on_find()
    @find_dialog.show
  end
  
  def on_replace()
    @replace_dialog.show
  end

  def on_text_bold
    style_text('bold')
  end

  def on_text_italic
    style_text('italic')
  end

  def on_text_centered
    style_text('centered')
  end

  def on_justify_left
    style_text('justify-left')
  end

  def on_justify_right
    style_text('justify-right')
  end

  def on_text_highlight
    style_text('highlight')
  end

  def on_text_strikethrough
    style_text('strikethrough')
  end

  def on_bulleted_list
    toogle_bulleted_list
    @model.currentNode.undopool <<  ["toogle_bulleted_list"]
  end

  def toogle_bulleted_list
    @view.buffer.toggle_selection_bullets()
  end
  
  def on_quit
    if @model.is_saved
      Gtk.main_quit
    else
      titre = (@model.filename.nil?)?_("No title"):@model.filename
      dialog = Gtk::MessageDialog.new(@appwindow, Gtk::Dialog::MODAL, 
                                        Gtk::MessageDialog::QUESTION, 
                                        Gtk::MessageDialog::BUTTONS_NONE, 
                                        _("Save changes to ")+titre+"?")
      dialog.add_buttons([Gtk::Stock::YES, Gtk::Dialog::RESPONSE_YES],
                         [Gtk::Stock::NO, Gtk::Dialog::RESPONSE_NO],
                         [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL])
      response = dialog.run
      dialog.destroy
      case response
      when Gtk::Dialog::RESPONSE_NO
        Gtk.main_quit 
      when Gtk::Dialog::RESPONSE_YES
        on_save_file
        Gtk.main_quit 
      when Gtk::Dialog::RESPONSE_CANCEL
      end
    end
    return true
  end


  def on_notebook_switch_page(widget, page, page_num)
    if not @notebook_actions[page_num].nil?
      @notebook_actions[page_num].call
    end
  end

  def recent_item_activated(widget)
    #Activated when an item from the recent projects menu is clicked
    uri = widget.current_item.uri
    # Strip 'file://' from the beginning of the uri
    file_to_open = uri[7..-1]
    #code here to open the selected file
    if @model.is_saved
      load_file(file_to_open)
    end
  end

  private
 
  def style_text(style)
    @view.buffer.begin_user_action
    (debut, fin, selected) = @view.buffer.selection_bounds
     if selected
       #La selection a-t-elle déjà le style appliqué ?
       style_tag = @view.buffer.tag_table[style]
       already_styled = true
       iter = debut.dup
       while (already_styled and (iter != fin))
         if (!iter.has_tag?(style_tag))
           already_styled = false
         end
         iter.forward_char
       end

       if (already_styled)
         remove_style_text(style, debut, fin)
       else
         apply_style_text(style, debut, fin)
       end
     end
     @view.buffer.end_user_action
  end

  def remove_style_text(style, debut, fin)
    @view.buffer.remove_tag(@view.buffer.tag_table[style], debut, fin)
#    @model.currentNode.undopool <<  ["remove_style_text", debut.offset, fin.offset, style]
  end

  def apply_style_text(style, debut, fin)
    @view.buffer.apply_tag(@view.buffer.tag_table[style], debut, fin)
#    @model.currentNode.undopool <<  ["apply_style_text", debut.offset, fin.offset, style]
  end

  #Find Dialog
  def on_find_quit()
    @find_dialog.hide
  end
 
  def on_find_execute(widget)
    string_to_find = @gladeDialogs.get_object('find_entry').text
    backward = @gladeDialogs.get_object('backwards_checkbutton').active?
    if (backward)
      #On recherche à partir du début de la section courante (= position du curseur s'il n'y a pas de sélection)
      iterDebut =  @view.buffer.get_iter_at_mark(@view.buffer.get_mark('insert'))
      itersFound = iterDebut.backward_search(string_to_find, Gtk::TextIter::SEARCH_TEXT_ONLY) 
    else
      #On recherche à partir de la fin de la section courante (= position du curseur s'il n'y a pas de sélection)
      iterDebut =  @view.buffer.get_iter_at_mark(@view.buffer.get_mark('selection_bound'))
      itersFound = iterDebut.forward_search(string_to_find, Gtk::TextIter::SEARCH_TEXT_ONLY) 
    end
    if (itersFound.nil?)
      show_message(_("End of file"))
    else
      #On sélectionne le texte trouvé
      @view.buffer.select_range(itersFound[0], itersFound[1])
      #On scrolle vers le texte trouvé
      @view.textview.scroll_mark_onscreen(@view.buffer.get_mark('selection_bound'))
    end

  end
  
  #Replace Dialog
  def on_replace_quit()
    @replace_dialog.hide
  end
  
  def on_replace_execute(widget)
    string_to_find = @gladeDialogs.get_object('replace_find_entry').text
    string_replace = @gladeDialogs.get_object('replace_replace_entry').text
    backward = @gladeDialogs.get_object('replace_backwards_checkbutton').active?
    if (backward)
      iterDebut =  @view.buffer.get_iter_at_mark(@view.buffer.get_mark('insert'))
      itersFound = iterDebut.backward_search(string_to_find, Gtk::TextIter::SEARCH_TEXT_ONLY) 
    else
      #On recherche à partir de la fin de la section courante (= position du curseur s'il n'y a pas de sélection)
      iterDebut =  @view.buffer.get_iter_at_mark(@view.buffer.get_mark('selection_bound'))
      itersFound = iterDebut.forward_search(string_to_find, Gtk::TextIter::SEARCH_TEXT_ONLY) 
    end
    if (itersFound.nil?)
      show_message(_("End of file"))
    else
      #On sélectionne le texte trouvé
      @view.buffer.select_range(itersFound[0], itersFound[1])
      #On scrolle vers le texte trouvé
      @view.textview.scroll_mark_onscreen(@view.buffer.get_mark('selection_bound'))
      #On supprime le texte trouvé
      @view.buffer.delete(itersFound[0], itersFound[1])
      #On ajoute le texte de remplacement
      @view.buffer.insert(itersFound[0], string_replace)
      set_not_saved
    end
  end
end
