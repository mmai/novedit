Plugin.define "wordscount" do
  title "Words count"
  description "Text statistics"
  author "Henri Bourcereau"
  site "http://henri.websiteburo.com"
  version "0.01"

  def enable(plugins_proxy)
    @tab = plugins_proxy.addTab('Words count', widget)
  end

  def disable(plugins_proxy)
    plugins_proxy.removeTab(@tab)
  end

end

