#This module used by the controller act as a plugins proxy
#It translate interface changes and new functions asked by plugins
#in the controller and view implementations
module NoveditPluginsProxy
  attr_accessor :model, :view

  def add_status(status_func)
    @model.status_funcs << status_func
  end

  def add_loadnode(loadnode_func)
    @model.loadnode_funcs << loadnode_func
  end

  def update_last_metas(metas, node = nil)
    if node.nil? 
      @model.document.update_last_metas(metas)
    else
      node.update_last_metas(metas)
    end
  end

#  def init_metas(metas)
#    @model.init_metas(metas)
#  end
  
  def get_metas(metas, node = nil)
    if node.nil? 
      curr_metas = @model.document.metas
    else
      curr_metas = node.metas
    end
    metas.each do |meta|
      if not curr_metas.include?(meta)
        return false
      else
        curr_metas = curr_metas[meta]
      end
    end
    return curr_metas
  end

  def schedule(function, interval=20)
    GLib::Timeout.add_seconds(interval){ function.call }
  end

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
  #
  #Example, in a plugin :
#  def enable(plugins_proxy)
#    @rootMenu = plugins_proxy.addMenuContainer('My beautiful menu')
#    plugins_proxy.addMenu(_('Load'), nil, @rootMenu)
#    plugins_proxy.addMenu(_('Save'), nil, @rootMenu)
#  end
#
#  def disable(plugins_proxy)
#    plugins_proxy.removeMenuContainer(@rootMenu)
#  end

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


