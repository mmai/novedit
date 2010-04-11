
Plugin.define "automatic_save" do
  title "Automatic save"
  description "Save document every 10 seconds"
  author "Henri Bourcereau"
  site "http://henri.websiteburo.com"
  version "0.01"

 @automatic_save_save = lambda do 
    if not @plugins_proxy.model.is_saved
      @plugins_proxy.on_save_file
    end
    return @automatic_save_enabled
  end

  def enable(plugins_proxy)
    @automatic_save_enabled = true
    @plugins_proxy = plugins_proxy
    plugins_proxy.schedule(@automatic_save_save)
  end

  def disable(plugins_proxy)
    @automatic_save_enabled = false
  end

end
