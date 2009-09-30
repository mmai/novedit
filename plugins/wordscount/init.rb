Plugin.define "wordscount" do
  title "Words count"
  description "Text statistics"
  author "Henri Bourcereau"
  site "http://henri.websiteburo.com"
  version "0.01"

  def enable(plugins_proxy)
    glade = Gtk::Builder.new() << File.dirname(__FILE__) + "/wordscount.glade"
    #glade.connect_signals{|handler| method(handler)}
    widget = glade.get_object("tabinfos")

    @tab_id = plugins_proxy.addTab(widget, 'Words count')
  end

  def disable(plugins_proxy)
    plugins_proxy.removeTab(@tab_id)
  end

end

