
#using System
#using System.Collections
#using System.IO
#using System.Xml
#
#namespace Tomboy
#{
#	def delegate bool TagActivatedHandler (NoteTag tag,
#						  NoteEditor editor,
#						  Gtk.TextIter start, 
#						  Gtk.TextIter end)
require 'singleton'

class NoteTag < Gtk::TextTag
  attr_accessor :element_name
  

#  def NoteTag(tag_name)
#    if (tag_name.nil? || tag_name == "") 
#      raise ("NoteTags must have a tag name.  Use " + "DynamicNoteTag for constructing " + "anonymous tags.")
#    end
#    initialize(tag_name)
#  end
#


  def initialize(tag)
    if !(tag.instance_of?(NoteTag) or tag.instance_of?(DepthNoteTag))
         if (tag.instance_of?(Gtk::TextTag))
           @element_name = tag.name
         else
           super(tag)
           @element_name = tag
         end
    end

    @imageLocation = Gtk::TextMark.new
    #@imageLocation = Gtk::TextMark.new "nom", false 
    @tag_flags = {
      'CanSerialize' => 1,
      'CanUndo' => 2,
      'CanGrow' => 4,
      'CanSpellCheck' => 8,
      'CanActivate' => 16,
      'CanSplit' => 32
    }
    @flags = @tag_flags['CanSerialize'] | @tag_flags['CanSplit']
  end

  def can_serialize?
    return (@flags & @tag_flags['CanSerialize']) != 0
  end
  def can_serialize=(value)
    if (value)
      @flags |= @tag_flags['CanSerialize']
    else 
      @flags &= ~@tag_flags['CanSerialize']
    end
  end

  def CanUndo 
    return (@flags & @tag_flags['CanUndo']) != 0
  end
  def CanUndo=(value)
    if (value)
      @flags |= @tag_flags['CanUndo']
    else 
      @flags &= ~@tag_flags['CanUndo']
    end
  end

  def CanGrow
    return (@flags & @tag_flags['CanGrow']) != 0
  end
  def CanGrow=(value)
    if (value)
      @flags |= @tag_flags['CanGrow']
    else 
      @flags &= ~@tag_flags['CanGrow']
    end
  end

  def CanSpellCheck
    return (@flags & @tag_flags['CanSpellCheck']) != 0
  end
  def CanSpellCheck=(value)
    if (value)
      @flags |= @tag_flags['CanSpellCheck']
    else 
      @flags &= ~@tag_flags['CanSpellCheck']
    end
  end

  def CanActivate
    return (@flags & @tag_flags['CanActivate']) != 0
  end
  def CanActivate=(value)
    if (value)
      @flags |= @tag_flags['CanActivate']
    else 
      @flags &= ~@tag_flags['CanActivate']
    end
  end

  def CanSplit
    return (@flags & @tag_flags['CanSplit']) != 0
  end
  def CanSplit=(value)
    if (value)
      @flags |= @tag_flags['CanSplit']
    else
      @flags &= ~@tag_flags['CanSplit']
    end
  end

  #		def void GetExtents (Gtk.TextIter iter, out Gtk.TextIter start, out Gtk.TextIter end) 
  def GetExtents(iter, start, fin) 
    start = iter
    if (!start.BeginsTag(self))
      start.BackwardToTagToggle(self)
    end
    fin = iter
    fin.ForwardToTagToggle(self)
  end

  def Write(xml, start)
    if (can_serialize?()) 
      if (start) 
        xml.WriteStartElement(nil, @element_name, nil)
      else 
        xml.WriteEndElement()
      end
    end
  end

  def Read(xml, start)
    if (can_serialize?) 
      if (start) 
        @element_name = xml.name
      end
    end
  end

  def marshal_dump
    [element_name]
  end

  def marshal_load(ary)
    @element_name = ary[0]
  end

  #		protected override bool OnTextEvent (GLib.Object  sender, Gdk.Event    ev, Gtk.TextIter iter)
  def OnTextEvent(sender, ev, iter)
    #NoteEditer editor
    editor = sender
    startIter = TextIter.new
    endIter = TextIter.new

    if (!CanActivate)
      return false
    end

    case (ev.Type) 
    when Gdk.EventType.ButtonPress:
      button_ev =  Gdk::EventButton.new(ev.Handle)
      if (button_ev.Button != 1 && button_ev.Button != 2)
        return false
      end
      # Don't activate if Shift or Control is pressed 
      if ((button_ev.State & (Gdk.ModifierType.ShiftMask | Gdk.ModifierType.ControlMask)).to_i != 0)
        return false
      end
      GetExtents(iter, startIter, endIter)
      success = OnActivate(editor, startIter, endIter)
      if (success && button_ev.Button == 2) 
        widget = sender
        widget.Toplevel.Hide()
      end	
      return success
    when Gdk.EventType.KeyPress:
      key_ev = Gdk::EventKey.new(ev.Handle)
      # Control-Enter activates the link at point...
      if ((key_ev.State & Gdk.ModifierType.ControlMask).to_i == 0)
        return false
      end
      if (key_ev.Key != Gdk.Key.Return && key_ev.Key != Gdk.Key.KP_Enter)
        return false
      end
      #GetExtents(iter, out startIter, out endIter)
      GetExtents(iter, startIter, endIter)
      return OnActivate(editor, startIter, endIter)
    end

    return false
  end

  #		protected virtual bool OnActivate (NoteEditor editor, 
  def OnActivate(editor, start, fin)
    retval = false

    if (!Activated.nil?) 
      Activated.GetInvocationList().each do |d| 
        #handler = (TagActivatedHandler) d
        handler = d
        retval |= handler(self, editor, start, fin)
      end
    end

    return retval
  end

  def Image
    return image
  end
  def Image=(value)
    image = value
    if (!Changed.nil?) 
      args = Gtk::TagChangedArgs.new
      args.Args[0] = false; # SizeChanged
      args.Args[1] = self;  # Tag
      Changed(self, args)
    end
  end

  def ImageLocation
    return @imageLocation
  end
  def ImageLocation=(value)
    @imageLocation = value
  end

  def Changed
  end
end

class DynamicNoteTag < NoteTag
  @attributes

  def initialize
    super
  end

  def Attributes 
    if (!@attributes.nil?)
      @attributes = Hash.new
    end
    return @attributes 
  end

  def Write(xml, start)
    if (can_serialize?) 
      super(xml, start)
      if (start && !@attributes.nil?) 
        @attributes.Keys.each do |key|
          val = @attributes[key].to_s
          xml.WriteAttributeString(nil, key, nil, val)
        end
      end
    end
  end

  def Read(xml, start)
    if (can_serialize?) 
      super(xml, start)
      if (start) 
        while (xml.MoveToNextAttribute()) 
          name = xml.Name
          xml.ReadAttributeValue()
          Attributes[name] = xml.Value
          Logger.Log( "NoteTag: {0} read attribute {1}='{2}'", ElementName, name, xml.Value)
        end
      end
    end
  end
end

class DepthNoteTag < NoteTag
  @depth = -1
  @direction = Pango::DIRECTION_LTR

  def depth
    return @depth
  end

  def direction
    return @direction
  end

  def initialize(depth=-1, direction=Pango::DIRECTION_LTR)
    super("depth:" + depth.to_s + ":" + direction.to_s)
    @depth = depth
    @direction = direction
  end

  def Write(xml, start)
    if (can_serialize?) 
      if (start) 
        xml.WriteStartElement(nil, "list-item", nil)

        #					 Write the list items writing direction
#        xml.WriteStartAttribute(nil, "dir", nil)
#        if (Direction == Pango.Direction.Rtl)
#          xml.WriteString("rtl")
#        else
#          xml.WriteString("ltr")
#        end
#        xml.WriteEndAttribute()
      else 
        xml.WriteEndElement()
      end
    end
  end
end	

class NoteTagTable < Gtk::TextTagTable
#  include Singleton

  @tag_types
  @added_tags

  def initialize() 
    super()
    @tag_types = Hash.new 
    @added_tags = Array.new
    init_common_tags()
  end

  def init_common_tags
    # Font stylings
    tag = NoteTag.new("bold")
    tag.weight=Pango::FontDescription::WEIGHT_BOLD
    tag.CanUndo = true
    tag.CanGrow = true
    tag.CanSpellCheck = true
    add(tag)

    tag = NoteTag.new("italic")
    tag.style=Pango::FontDescription::STYLE_ITALIC
    tag.CanUndo = true
    tag.CanGrow = true
    tag.CanSpellCheck = true
    add(tag)

    tag = NoteTag.new("centered")
    tag.justification = Gtk::JUSTIFY_CENTER
    tag.CanUndo = true
    tag.CanGrow = true
    tag.CanSpellCheck = true
    add(tag)

    tag = NoteTag.new("justify-left")
    tag.justification = Gtk::JUSTIFY_LEFT
    tag.CanUndo = true
    tag.CanGrow = true
    tag.CanSpellCheck = true
    add(tag)

    tag = NoteTag.new("justify-right")
    tag.justification = Gtk::JUSTIFY_RIGHT
    tag.CanUndo = true
    tag.CanGrow = true
    tag.CanSpellCheck = true
    add(tag)

    tag = NoteTag.new("strikethrough")
    tag.strikethrough = true
    tag.CanUndo = true
    tag.CanGrow = true
    tag.CanSpellCheck = true
    add(tag)

    tag = NoteTag.new("highlight")
    tag.background = "yellow"
    tag.CanUndo = true
    tag.CanGrow = true
    tag.CanSpellCheck = true
    add(tag)

    tag = NoteTag.new("find-match")
    tag.background = "green"
    tag.can_serialize = false
    tag.CanSpellCheck = true
    add(tag)

    # Font sizes

    tag = NoteTag.new("size:huge")
    tag.scale = Pango::SCALE_XX_LARGE
    tag.CanUndo = true
    tag.CanGrow = true
    tag.CanSpellCheck = true
    add(tag)

    tag = NoteTag.new("size:large")
    tag.scale = Pango::SCALE_X_LARGE
    tag.CanUndo = true
    tag.CanGrow = true
    tag.CanSpellCheck = true
    add(tag)

    tag = NoteTag.new("size:normal")
    tag.scale = Pango::SCALE_MEDIUM
    tag.CanUndo = true
    tag.CanGrow = true
    tag.CanSpellCheck = true
    add(tag)

    tag = NoteTag.new("size:small")
    tag.scale = Pango::SCALE_SMALL
    tag.CanUndo = true
    tag.CanGrow = true
    tag.CanSpellCheck = true
    add(tag)

    # Links

    tag = NoteTag.new("link:broken")
    tag.underline = Pango::UNDERLINE_SINGLE
    tag.foreground = "#555753"
    tag.CanActivate = true
    add(tag)

    tag = NoteTag.new("link:internal")
    tag.underline = Pango::UNDERLINE_SINGLE
    tag.foreground = "#204a87"
    tag.CanActivate = true
    add(tag)

    tag = NoteTag.new("link:url")
    tag.underline = Pango::UNDERLINE_SINGLE
    tag.foreground = "#3465a4"
    tag.CanActivate = true
    add(tag)
  end

  def NoteTagTable.TagIsSerializable(tag)
    if tag.instance_of?(NoteTag)
   			return tag.can_serialize?
    end
  	return false
  end

  def TagIsGrowable( tag)
    return tag.CanGrow
  end

  def TagIsUndoable(tag)
    return  tag.CanUndo
  end

  def TagIsSpellCheckable(tag)
    return tag.CanSpellCheck
  end

  def TagIsActivatable(tag)
    return tag.CanActivate
  end

  def NoteTagTable.TagHasDepth(tag)
    return tag.kind_of?(DepthNoteTag)
  end

  def get_depth_tag(depth, direction)
    name = "depth:" + depth.to_s + ":" + direction.to_s
    #tag = Lookup(name) as DepthNoteTag
    tag = self.lookup(name)

    if (tag.nil?) 
      tag = DepthNoteTag.new(depth, direction)
      tag.indent = -14

      if (direction == Pango::DIRECTION_RTL)
        tag.right_margin = (depth+1) * 25
      else
        tag.left_margin = (depth+1) * 25
      end

      tag.pixels_below_lines = 4
      tag.scale = Pango::SCALE_MEDIUM
      tag.size_points = 12
      add(tag)
    end

    return tag
  end

  def CreateDynamicTag(tag_name)
    tag_type = tag_types[tag_name] 
    if (tag_type.nil?) 
      return nil
    end

    tag = Activator.CreateInstance(tag_type)
    tag.Initialize(tag_name)
    add(tag)
    return tag
  end

  def RegisterDynamicTag(tag_name, type)
    if (!type.IsSubclassOf(DynamicNoteTag.class))
      throw Exception.new("Must register only DynamicNoteTag types.")
    end
    @tag_types[tag_name] = type
  end

  def IsDynamicTagRegistered(tag_name)
    return !@tag_types[tag_name].nil?
  end

  def OnTagChanged(sender, args)
    if (!TagChanged.nil?) 
      TagChanged(self, args)
    end
  end

  def TagChanged
  end

  protected 

  def OnTagAdded(tag)
    @added_tags.add(tag)

    note_tag = tag
    if (not note_tag.nil?) 
      note_tag.Changed += OnTagChanged
    end
  end

  def OnTagRemoved(tag)
    added_tags.Remove(tag)
    note_tag = tag
    if (not note_tag.nil?) 
      note_tag.Changed -= OnTagChanged
    end
  end
end
