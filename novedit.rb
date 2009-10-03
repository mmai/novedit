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
require "ruby-debug"

require 'gettext'
include GetText
bindtextdomain("novedit", "./locale")

# UTF-8
$KCODE = "U"

$TITLE = "Novedit"
$NAME = "Novedit"
$VERSION = "0.1.0"

$DEFAULT_NODE_NAME = _("New node")

$DIR_PLUGINS =  File.dirname($0) + "/plugins/"
$HELP_FILE =  File.dirname($0) + "/doc/documentation_fr.nov"
$SETTINGS_FILE = File.expand_path('~/.novedit_settings.yaml')

$: << File.dirname($0)

require  "controlerNovedit"
require  "modelNovedit"

Gtk.init

model = NoveditModel.new(nil)
ControlerNovedit.new(model)
Gtk.main





