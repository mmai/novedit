Plugin.define "amazonS3" do
  title "Amazon S3"
  description "Amazon S3 backup"
  author "Henri Bourcereau http://henri.websiteburo.com"
  version 0.01

  def init(plugins_proxy)
    rootMenu = plugins_proxy.addMenuContainer('Amazon S3')
    plugins_proxy.addMenu(_('Load'), nil, rootMenu)
    plugins_proxy.addMenu(_('Save'), nil, rootMenu)
  end

  def remove
  end

end

#class AmazonS3Plugin 
#  attr_reader :name, :description, :author, :version
#  
#  def initialize()
#    @name = "Amazon S3"
#    @description = "Amazon S3 backup"
#    @author = "Henri Bourcereau http://henri.websiteburo.com"
#    @version = 0.01
#  end
#
#  def init(plugins_proxy)
#    rootMenu = plugins_proxy.addMenuContainer('Amazon S3')
#    plugins_proxy.addMenu(_('Load'), nil, rootMenu)
#    plugins_proxy.addMenu(_('Save'), nil, rootMenu)
#  end
#
#  def remove
#  end
#
#end
#
#def load_plugin()
#  AmazonS3Plugin.new
#end
