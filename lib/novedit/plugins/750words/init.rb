NoveditMode.define "750words" do
  title "750 words"
  description "Incite you to write three pages every day.\nIdea stolen from http://750words.com/.\n\"It's about writing, and getting into your brain\""
  author "Henri Bourcereau"
  site "http://www.rhumbs.fr"
  version "0.2"

  @update_count = lambda do
    now = DateTime.now
    today = [now.year, now.month, now.day].join('-')
    time = [now.hour, now.min, now.sec].join(':')
    
    wordcount = @plugins_proxy.count_view_words.to_s

    metas = @plugins_proxy.get_metas(['750words', today], @model.current_node)
    if metas
      metas = {today => metas + ',' + time + '=' + wordcount}
    else
      metas = {today => time + '=' + wordcount}
    end
    @plugins_proxy.update_last_metas({'750words' => metas}, @model.current_node)
  end

  def init_current_node
    now = DateTime.now
    today = [now.year, now.month, now.day].join('-')
    metas = @plugins_proxy.get_metas(['750words', today], @plugins_proxy.model.current_node)
    if metas
      wordcountini = metas.split(',').first.split('=').first.to_i
    else
      wordcountini = @plugins_proxy.count_view_words
    end
    return wordcountini
  end

  def enable(plugins_proxy)
    @enabled = true
    @plugins_proxy = plugins_proxy

    wordcountini = init_current_node
    plugins_proxy.add_status(lambda do
      wordcount = @plugins_proxy.count_view_words - wordcountini
      color_code = (wordcount < 750) ? '65535-0-0' : '0-65535-0'
      color = Gdk::Color.new(*color_code.split('-').map{|c| c.to_i})
      status = {'text' => wordcount.to_s, 'position' => 'right', 'color' => color}
      return status
    end)
    plugins_proxy.schedule(@update_count, 60)
  end

  def disable(plugins_proxy)
    @enabled = false
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
