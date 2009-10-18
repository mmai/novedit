Plugin.define "amazonS3" do
  title "Amazon S3"
  description "Amazon S3 backup"
  author "Henri Bourcereau"
  site "http://henri.websiteburo.com"
  version "0.01"

  def enable(plugins_proxy)
    @rootMenu = plugins_proxy.addMenuContainer('Amazon S3')
    plugins_proxy.addMenu(_('Load'), nil, @rootMenu)
    plugins_proxy.addMenu(_('Save'), nil, @rootMenu)
  end

  def disable(plugins_proxy)
    plugins_proxy.removeMenuContainer(@rootMenu)
  end

end

