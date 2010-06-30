NoveditMode.define "750words" do
  title "750 words"
  description "Incite you to write three pages every day.\nIdea stolen from http://750words.com/.\n\"It's about writing, and getting into your brain\""
  author "Henri Bourcereau"
  site "http://www.rhumbs.fr"
  version "0.1"

  def enable(plugins_proxy)
    @enabled = true
    @rootMenu = plugins_proxy.addMenuContainer('750words')
    plugins_proxy.init_metas({'750words' => {'start_time' =>DateTime.now}})
    plugins_proxy.addMenu(_('Stats'), nil, @rootMenu)
    plugins_proxy.addMenu(_('Begin'), nil, @rootMenu)
  end

  def disable(plugins_proxy)
    @enabled = false
    plugins_proxy.removeMenuContainer(@rootMenu)
  end

  def enabled?
    return @enabled
  end

end

Plugin.define "750words" do
  title "750 words"
  description "Incite you to write three pages every day.\nIdea stolen from http://750words.com/.\n\"It's about writing, and getting into your brain\""
  author "Henri Bourcereau"
  site "http://www.rhumbs.fr"
  version "0.1"
  dependencies [
    [:name =>'automatic_save', :version => 0.1]
  ]

  def enable(plugins_proxy)
    plugins_proxy.model.available_modes << "750words"
  end

  def disable(plugins_proxy)
    plugins_proxy.model.available_modes.delete("750words")
  end

end
