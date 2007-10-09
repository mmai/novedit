
#using System;
#using System.Collections;
#using System.IO;
#using System.Xml;
#
#namespace Tomboy
#{
#	def delegate bool TagActivatedHandler (NoteTag tag,
#						  NoteEditor editor,
#						  Gtk.TextIter start, 
#						  Gtk.TextIter end);

	class NoteTag 
    attr_accessor :element_name
		imageLocation = Gtk::TextMark.new

		@tag_flags = {
			'CanSerialize' => 1,
			'CanUndo' => 2,
			'CanGrow' => 4,
			'CanSpellCheck' => 8,
			'CanActivate' => 16,
			'CanSplit' => 32
		}
		
		
		def NoteTag (tag_name)
			if (tag_name == null || tag_name == "") 
				raise ("NoteTags must have a tag name.  Use " + "DynamicNoteTag for constructing " + "anonymous tags.")
      end
			initialize(tag_name)
    end

		def initialize (element_name)
			@element_name = element_name
			@flags = @tag_flags.CanSerialize | @tag_flags.CanSplit;
    end

		def bool CanSerialize 
		{
			get { return (flags & @tag_flags.CanSerialize) != 0; }
			set {
				if (value)
					flags |= @tag_flags.CanSerialize;
				else 
					flags &= ~@tag_flags.CanSerialize;
			}
		}

		def bool CanUndo 
		{
			get { return (flags & @tag_flags.CanUndo) != 0; }
			set {
				if (value)
					flags |= @tag_flags.CanUndo;
				else 
					flags &= ~@tag_flags.CanUndo;
			}
		}

		def bool CanGrow
		{
			get { return (flags & @tag_flags.CanGrow) != 0; }
			set {
				if (value)
					flags |= @tag_flags.CanGrow;
				else 
					flags &= ~@tag_flags.CanGrow;
			}
		}

		def bool CanSpellCheck
		{
			get { return (flags & @tag_flags.CanSpellCheck) != 0; }
			set {
				if (value)
					flags |= @tag_flags.CanSpellCheck;
				else 
					flags &= ~@tag_flags.CanSpellCheck;
			}
		}

		def bool CanActivate
		{
			get { return (flags & @tag_flags.CanActivate) != 0; }
			set {
				if (value)
					flags |= @tag_flags.CanActivate;
				else 
					flags &= ~@tag_flags.CanActivate;
			}
		}

		def bool CanSplit
		{
			get { return (flags & @tag_flags.CanSplit) != 0; }
			set {
				if (value)
					flags |= @tag_flags.CanSplit;
				else
					flags &= ~@tag_flags.CanSplit;
			}
		}

		def void GetExtents (Gtk.TextIter iter, 
					out Gtk.TextIter start, 
					out Gtk.TextIter end)
		{
			start = iter;
			if (!start.BeginsTag (this))
				start.BackwardToTagToggle (this);

			end = iter;
			end.ForwardToTagToggle (this);
		}
		
		def virtual void Write (XmlTextWriter xml, bool start)
		{
			if (CanSerialize) {
				if (start) {
					xml.WriteStartElement (null, element_name, null);
				} else {
					xml.WriteEndElement();
				}
			}
		}

		def virtual void Read (XmlTextReader xml, bool start)
		{
			if (CanSerialize) {
				if (start) {
					element_name = xml.Name;
				}
			}
		}

		protected override bool OnTextEvent (GLib.Object  sender, 
						     Gdk.Event    ev, 
						     Gtk.TextIter iter)
		{
			NoteEditor editor = (NoteEditor) sender;
			Gtk.TextIter start, end;

			if (!CanActivate)
				return false;

			switch (ev.Type) {
			case Gdk.EventType.ButtonPress:
				Gdk.EventButton button_ev = new Gdk.EventButton (ev.Handle);

				if (button_ev.Button != 1 && button_ev.Button != 2)
					return false;

				/* Don't activate if Shift or Control is pressed */
				if ((int) (button_ev.State & (Gdk.ModifierType.ShiftMask |
							      Gdk.ModifierType.ControlMask)) != 0)
					return false;

				GetExtents (iter, out start, out end);
				bool success = OnActivate (editor, start, end);

				if (success && button_ev.Button == 2) {
					Gtk.Widget widget = (Gtk.Widget) sender;
					widget.Toplevel.Hide ();
				}

				return success;

			case Gdk.EventType.KeyPress:
				Gdk.EventKey key_ev = new Gdk.EventKey (ev.Handle);

				// Control-Enter activates the link at point...
				if ((int) (key_ev.State & Gdk.ModifierType.ControlMask) == 0)
					return false;

				if (key_ev.Key != Gdk.Key.Return &&
				    key_ev.Key != Gdk.Key.KP_Enter)
					return false;

				GetExtents (iter, out start, out end);
				return OnActivate (editor, start, end);
			}

			return false;
		}

		protected virtual bool OnActivate (NoteEditor editor, 
						   Gtk.TextIter start, 
						   Gtk.TextIter end)
		{
			bool retval = false;

			if (Activated != null) {
				foreach (Delegate d in Activated.GetInvocationList()) {
					TagActivatedHandler handler = (TagActivatedHandler) d;
					retval |= handler (this, editor, start, end);
				}
			}

			return retval;
		}

		def event TagActivatedHandler Activated;

		def virtual Gdk.Pixbuf Image
		{
			get { return image; }
			set {
				image = value;

				if (Changed != null) {
					Gtk.TagChangedArgs args = new Gtk.TagChangedArgs ();
					args.Args [0] = false; // SizeChanged
					args.Args [1] = this;  // Tag
					Changed (this, args);
				}
			}
		}

		def virtual Gtk.TextMark ImageLocation
		{
			get { return imageLocation; }
			set { imageLocation = value; }
		}

		def event Gtk.TagChangedHandler Changed;
	}

	def class DynamicNoteTag : NoteTag
	{
		Hashtable attributes;

		def DynamicNoteTag ()
			: base()
		{
		}

		def Hashtable Attributes 
		{
			get { 
				if (attributes == null)
					attributes = new Hashtable ();
				return attributes; 
			}
		}

		def override void Write (XmlTextWriter xml, bool start)
		{
			if (CanSerialize) {
				base.Write (xml, start);

				if (start && attributes != null) {
					foreach (string key in attributes.Keys) {
						string val = (string) attributes [key];
						xml.WriteAttributeString (null, key, null, val);
					}
				}
			}
		}

		def override void Read (XmlTextReader xml, bool start)
		{
			if (CanSerialize) {
				base.Read (xml, start);

				if (start) {
					while (xml.MoveToNextAttribute()) {
						string name = xml.Name;

						xml.ReadAttributeValue();
						Attributes [name] = xml.Value;

						Logger.Log (
							"NoteTag: {0} read attribute {1}='{2}'",
							ElementName,
							name,
							xml.Value);
					}
				}
			}
		}
	}
	
	def class DepthNoteTag : NoteTag
	{
		int depth = -1;
		Pango.Direction direction = Pango.Direction.Ltr;
		
		def int Depth
		{
			get{ return depth; }
		}
		
		def Pango.Direction Direction
		{
			get{ return direction; }
		}

		def DepthNoteTag (int depth, Pango.Direction direction)
			: base("depth:" + depth + ":" + direction)
		{
			this.depth = depth;
			this.direction = direction;
		}

		def override void Write (XmlTextWriter xml, bool start)
		{
			if (CanSerialize) {
				if (start) {
					xml.WriteStartElement (null, "list-item", null);
					
					// Write the list items writing direction
					xml.WriteStartAttribute (null, "dir", null);
					if (Direction == Pango.Direction.Rtl)
						xml.WriteString ("rtl");
					else
						xml.WriteString ("ltr");
					xml.WriteEndAttribute ();
				} else {
					xml.WriteEndElement ();
				}
			}
		}
	}	

	def class NoteTagTable : Gtk.TextTagTable
	{
		static NoteTagTable instance;
		Hashtable tag_types;
		ArrayList added_tags;

		def static NoteTagTable Instance 
		{
			get {
				if (instance == null) 
					instance = new NoteTagTable ();
				return instance;
			}
		}

		def NoteTagTable () 
			: base ()
		{
			tag_types = new Hashtable ();
			added_tags = new ArrayList ();

			InitCommonTags ();
		}
		
		void InitCommonTags () 
		{
			NoteTag tag;

			// Font stylings

			tag = new NoteTag ("centered");
			tag.Justification = Gtk.Justification.Center;
			tag.CanUndo = true;
			tag.CanGrow = true;
			tag.CanSpellCheck = true;
			Add (tag);

			tag = new NoteTag ("bold");
			tag.Weight = Pango.Weight.Bold;
			tag.CanUndo = true;
			tag.CanGrow = true;
			tag.CanSpellCheck = true;
			Add (tag);

			tag = new NoteTag ("italic");
			tag.Style = Pango.Style.Italic;
			tag.CanUndo = true;
			tag.CanGrow = true;
			tag.CanSpellCheck = true;
			Add (tag);

			tag = new NoteTag ("strikethrough");
			tag.Strikethrough = true;
			tag.CanUndo = true;
			tag.CanGrow = true;
			tag.CanSpellCheck = true;
			Add (tag);

			tag = new NoteTag ("highlight");
 			tag.Background = "yellow";
			tag.CanUndo = true;
			tag.CanGrow = true;
			tag.CanSpellCheck = true;
			Add (tag);

			tag = new NoteTag ("find-match");
			tag.Background = "green";
			tag.CanSerialize = false;
			tag.CanSpellCheck = true;
			Add (tag);

			tag = new NoteTag ("note-title");
			tag.Underline = Pango.Underline.Single;
			tag.Foreground = "#204a87";
			tag.Scale = Pango.Scale.XXLarge;
			// FiXME: Hack around extra rewrite on open
			tag.CanSerialize = false;
			Add (tag);

			tag = new NoteTag ("related-to");
			tag.Scale = Pango.Scale.Small;
			tag.LeftMargin = 40;
			tag.Editable = false;
			Add (tag);

			// Used when inserting dropped URLs/text to Start Here
			tag = new NoteTag ("datetime");
			tag.Scale = Pango.Scale.Small;
			tag.Style = Pango.Style.Italic;
			tag.Foreground = "#888a85";
			Add (tag);

			// Font sizes

			tag = new NoteTag ("size:huge");
			tag.Scale = Pango.Scale.XXLarge;
			tag.CanUndo = true;
			tag.CanGrow = true;
			tag.CanSpellCheck = true;
			Add (tag);

			tag = new NoteTag ("size:large");
			tag.Scale = Pango.Scale.XLarge;
			tag.CanUndo = true;
			tag.CanGrow = true;
			tag.CanSpellCheck = true;
			Add (tag);

			tag = new NoteTag ("size:normal");
			tag.Scale = Pango.Scale.Medium;
			tag.CanUndo = true;
			tag.CanGrow = true;
			tag.CanSpellCheck = true;
			Add (tag);

			tag = new NoteTag ("size:small");
			tag.Scale = Pango.Scale.Small;
			tag.CanUndo = true;
			tag.CanGrow = true;
			tag.CanSpellCheck = true;
			Add (tag);

			// Links

			tag = new NoteTag ("link:broken");
			tag.Underline = Pango.Underline.Single;
			tag.Foreground = "#555753";
			tag.CanActivate = true;
			Add (tag);

			tag = new NoteTag ("link:internal");
			tag.Underline = Pango.Underline.Single;
			tag.Foreground = "#204a87";
			tag.CanActivate = true;
			Add (tag);

			tag = new NoteTag ("link:url");
			tag.Underline = Pango.Underline.Single;
			tag.Foreground = "#3465a4";
			tag.CanActivate = true;
			Add (tag);
		}

		def static bool TagIsSerializable (Gtk.TextTag tag)
		{
			if (tag is NoteTag)
				return ((NoteTag) tag).CanSerialize;
			return false;
		}

		def static bool TagIsGrowable (Gtk.TextTag tag)
		{
			if (tag is NoteTag)
				return ((NoteTag) tag).CanGrow;
			return false;
		}

		def static bool TagIsUndoable (Gtk.TextTag tag)
		{
			if (tag is NoteTag)
				return ((NoteTag) tag).CanUndo;
			return false;
		}

		def static bool TagIsSpellCheckable (Gtk.TextTag tag)
		{
			if (tag is NoteTag)
				return ((NoteTag) tag).CanSpellCheck;
			return false;
		}

		def static bool TagIsActivatable (Gtk.TextTag tag)
		{
			if (tag is NoteTag)
				return ((NoteTag) tag).CanActivate;
			return false;
		}
		
		def static bool TagHasDepth (Gtk.TextTag tag)
		{
			if (tag is DepthNoteTag)
				return true;
			
			return false;
		}

		def DepthNoteTag GetDepthTag(int depth, Pango.Direction direction)
		{
			string name = "depth:" + depth + ":" + direction;
			
			DepthNoteTag tag = Lookup (name) as DepthNoteTag;

			if (tag == null) {
				tag = new DepthNoteTag (depth, direction);
				tag.Indent = -14;
				
				if (direction == Pango.Direction.Rtl)
					tag.RightMargin = (depth+1) * 25;
				else
					tag.LeftMargin = (depth+1) * 25;
				
				tag.PixelsBelowLines = 4;
				tag.Scale = Pango.Scale.Medium;
				tag.SizePoints = 12;
				Add (tag);
			}

			return tag;
		}

		def DynamicNoteTag CreateDynamicTag (string tag_name)
		{
			Type tag_type = tag_types [tag_name] as Type;
			if (tag_type == null) 
				return null;

			DynamicNoteTag tag = (DynamicNoteTag) Activator.CreateInstance(tag_type);
			tag.Initialize (tag_name);
			Add (tag);
			return tag;
		}

		def void RegisterDynamicTag (string tag_name, Type type)
		{
			if (!type.IsSubclassOf (typeof (DynamicNoteTag)))
				throw new Exception ("Must register only DynamicNoteTag types.");

			tag_types [tag_name] = type;
		}

		def bool IsDynamicTagRegistered (string tag_name)
		{
			return tag_types [tag_name] != null;
		}

		protected override void OnTagAdded (Gtk.TextTag tag)
		{
			added_tags.Add (tag);

			NoteTag note_tag = tag as NoteTag;
			if (note_tag != null) {
				note_tag.Changed += OnTagChanged;
			}
		}

		protected override void OnTagRemoved (Gtk.TextTag tag)
		{
			added_tags.Remove (tag);

			NoteTag note_tag = tag as NoteTag;
			if (note_tag != null) {
				note_tag.Changed -= OnTagChanged;
			}
		}

		void OnTagChanged (object sender, Gtk.TagChangedArgs args)
		{
			if (TagChanged != null) {
				TagChanged (this, args);
			}
		}

		def new event Gtk.TagChangedHandler TagChanged;
	}
}
