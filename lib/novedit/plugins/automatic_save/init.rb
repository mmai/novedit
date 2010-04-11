
Plugin.define "automatic save" do
  title "Automatic save"
  description "Auto save document regularly"
  author "Henri Bourcereau"
  site "http://henri.websiteburo.com"
  version "0.01"

  @automatic_save_save = lambda do 
    if not @plugins_proxy.model.is_saved
      if @plugins_proxy.model.filename
        @plugins_proxy.on_save_file
      else
        dialog = Gtk::MessageDialog.new(@appwindow, Gtk::Dialog::MODAL, 
                                        Gtk::MessageDialog::QUESTION, 
                                        Gtk::MessageDialog::BUTTONS_YES_NO, 
                                        _("You must choose a file destination for this document to enable automatic saving. Choose a file ?"))
        response = dialog.run
        dialog.destroy
        @plugins_proxy.on_save_file if response == Gtk::Dialog::RESPONSE_YES
      end
    end
    return @automatic_save_enabled
  end

  def enable(plugins_proxy)
    @automatic_save_enabled = true
    @plugins_proxy = plugins_proxy
    plugins_proxy.schedule(@automatic_save_save, 30)
  end

  def disable(plugins_proxy)
    @automatic_save_enabled = false
  end

end
