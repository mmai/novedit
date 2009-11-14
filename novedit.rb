#!/usr/bin/env ruby
#
# Novedit
#

begin
  require 'rubygems'
rescue LoadError
  $stderr.puts "RubyGems is not found."
end

#XXX To comment in production
#require "ruby-debug"

require 'gettext'
include GetText
bindtextdomain("novedit", File.join(File.dirname($0), "locale"))
bindtextdomain("noveditGlade", File.join(File.dirname($0), "locale"))

# UTF-8
$KCODE = "U"

$TITLE = "Novedit"
$NAME = "Novedit"
$VERSION = "0.1.0"

$DEFAULT_NODE_NAME = _("New node")

$INSTALL_PATH = File.dirname($0) 
$PROGNAME = File.basename($0) # Used by the recent files filter
$DIR_PLUGINS =  $INSTALL_PATH + "/plugins/"
$DIR_MODULES =  $INSTALL_PATH + "/modules/"
$DIR_THEMES =  $INSTALL_PATH + "/themes/"
$HELP_FILE =  $INSTALL_PATH + "/doc/documentation_fr.nov"
$HOME = ENV["HOME"] || ENV["HOMEPATH"] || File::expand_path("~")
$SETTINGS_FILE = File.join($HOME, '.novedit_settings.yaml')

$: << File.dirname($0)

require  "controlerNovedit"
require  "modelNovedit"

Gtk.init

model = NoveditModel.new(nil)
ControlerNovedit.new(model)
Gtk.main





