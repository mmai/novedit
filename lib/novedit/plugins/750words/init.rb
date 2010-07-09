NoveditMode.define "750words" do
  title "750 words"
  description "Incite you to write three pages every day.\nIdea stolen from http://750words.com/.\n\"It's about writing, and getting into your brain\""
  author "Henri Bourcereau"
  site "http://www.rhumbs.fr"
  version "0.1"

  @update_count = lambda do
    now = DateTime.now
    today = [now.year, now.month, now.day].join('-')
    time = [now.hour, now.min, now.sec].join(':')
    
    wordcount = @plugins_proxy.view.buffer.serialize().split.size.to_s
#    wordcount = @plugins_proxy.model.current_node.text.split.size.to_s

    metas = @plugins_proxy.get_metas(['750words', today])
    if metas
      metas = {today => metas + ',' + time + '=' + wordcount}
    else
      metas = {today => time + '=' + wordcount}
    end
    @plugins_proxy.update_last_metas({'750words' => metas})
  end

  def enable(plugins_proxy)
    @enabled = true
    @rootMenu = plugins_proxy.addMenuContainer('750words')
    @plugins_proxy = plugins_proxy

    plugins_proxy.addMenu(_('Stats'), nil, @rootMenu)
    plugins_proxy.addMenu(_('Begin'), nil, @rootMenu)

    #We call update_count a first time in order to insure the presence of initial metas for the day
    @update_count.call

    #Get the first wordcount for the day
    now = DateTime.now
    today = [now.year, now.month, now.day].join('-')
    metas = @plugins_proxy.get_metas(['750words', today])
    wordcountini = metas.split(',').first.split('=').last.to_i

    plugins_proxy.add_status(lambda do
      wordcount = @plugins_proxy.view.buffer.serialize().split.size
      return (wordcount - wordcountini).to_s
    end)
    plugins_proxy.schedule(@update_count, 60)
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
