#!/usr/bin/env ruby
#
# Novedit
#

#Utilisation de UTF-8
$KCODE = "U"

$TITLE = "Novedit"
$NAME = "Novedit"
$VERSION = "0.0.3"

$DEFAULT_NODE_NAME = "New node"
$: << File.dirname($0)

require  "controlerNovedit"
require  "modelNovedit"

Gtk.init

model = NoveditModel.new(nil)
ControlerNovedit.new(model)
Gtk.main





