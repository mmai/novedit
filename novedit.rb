#!/usr/bin/env ruby
#
# Novedit
#

#Utilisation de UTF-8
$KCODE = "U"

$TITLE = "Novedit"
$NAME = "Novedit"
$VERSION = "0.0.2"

$DEFAULT_NODE_NAME = "New node"

require "controlerNovedit"
require "modelNovedit"

Gtk.init
model = NoveditModel.new(nil)
ControlerNovedit.new(model)
Gtk.main





