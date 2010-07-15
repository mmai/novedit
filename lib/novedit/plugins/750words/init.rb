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
    
    wordcount = count_words

    metas = @plugins_proxy.get_metas(['750words', today])
    if metas
      metas = {today => metas + ',' + time + '=' + wordcount}
    else
      metas = {today => time + '=' + wordcount}
    end
    @plugins_proxy.update_last_metas({'750words' => metas})
  end

  def count_words
    rawtext = @plugins_proxy.view.buffer.text
    #Remove bullets
    rawtext.delete_utf8!([Unicode::U2022, Unicode::U2218, Unicode::U2023])
    return rawtext.split.size
  end

  def enable(plugins_proxy)
    @enabled = true
    @plugins_proxy = plugins_proxy

    wordcountini = count_words
    plugins_proxy.add_status(lambda do
      wordcount = count_words
      return (wordcount - wordcountini).to_s
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
