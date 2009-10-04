
Plugin.define "statistics" do
  title "Statistics"
  description "Text statistics"
  author "Henri Bourcereau"
  site "http://henri.websiteburo.com"
  version "0.01"

  def enable(plugins_proxy)
    #Statistics tab elements
    require $DIR_MODULES + "statistics/novedit_statistics_word_count.rb"
    tab_stats = [NoveditStatisticsWordCount.new]

    glade = Gtk::Builder.new() << File.dirname(__FILE__) + "/statistics.glade"
    widget = glade.get_object("tabstats")
    wordcount_label = glade.get_object("labelNbWordsValue")

    # Function called when the 'statistics' tab is activated
    plugins_statistics_on_show_tabinfos = lambda {
        plugins_proxy.model.currentNode.text = plugins_proxy.view.buffer.get_text
        wordcount_label.label = tab_stats[0].to_s(plugins_proxy.model.currentNode)
    }

    @tab_id = plugins_proxy.addTab(widget, 'Statistics', plugins_statistics_on_show_tabinfos)
  end

  def disable(plugins_proxy)
    plugins_proxy.removeTab(@tab_id)
  end
end
