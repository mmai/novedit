
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
