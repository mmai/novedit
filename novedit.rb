#!/usr/bin/env ruby
#
# Novedit
#

#Utilisation de UTF-8
$KCODE = "U"

$TITLE = "Novedit"
$NAME = "Novedit"
$VERSION = "0.0.2"

require "controlerNovedit"
require "modelNovedit"

Gtk.init
model = NoveditModel.new
ControlerNovedit.new(model)
Gtk.main





