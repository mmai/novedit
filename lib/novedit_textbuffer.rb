class NoveditTextbuffer < Gtk::TextBuffer
  # This is taken almost directly from GAIM.  There must be a
		# better way to do this...
		def Serialize (Gtk.TextBuffer buffer, Gtk.TextIter   start, Gtk.TextIter   end, XmlTextWriter  xml) 
			Stack tag_stack = new Stack ();
			Stack replay_stack = new Stack ();
			Stack continue_stack = new Stack ();

			Gtk.TextIter iter = start;
			Gtk.TextIter next_iter = start;
			next_iter.ForwardChar ();

			bool line_has_depth = false;
			int prev_depth_line = -1;
			int prev_depth = -1;

			xml.WriteStartElement (null, "note-content", null);
			xml.WriteAttributeString ("version", "0.1");

			# Insert any active tags at start into tag_stack...
			foreach (Gtk.TextTag start_tag in start.Tags) {
				if (!start.TogglesTag (start_tag)) {
					tag_stack.Push (start_tag);
					WriteTag (start_tag, xml, true);
				}
			}

			while (!iter.Equal (end) && iter.Char != null) {
				bool new_list = false;

				DepthNoteTag depth_tag = ((NoteBuffer)buffer).FindDepthTag (iter);

				# If we are at a character with a depth tag we are at the 
				# start of a bulleted line
				if (depth_tag != null && iter.StartsLine()) {
					line_has_depth = true;
					
					if (iter.Line == prev_depth_line + 1) {
						# Line part of existing list
						
						if (depth_tag.Depth == prev_depth) {
							# Line same depth as previous
							# Close previous <list-item>
							xml.WriteEndElement ();
													
						} else if (depth_tag.Depth > prev_depth) {
							# Line of greater depth								
							xml.WriteStartElement (null, "list", null);
							
							for (int i = prev_depth + 2; i <= depth_tag.Depth; i++) {
								# Start a new nested list
								xml.WriteStartElement (null, "list-item", null);
								xml.WriteStartElement (null, "list", null);
							}			
						} else {
							# Line of lesser depth
							# Close previous <list-item>
							# and nested <list>s
							xml.WriteEndElement ();
							
							for (int i = prev_depth; i > depth_tag.Depth; i--) {
								# Close nested <list>
								xml.WriteEndElement ();
								# Close <list-item>
								xml.WriteEndElement ();
							}
						}	
					} else {
						# Start of new list
						xml.WriteStartElement (null, "list", null);
						for (int i = 1; i <= depth_tag.Depth; i++) {
						    xml.WriteStartElement (null, "list-item", null);
							xml.WriteStartElement (null, "list", null);
						}
						new_list = true;
					}
					
					prev_depth = depth_tag.Depth;

					# Start a new <list-item>
					WriteTag (depth_tag, xml, true);
				}

				# Output any tags that begin at the current position
				foreach (Gtk.TextTag tag in iter.Tags) {
					if (iter.BeginsTag (tag)) {

						if (!(tag is DepthNoteTag) && NoteTagTable.TagIsSerializable(tag)) {
							WriteTag (tag, xml, true);
							tag_stack.Push (tag);
						}
					}
				}

				# Reopen tags that continued across indented lines 
				# or into or out of lines with a depth
				while (continue_stack.Count > 0 && 
						((depth_tag == null && iter.StartsLine ()) || iter.LineOffset == 1))
				{
					Gtk.TextTag continue_tag = (Gtk.TextTag) continue_stack.Pop();
					
					if (!TagEndsHere (continue_tag, iter, next_iter)
						&& iter.HasTag (continue_tag))
					{
						WriteTag (continue_tag, xml, true);
						tag_stack.Push (continue_tag);
					}
				}			

				# Hidden character representing an anchor
				if (iter.Char[0] == (char) 0xFFFC) {
					Logger.Log ("Got child anchor!!!");
					if (iter.ChildAnchor != null) {
						string serialize = 
						    (string) iter.ChildAnchor.Data ["serialize"];
						if (serialize != null)
							xml.WriteRaw (serialize);
					}
				} else if (depth_tag == null) {
					xml.WriteString (iter.Char);
				}

				bool end_of_depth_line = line_has_depth && next_iter.EndsLine ();

				bool next_line_has_depth = false;
				if (iter.Line < buffer.LineCount - 1) {
					Gtk.TextIter next_line = buffer.GetIterAtLine(iter.Line+1);
					next_line_has_depth =
						((NoteBuffer)buffer).FindDepthTag (next_line) != null;
				}
				
				bool at_empty_line = iter.EndsLine () && iter.StartsLine ();
			
				if (end_of_depth_line || 
					(next_line_has_depth && (next_iter.EndsLine () || at_empty_line))) 
				{
					# Close all tags in the tag_stack
					while (tag_stack.Count > 0) {
						Gtk.TextTag existing_tag = tag_stack.Pop () as Gtk.TextTag;

						# Any tags which continue across the indented
						# line are added to the continue_stack to be
						# reopened at the start of the next <list-item>
						if (!TagEndsHere (existing_tag, iter, next_iter)) {
							continue_stack.Push (existing_tag);
						}

						WriteTag (existing_tag, xml, false);
					}					
				} else {
					foreach (Gtk.TextTag tag in iter.Tags) {
						if (TagEndsHere (tag, iter, next_iter) && 
							NoteTagTable.TagIsSerializable(tag) && !(tag is DepthNoteTag)) 
						{
							while (tag_stack.Count > 0) {
								Gtk.TextTag existing_tag = tag_stack.Pop () as Gtk.TextTag;

								if (!TagEndsHere (existing_tag, iter, next_iter)) {
									replay_stack.Push (existing_tag);
								}

								WriteTag (existing_tag, xml, false);
							}

							# Replay the replay queue.
							# Restart any tags that
							# overlapped with the ended
							# tag...
							while (replay_stack.Count > 0) {
								Gtk.TextTag replay_tag = replay_stack.Pop () as Gtk.TextTag;
								tag_stack.Push (replay_tag);

								WriteTag (replay_tag, xml, true);
							}				
						}
					}
				}

				# At the end of the line record that it
				# was the last line encountered with a depth
				if (end_of_depth_line) {
					line_has_depth = false;
					prev_depth_line = iter.Line;
				}

				# If we are at the end of a line with a depth and the
				# next line does not have a depth line close all <list> 
				# and <list-item> tags that remain open
				if (end_of_depth_line && !next_line_has_depth) {
					for (int i = prev_depth; i > -1; i--) {
						# Close <list>
						xml.WriteFullEndElement ();
						# Close <list-item>
						xml.WriteFullEndElement ();
					}
							
					prev_depth = -1;
				}

				iter.ForwardChar ();
				next_iter.ForwardChar ();
			}

			# Empty any trailing tags left in tag_stack..
			while (tag_stack.Count > 0) {
				Gtk.TextTag tail_tag = (Gtk.TextTag) tag_stack.Pop ();
				WriteTag (tail_tag, xml, false);
			}

			xml.WriteEndElement (); # </note-content>
      end
