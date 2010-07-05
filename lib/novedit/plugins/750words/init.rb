NoveditMode.define "750words" do
  title "750 words"
  description "Incite you to write three pages every day.\nIdea stolen from http://750words.com/.\n\"It's about writing, and getting into your brain\""
  author "Henri Bourcereau"
  site "http://www.rhumbs.fr"
  version "0.1"

  def enable(plugins_proxy)
    @enabled = true
    @rootMenu = plugins_proxy.addMenuContainer('750words')
    @plugins_proxy = plugins_proxy

    plugins_proxy.addMenu(_('Stats'), nil, @rootMenu)
    plugins_proxy.addMenu(_('Begin'), nil, @rootMenu)
    plugins_proxy.schedule(update_count, 30)
  end

  def update_count
    now = DateTime.now
    today = [now.year, now.month, now.day].join('-')
    time = [now.hour, now.min, now.sec].join('-')
    
    count = @plugins_proxy.model.current_node.text.split.size.to_s

    metas = @plugins_proxy.get_metas(['750words', today])
    if metas
      metas = {today => metas + ',' + time + ':' + count}
    else
      metas = {today => time + ':' + count}
    end
    @plugins_proxy.update_last_metas({'750words' => {today => metas}})
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
