def plugin_init(plugins_proxy)
  rootMenu = plugins_proxy.addMenuContainer('amazonS3')
  plugins_proxy.addMenu(_('Load'), nil, rootMenu)
  savemenu = plugins_proxy.addMenu(_('Save'), nil, rootMenu)
end