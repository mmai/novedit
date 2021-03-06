#
# Novedit
#

require "find" #For plugins detection
require "novedit/lib/pluginsystem.rb"

require "novedit/lib/noveditmodesystem.rb" #Novedit document modes

require "novedit/viewNovedit.rb"
require "novedit/lib/settings.rb"

require "novedit/lib/undo_redo.rb"
require "novedit/lib/novedit_xml.rb"

require "novedit/plugins_proxy_module.rb"

bindtextdomain("controlerNovedit", "./locale")
class ControlerNovedit < UndoRedo
  include NoveditPluginsProxy
  
  @model
  @view
  @settings

  def initialize(model, file=nil)
    super()
    #Model association (MVC)
    @actions_started = 0
    @model = model
    @settings = Settings.new($SETTINGS_FILE)
#    @mysettings['test'] =  'testvalue'
    
    # Load IO modules
    Find.find($DIR_MODULES + "io") { |path| require path if File.basename(path) =~ /.*\.rb$/ }

    #Saving mode
    @model.set_io(NoveditIOYaml.instance)
#    @model.set_io(NoveditIOHtml.new)
    #Visual interface linking (MVC)
    @view = ViewNovedit.new(self, model)

    @settings['theme'] = 'white'  if @settings['theme'].nil? #Default theme
    load_theme(@settings['theme'])  

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
    set_io_from_file(file) unless file.nil? 
    @model.open_file(file)

    #Notebook
    @notebook_actions = Array.new

    #Dialog windows
    pathgladeDialogs = $INSTALL_PATH + "/glade/noveditDialogs.glade"
    @gladeDialogs = Gtk::Builder.new()
    @gladeDialogs << pathgladeDialogs
    #@gladeDialogs.translation_domain = File.join($INSTALL_PATH, "locale")
    @gladeDialogs.translation_domain = "noveditGlade"
    @gladeDialogs.connect_signals{|handler| method(handler)}
    @find_dialog = @gladeDialogs.get_object("find_dialog")
    @replace_dialog = @gladeDialogs.get_object("replace_dialog")
    @about_dialog = @gladeDialogs.get_object("aboutdialog1")
    @about_dialog.program_name = $NAME
    @about_dialog.version = $VERSION
    @about_dialog.website = $HOMEPAGE
    @about_dialog.comments = $DESCRIPTION
#    @about_dialog.license = $LICENSE
    @edit_plugins_dialog = @gladeDialogs.get_object("edit_plugins")
    @edit_modes_dialog = @gladeDialogs.get_object("edit_modes")
    @preferences_dialog = @gladeDialogs.get_object("preferences_dialog")
    
    #Keyboard shortcuts : XXX ctrl-z and ctrl-y are not supported by glade menus (like ctrl-x for example) ?!?
    #We recreate menu shorcuts (for writeroom mode which has no menu...)
    ag = Gtk::AccelGroup.new
    #Undo : Ctrl-Z
    ag.connect(Gdk::Keyval::GDK_Z, Gdk::Window::CONTROL_MASK, Gtk::ACCEL_VISIBLE) {
     on_undo(nil) 
    }
    #Redo : Ctrl-Y 
    ag.connect(Gdk::Keyval::GDK_Y, Gdk::Window::CONTROL_MASK, Gtk::ACCEL_VISIBLE) {
     on_redo(nil) 
    }
    #Save : Ctrl-S 
    ag.connect(Gdk::Keyval::GDK_S, Gdk::Window::CONTROL_MASK, Gtk::ACCEL_VISIBLE) {
     on_save_file
    }
    #Open file : Ctrl-O 
    ag.connect(Gdk::Keyval::GDK_O, Gdk::Window::CONTROL_MASK, Gtk::ACCEL_VISIBLE) {
     open_file
     load_modes
    }
    #New file : Ctrl-N 
    ag.connect(Gdk::Keyval::GDK_N, Gdk::Window::CONTROL_MASK, Gtk::ACCEL_VISIBLE) {
     new_file
    }
    #Find : Ctrl-F 
    ag.connect(Gdk::Keyval::GDK_F, Gdk::Window::CONTROL_MASK, Gtk::ACCEL_VISIBLE) {
     on_find
    }
    #Replace : Ctrl-R 
    ag.connect(Gdk::Keyval::GDK_R, Gdk::Window::CONTROL_MASK, Gtk::ACCEL_VISIBLE) {
     on_replace
    }
    #Toogle Treeview : Ctrl-T
    ag.connect(Gdk::Keyval::GDK_T, Gdk::Window::CONTROL_MASK, Gtk::ACCEL_VISIBLE) {
      on_toggle_tree()
    }
    #FullScreen : F11
#    ag.connect(Gdk::Keyval::GDK_F11, 0, Gtk::ACCEL_VISIBLE) {
#      on_toggle_fullscreen()
#    }
    #WriteRoom : Ctrl-F11
    ag.connect(Gdk::Keyval::GDK_F11, Gdk::Window::CONTROL_MASK, Gtk::ACCEL_VISIBLE) {
      on_toggle_writeroom()
    }
    #WriteRoom exit : ESC
    ag.connect(Gdk::Keyval::GDK_Escape, 0, Gtk::ACCEL_VISIBLE) {
      on_toggle_writeroom() if @view.is_writeroom
    }
    #Next node : Ctrl-Period
    ag.connect(Gdk::Keyval::GDK_period, Gdk::Window::CONTROL_MASK, Gtk::ACCEL_VISIBLE) {
      show_next_node()
    }
    @view.appwindow.add_accel_group(ag)
    #End keyboard shortcuts

    init_plugins
    load_modes
  end

  def load_io_modules()
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
#    @model.set_io(NoveditIOYaml.instance)
    if filename
      set_io_from_file(filename)
      @model.open_file(filename)
      load_modes
      remember_file(filename)
    end
    @view.buffer.place_cursor(@view.buffer.start_iter)
    @view.textview.has_focus = true
    @view.update
    set_saved
  end

  def open_file()
    ensure_saved do
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

    io_module_names = (Dir.entries($DIR_MODULES + "io/").select {|elem| elem !~ /^\.+/}).map {|file| File.basename(file, '.rb').gsub(/^[a-z]|_[a-z]/){ |a| a.upcase }.gsub(/_/,'').gsub(/NoveditIo/, "NoveditIO") }
    dict_io_modules = {} 
    io_module_names.each do |io_module_name|
      io_module =  eval io_module_name + ".instance"
      filedialog.add_filter(io_module.get_filter)
      dict_io_modules[io_module.ext] = io_module.get_filter
    end
#    filedialog.add_filter(NoveditIOHtml.instance.get_filter)
#    filedialog.add_filter(NoveditIOYaml.instance.get_filter)
    filedialog.filter = @model.get_io.get_filter

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
    #Add extension 
    if (not filename.nil?) and (File.extname(filename) == "") and not File.exists?(filename)
      extension = dict_io_modules.select {|k,v| v == filedialog.filter}.first.first
      filename = filename + "." + extension
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
    load_modes
  end
  
  def on_save_file
    @model.current_node.text = @view.buffer.serialize()
    while not @model.filename
      selected_file = select_file()
      return false if selected_file.nil? #Cancelation

      #Do we have write permissions ?
      testfile = File.exists?(selected_file) ? selected_file : File.dirname(selected_file)
      if not File.writable?(testfile)
        dialog = Gtk::MessageDialog.new(@appwindow, Gtk::Dialog::MODAL, 
                                        Gtk::MessageDialog::ERROR, 
                                        Gtk::MessageDialog::BUTTONS_OK, 
                                        _("Permission denied!"))
        response = dialog.run
        dialog.destroy
        return false
      end

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

    set_io_from_file(@model.filename)
    @model.save_file
    set_saved
  end

  def set_io_from_file(filename)
    case File.extname(filename)
    when ".html"
      @model.set_io(NoveditIOHtml.instance)
    when ".nov"
      @model.set_io(NoveditIOYaml.instance)
    else
      @model.set_io(NoveditIOYaml.instance)
    end
  end

  def on_save_as
    @model.filename = false
    on_save_file
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
    if not plugin.settings.nil?
      @gladeDialogs.get_object("configure_button").visible = true
      plugin.settings.each_key do |setting|
        puts setting
      end
    end
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

  def desactivate_mode(mode_name)
    NoveditMode.registered_modes[mode_name].disable(self)
  end

  def activate_mode(mode_name)
    NoveditMode.registered_modes[mode_name].enable(self)
  end

  def load_modes
    NoveditMode.registered_modes.keys.each do |mode_name|
      desactivate_mode(mode_name) if NoveditMode.registered_modes[mode_name].enabled?
    end

    @model.modes.each do |mode_name|
      activate_mode(mode_name)
    end

    @view.update_modes_menu
  end

  #Preferences Dialog
  def preferences_dialog_redraw
    @combo_themes = Gtk::ComboBox.new()
    themes = (Dir.entries($DIR_THEMES).select {|elem| elem !~ /^\.+/}).map {|file| File.basename(file, '.yaml') }
    index = 0
    themes.each do |theme|
      @combo_themes.append_text(theme)
      if theme == @settings['theme']
        @combo_themes.active = index 
        @theme_index = index
      end
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
    @theme_index = @combo_themes.active
#    load_theme(choosen_theme)

    #Save preferences settings 
    @settings['theme'] = choosen_theme
    @settings.save
  end

  def on_preferences_nok()
    @combo_themes.active = @theme_index
    load_theme(@settings['theme'])  
  end

  #Help
  def new_instance(file)
    instance_model = NoveditModel.new(nil)
    ControlerNovedit.new(instance_model, file)
    Gtk.main
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

  #Go to text window
  def on_goto_text
    puts "Go to text"
  end
 
  #Node edition
  def rename_node
    selectedIter = @view.treeview.selection.selected
    if not selectedIter.nil?
      node = @model.get_node(selectedIter.path.to_s)
      @view.treeview.set_cursor(Gtk::TreePath.new(node.path), @view.treeview.get_column(0), true)
      set_not_saved
    end
  end

  #New sub-element insertion
  def on_insert_child()
    selectedIter = @view.treeview.selection.selected
    if not selectedIter.nil?
      newnode = NoveditNode.new($DEFAULT_NODE_NAME)
      parent = @model.get_node(selectedIter.path.to_s)
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
  
  #New brother insertion
  def on_insert_sibling()
    selectedIter = @view.treeview.selection.selected
    if not selectedIter.nil?
#      selectedIter = selectedIter.parent
#      if selectedIter.nil?
#        pathparent = ""
#      else 
#        pathparent = selectedIter.path.to_s
#      end
        
      newnode = NoveditNode.new($DEFAULT_NODE_NAME)
      todo = lambda {
#        @model.insert_node(pathparent, newnode)
        @model.insert_brother_node(selectedIter.path.to_s, newnode)
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
  
  #Node deletion
  def on_delete_node
    selectedIter = @view.treeview.selection.selected
    if not selectedIter.nil?
      node = @model.get_node(selectedIter.path.to_s)
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
  
  #Tree node selection
  def on_select_node(selectionWidget)
    memorize_current_node
    @model.before_nodeload_funcs.each_value {|func| func.call}
    iter = selectionWidget.selected
    select_node(iter) if not iter.nil?
  end

  
  #Tree element edition
  def on_cell_edited(path, newtext)
    node = @model.get_node(path)
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

#  def on_cell_editing_canceled(cell)
#    puts "canceled : " + cell.text
#  end
  
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

      node = @model.get_node(pathOrig)
      node_pos = pathOrig.split(":").last.to_i
      node_parent = node.parent
      node_newparent = @model.get_node(pathDest)
      node_rightbrother = node.rightbrother

      node_newpos = nil
      if position == Gtk::TreeView::DROP_BEFORE
        node_newpos = node_newparent.pos
        node_newparent = node_newparent.parent
      elsif position == Gtk::TreeView::DROP_AFTER
        node_newpos = node_newparent.pos + 1
        node_newparent = node_newparent.parent
      end

      #Model update
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
    @model.get_node(path.to_s).is_open = true
  end
  
  def on_collapse_node(path)
    @model.get_node(path.to_s).is_open = false
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
#        node = @model.get_node(selectedIter.path.to_s)
#        @view.treeview.set_cursor(Gtk::TreePath.new(node.path), @view.treeview.get_column(0), true)
#        @view.treeview.signal_emit("paste_clipboard") 
      end
    end
  end

  def on_key_pressed(keyval)
    insert_mark = @view.buffer.get_mark('insert')
    iter = @view.buffer.get_iter_at_mark(insert_mark)
#    puts "keypressed : "+keyval.to_s
    @view.user_action = true
    case keyval
    when 65293 #Enter
      #Caught for bulleted lists operations
      @model.current_node.undopool <<  ["action_begin"]
      key_inserted = @view.buffer.add_newline(iter)
      if key_inserted
        @model.current_node.undopool <<  ["action_end"]
      else
        @model.current_node.undopool.pop 
      end
    when 65289 #Tab
      #Caught for bulleted lists operations
      @model.current_node.undopool <<  ["action_begin"]
      key_inserted = @view.buffer.add_tab
      if key_inserted
        @model.current_node.undopool <<  ["action_end"]
      else
        @model.current_node.undopool.pop 
      end
    when 65288 #Backspace
      #Caught for bulleted lists operations
      @model.current_node.undopool <<  ["action_begin"]
      key_inserted = @view.buffer.remove_tab
      if key_inserted
        @model.current_node.undopool <<  ["action_end"]
      else
        @model.current_node.undopool.pop 
      end
    when 65361 #Left arrow
      #Caught for tag bounds operations
#      puts "<-"
    when 65363 #Right arrow
      #Caught for tag bounds operations
#      puts "->"
    end
    @view.user_action = false
    return key_inserted
  end          

  def on_insert_text(iter, text)
    separators_list = [" ", "\n", "\t"]
#    puts text
    
    #Put all the characters of a word in the same undo/redo
    if (not @model.current_node.undopool.empty?) and (not separators_list.include?(text)) and (@model.current_node.undopool.last[0] == "insert_text") and (@model.current_node.undopool.last[2] == iter.offset)
      last_text = @model.current_node.undopool.pop
#      @model.current_node.undopool <<  ["insert_text", last_text[1], last_text[1] + last_text[2] + text.scan(/./).size, last_text[3] + text]
      @model.current_node.undopool <<  ["insert_text", last_text[1], last_text[2] + Unicode.string_length(text), last_text[3] + text]
    else
      @model.current_node.undopool <<  ["insert_text", iter.offset, iter.offset + Unicode.string_length(text), text]
    end

    #On appelle les traitements spécifiques novedit_textbuffer
#    @view.buffer.on_insert_text(iter, text)

    store_text_redo()
   
    @model.current_node.redopool.clear
    set_not_saved
  end

  def on_delete_range(start_iter, end_iter)
    separators_list = [" ", "\n", "\t"]
    text = @view.buffer.get_text(start_iter, end_iter)

    #Delete all characters of a word at the same time
    stick_to_word = false
    if  (end_iter.offset - start_iter.offset == 1) and (not separators_list.include?(text)) and (not @model.current_node.undopool.empty?) 
      if (@model.current_node.undopool.last[0] == "action_end")
        #Find non tag action
        pool_index = -2
        action = ["apply_tag"]
        while (action[0] == "apply_tag") and (action[0] != "action_begin")
          action = @model.current_node.undopool[pool_index]
          pool_index -= 1
        end
        #Add this action to precedent action text if precedent action text is a delete_range
        stick_to_word = (action[0] == "delete_range") and ((action[1] == end_iter.offset) or (action[1] == start_iter.offset))
      end
    end

    if stick_to_word
      @model.current_node.undopool.pop
      @actions_started = 1
    else
      start_text_action()
    end

    #We remove all tags in order to call the on_remove_tag function which store the tags in the undopool array
    # Remove all tags, one by one
    current_iter = start_iter.dup
    while current_iter.offset <= end_iter.offset
      current_iter.tags.each do |curtag|
        tagend_iter = @view.buffer.get_iter_at_tag_end(current_iter, curtag)
        endoffset = [tagend_iter.offset, end_iter.offset].min
        @view.buffer.remove_tag(curtag, current_iter, @view.buffer.get_iter_at_offset(endoffset))
      end
      break if not current_iter.forward_char
    end

    @model.current_node.undopool <<  ["delete_range", start_iter.offset, end_iter.offset, text]
    end_text_action()
    set_not_saved
  end

  def on_apply_tag(tag, start_iter, end_iter)
#    end_iter.forward_char
    @model.current_node.undopool <<  ["apply_tag", start_iter.offset, end_iter.offset, tag]
    store_text_redo()
  end

  def on_remove_tag(tag, start_iter, end_iter)
#    end_iter.forward_char
    @model.current_node.undopool <<  ["remove_tag", start_iter.offset, end_iter.offset, tag]
    store_text_redo()
  end

  def on_drag_begin(drag_context)
    start_text_action
  end

  def on_drag_end(drag_context)
    end_text_action
  end

  def start_text_action
    @actions_started = @actions_started + 1
    @model.current_node.undopool <<  ["action_begin"] if @actions_started == 1
  end

  def end_text_action
    @actions_started = @actions_started - 1
    if @actions_started == 0
      @model.current_node.undopool <<  ["action_end"]
      store_text_redo()
    end
  end

  
  def store_text_redo()
   textnode = @model.current_node
    todo = lambda {
      @model.current_node = textnode
      redo_text
    }
    toundo = lambda {
      @model.current_node = textnode
      undo_text
    }
    #todo.call
    @tabUndo << Command.new(todo, toundo)
  end

  def undo_text()
    return if @model.current_node.undopool.size == 0
    action = @model.current_node.undopool.pop 
    #puts @model.current_node.undopool.inspect unless @in_action
    case action[0]
    when "action_end"
      @in_action = true
      @model.current_node.redopool << action
      undo_text while @in_action
    when "action_begin"
      @in_action = false
    when "insert_text"
      start_iter = @view.buffer.get_iter_at_offset(action[1])
      end_iter = @view.buffer.get_iter_at_offset(action[2])
      @view.buffer.delete(start_iter, end_iter)
    when "delete_range"
#      puts @model.current_node.undopool.inspect
      start_iter = @view.buffer.get_iter_at_offset(action[1])
      @view.buffer.insert(start_iter, action[3])
    when "remove_tag"
      end_iter = @view.buffer.get_iter_at_offset(action[2])
#      end_iter.forward_char
      @view.buffer.apply_tag(action[3], @view.buffer.get_iter_at_offset(action[1]), end_iter)
    when "apply_tag"
      end_iter = @view.buffer.get_iter_at_offset(action[2])
#      end_iter.forward_char
      @view.buffer.remove_tag(action[3], @view.buffer.get_iter_at_offset(action[1]), end_iter)
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
    @model.current_node.redopool << action unless action[0] == "action_end"
  end

  def redo_text()
    return if @model.current_node.redopool.size == 0
    action = @model.current_node.redopool.pop 
    case action[0]
    when "action_end"
      @in_action = false
    when "action_begin"
      @in_action = true
      @model.current_node.undopool << action
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
      end_iter = @view.buffer.get_iter_at_offset(action[2])
#      end_iter.forward_char
      @view.buffer.remove_tag(action[3], @view.buffer.get_iter_at_offset(action[1]), end_iter)
    when "apply_tag"
      end_iter = @view.buffer.get_iter_at_offset(action[2])
#      end_iter.forward_char
      @view.buffer.apply_tag(action[3], @view.buffer.get_iter_at_offset(action[1]), end_iter)
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
    @model.current_node.undopool << action unless action[0] == "action_begin"
  end

  def on_undo(widget)
    undo_command
#    undo_text
  end

  def on_redo(widget)
    #    redo_text
    redo_command
  end

  #Printing
  def on_print()
    print_op = Gtk::PrintOperation.new
    print_op.n_pages = 1
    print_op.signal_connect("draw-page") { |operation, context, page_nbr| print_text(operation, context, page_nbr)}
    res = print_op.run(Gtk::PrintOperation::ACTION_PRINT_DIALOG, nil)
    puts "end printing"
  end

  def print_text(operation, context, page_nbr)

    txt = @model.current_node.text
#    textview = @view.glade.get_object("textview")
    pangolayout = context.create_pango_layout()
    pangolayout.set_text(@view.buffer.text)
    cairo_context = context.cairo_context
    cairo_context.show_pango_layout(pangolayout)
  end
  #End printing
  
  def on_toggle_fullscreen()
    if @view.is_fullscreen
      @view.appwindow.unfullscreen
    else
      @view.appwindow.fullscreen
    end
    @view.is_fullscreen = ! @view.is_fullscreen
  end

  def on_toggle_menus
    menubar = @view.glade.get_object("menubar")
    toolbar = @view.glade.get_object("toolbar")
    toolbartext = @view.glade.get_object("toolbartext")
    menubar.visible = ! menubar.visible? 
    toolbar.visible = ! toolbar.visible?
    toolbartext.visible = !toolbartext.visible?
  end

  def on_toggle_tree
    treeview = @view.glade.get_object("treeview")
    treeview.visible = ! treeview.visible?
  end
  
  def on_toggle_statusbar
    statusbar = @view.glade.get_object("statusbar")
    statusbar.visible = !statusbar.visible?
  end

  def on_toggle_writeroom()
    menubar = @view.glade.get_object("menubar")
    toolbar = @view.glade.get_object("toolbar")
    treeview = @view.glade.get_object("treeview")
    toolbartext = @view.glade.get_object("toolbartext")
    statusbar = @view.glade.get_object("statusbar")
    textview = @view.glade.get_object("textview")
    textwindow =  @view.glade.get_object("scrolledwindow")

    textview.grab_focus
    @view.is_writeroom = ! @view.is_writeroom

    @view.appwindow.decorated = ! @view.is_writeroom
    menubar.visible = ! @view.is_writeroom
#    if @view.is_writeroom
#      nodimension = Gtk::Allocation.new(0,0,0,0)
#      menubar.size_allocate(nodimension)
#    else
#    end
    toolbar.visible = ! @view.is_writeroom
    treeview.visible = ! @view.is_writeroom
    toolbartext.visible = ! @view.is_writeroom
#    statusbar.visible = ! @view.is_writeroom
    @view.tabs.show_tabs = (@view.tabs.n_pages > 1 and ! @view.is_writeroom)

    font_desc = textview.pango_context.font_description
    if @view.is_writeroom
      @view.appwindow.fullscreen
      @view.appwindow.border_width = 0
#      textview.left_margin = textview.right_margin = 30
      @orig_textview_border_width = textview.border_width
      textview.border_width =  30

      # Sizing
#      screen = Gdk::Screen.default
#      window, mouse_x, mouse_y, mouse_mods = screen.root_window.pointer
#      monitor_geometry = screen.monitor_geometry(screen.get_monitor(mouse_x, mouse_y))
#      fixed_container.move(textwindow, 0.1 * monitor_geometry.width, 0.1 * monitor_geometry.height)
#      textwindow.set_size_request( 0.8 * monitor_geometry.width, 0.8 * monitor_geometry.height)

#      Doesn't work :
#      color_bg = textview.style.base(Gtk::STATE_NORMAL)
#      statusbar.modify_bg(Gtk::STATE_NORMAL,color_bg)
#      statusbar.modify_fg(Gtk::STATE_NORMAL,color_bg)
#      statusbar.modify_base(Gtk::STATE_NORMAL,color_bg)
#      statusbar.modify_text(Gtk::STATE_NORMAL,color_bg)


      font_desc.size = font_desc.size + 2*Pango::SCALE
      textview.modify_font(font_desc)
      #textview.modify_font(Pango::FontDescription.new("Monospace 12"))
    else
      @view.appwindow.unfullscreen
      @view.appwindow.border_width = 0
      textview.border_width = @orig_textview_border_width
      font_desc.size = font_desc.size - 2*Pango::SCALE
      textview.modify_font(font_desc)
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

    theme_file = File.join($DIR_THEMES, theme + ".yaml")
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

      @view.textview.modify_bg(Gtk::STATE_NORMAL,color_bg)

      #test couleurs sur widgets
#      testwidget = @view.glade.get_object("textview3")
#      testwidget.modify_bg(Gtk::STATE_NORMAL,color_bg)
#      testwidget.modify_base(Gtk::STATE_NORMAL,color_bg)

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

  def on_textview_focus_out
    memorize_current_node
  end

  def count_view_words
    rawtext = @view.buffer.text
    #Remove bullets
    rawtext.delete_utf8!([Unicode::U2022, Unicode::U2218, Unicode::U2023])
    return rawtext.split.size
  end

  def memorize_current_node
    @model.current_node.text = @view.buffer.serialize() unless @model.current_node.nil?
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

  def on_text_size(size)
    style_text('size:' + size)
  end

  def on_bulleted_list
    toogle_bulleted_list
    @model.current_node.undopool <<  ["toogle_bulleted_list"]
  end

  def show_next_node
    next_path = "0"
    selection_manager = @view.treeview.selection
    iter = selection_manager.selected
    if not iter.nil?
      selection_manager.unselect_path(iter.path)
      next_node = @model.current_node.next
      next_path = next_node.path if next_node
    end
    selection_manager.select_path(Gtk::TreePath.new(next_path))
  end

  def toogle_bulleted_list
    @view.buffer.toggle_selection_bullets()
  end

  def ensure_saved
    if @model.is_saved
      yield
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
        yield
      when Gtk::Dialog::RESPONSE_YES
        on_save_file
        yield
      when Gtk::Dialog::RESPONSE_CANCEL
      end
    end
    return true
  end

  def quit_instance
#    puts "quitting level " + Gtk.main_level.to_s
    # XXX How to do that in a clean way ?
    @view.appwindow.destroy
    @view = nil
    @model = nil
    Gtk.main_quit
  end
 
  def on_quit
    ensure_saved { quit_instance }
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
    ensure_saved { load_file(file_to_open) }
  end

  private
 
  def select_node(iter)
    @model.current_node = @model.get_node(iter.path.to_s)
    $DESERIALIZING = true
    @view.buffer.deserialize(@model.current_node.text)
    $DESERIALIZING = false
    @view.update_appbar
  end

  def style_text(style)
    @view.buffer.begin_user_action
    (debut, fin, selected) = @view.buffer.selection_bounds
     if selected
       #Is the style already applied on the selection ?
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
#    @model.current_node.undopool <<  ["remove_style_text", debut.offset, fin.offset, style]
  end

  def apply_style_text(style, debut, fin)
    @view.buffer.apply_tag(@view.buffer.tag_table[style], debut, fin)
#    @model.current_node.undopool <<  ["apply_style_text", debut.offset, fin.offset, style]
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
      #Select found text
      @view.buffer.select_range(itersFound[0], itersFound[1])
      #Scroll toward found text
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
    
      start_text_action()
      #On supprime le texte trouvé
      on_delete_range(itersFound[0], itersFound[1])
      @view.buffer.delete(itersFound[0], itersFound[1])
      #On ajoute le texte de remplacement
      on_insert_text(itersFound[0], string_replace)
      @view.buffer.insert(itersFound[0], string_replace)
      end_text_action()

      set_not_saved
    end
  end
end
