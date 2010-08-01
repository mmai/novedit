require 'ftools'

Plugin.define "backups" do
  backups_settings = {'location'=>'text'}

  title "Backups"
  description "Backup/restore your document anywhere you want"
  author "Henri Bourcereau"
  site "http://www.rhumbs.fr"
  version "0.1"
  settings backups_settings

  class BackupFileCopy
    def initialize(plugins_proxy, location)
      @plugins_proxy = plugins_proxy
      @location = location
    end

    def push
      filename = @plugins_proxy.model.filename
      File.copy(filename, File.join(@location, File.basename(filename)))
    end

    def pull
      filename = @plugins_proxy.model.filename
      File.copy(File.join(@location, File.basename(filename)), filename)
      @plugins_proxy.model.open_file(filename, true)
    end
  end

  @backup_push = lambda do 
    ensure_saved
#    backup = BackupFileCopy.new(settings['location'])
    home = ENV["HOME"] || ENV["HOMEPATH"] || File::expand_path("~")
    backup = BackupFileCopy.new(@plugins_proxy, File.join(home, 'Dropbox'))
    backup.push
  end

  @backup_pull = lambda do 
#    backup = BackupFileCopy.new(settings['location'])
    home = ENV["HOME"] || ENV["HOMEPATH"] || File::expand_path("~")
    backup = BackupFileCopy.new(@plugins_proxy, File.join(home, 'Dropbox'))
    backup.pull
  end


  def enable(plugins_proxy)
    @plugins_proxy = plugins_proxy
    @rootMenu = plugins_proxy.addMenuContainer(_('Backup'))
    plugins_proxy.addMenu(_('Pull'), @backup_pull, @rootMenu)
    plugins_proxy.addMenu(_('Push'), @backup_push, @rootMenu)
  end

  def disable(plugins_proxy)
    plugins_proxy.removeMenuContainer(@rootMenu)
  end

  def ensure_saved
    if not @plugins_proxy.model.is_saved
      if @plugins_proxy.model.filename
        @plugins_proxy.on_save_file
      else
        dialog = Gtk::MessageDialog.new(@appwindow, Gtk::Dialog::MODAL, 
                                        Gtk::MessageDialog::QUESTION, 
                                        Gtk::MessageDialog::BUTTONS_YES_NO, 
                                        _("You must first choose a local file destination for this document to enable backups. Choose a file ?"))
        response = dialog.run
        dialog.destroy
        @plugins_proxy.on_save_file if response == Gtk::Dialog::RESPONSE_YES
      end
    end
  end

end
