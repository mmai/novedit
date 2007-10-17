class NoveditTextbuffer < Gtk::TextBuffer
  # This is taken almost directly from GAIM.  There must be a
  # better way to do this...
  #		def Serialize (Gtk.TextBuffer buffer, Gtk.TextIter   start, Gtk.TextIter   end, XmlTextWriter  xml) 
  def Serialize (buffer, start, fin, xml) 
    tag_stack = Stack.new ()
    replay_stack = Stack.new ()
    continue_stack = Stack.new ()

    iter = start
    next_iter = start
    next_iter.ForwardChar ()

    line_has_depth = false
    prev_depth_line = -1
    prev_depth = -1

    xml.WriteStartElement (nil, "note-content", nil)
    xml.WriteAttributeString ("version", "0.1")

    # Insert any active tags at start into tag_stack...
    start.Tags.each do |start_tag|
      if (!start.TogglesTag (start_tag)) 
        tag_stack << start_tag
        WriteTag (start_tag, xml, true)
      end
    end

    while (!iter.Equal (fin) && !iter.Char.nil?)
      new_list = false

      depth_tag = ((NoteBuffer)buffer).FindDepthTag (iter)

      # If we are at a character with a depth tag we are at the 
      # start of a bulleted line
      if (!depth_tag.nil? && iter.StartsLine())
        line_has_depth = true

        if (iter.Line == prev_depth_line + 1) 
          # Line part of existing list

          if (depth_tag.Depth == prev_depth)
            # Line same depth as previous
            # Close previous <list-item>
            xml.WriteEndElement ()

          elsif (depth_tag.Depth > prev_depth)
            # Line of greater depth								
            xml.WriteStartElement (nil, "list", nil)

            i = prev_depth + 2
            while (i <= depth_tag.Depth)
              # Start a new nested list
              xml.WriteStartElement (nil, "list-item", nil)
              xml.WriteStartElement (nil, "list", nil)
              i+=1
            end			
          else 
            # Line of lesser depth
            # Close previous <list-item>
            # and nested <list>s
            xml.WriteEndElement ()

            int i = prev_depth
            while (i > depth_tag.Depth) 
              # Close nested <list>
              xml.WriteEndElement ()
              # Close <list-item>
              xml.WriteEndElement ()
              i-=1
            end
          end	
        else 
          # Start of new list
          xml.WriteStartElement (nil, "list", nil)
          int i = 1
          while ( i <= depth_tag.Depth) 
            xml.WriteStartElement (nil, "list-item", nil)
            xml.WriteStartElement (nil, "list", nil)
            i += 1
          end
          new_list = true
        end

        prev_depth = depth_tag.Depth

        # Start a new <list-item>
        WriteTag (depth_tag, xml, true)
      end

      # Output any tags that begin at the current position
      iter.Tags.each do |tag|
        if (iter.BeginsTag (tag)) 

          if (!(tag is DepthNoteTag) && NoteTagTable.TagIsSerializable(tag)) 
            WriteTag (tag, xml, true)
            tag_stack.Push (tag)
          end
        end
      end

      # Reopen tags that continued across indented lines 
      # or into or out of lines with a depth
      while (continue_stack.Count > 0 && ((depth_tag.nil? && iter.StartsLine ()) || iter.LineOffset == 1))
        continue_tag = (Gtk.TextTag) continue_stack.Pop()

        if (!TagEndsHere (continue_tag, iter, next_iter) && iter.HasTag (continue_tag))
          WriteTag (continue_tag, xml, true)
          tag_stack.Push (continue_tag)
        end
      end			

      # Hidden character representing an anchor
      if (iter.Char[0] == (char) 0xFFFC) 
        Logger.Log ("Got child anchor!!!")
        if (iter.ChildAnchor != nil) 
          string serialize = (string) iter.ChildAnchor.Data ["serialize"]
          xml.WriteRaw (serialize) unless serialize.nil? 
        end
      elsif (depth_tag == nil) 
        xml.WriteString (iter.Char)
      end

      end_of_depth_line = line_has_depth && next_iter.EndsLine ()

      next_line_has_depth = false
      if (iter.Line < buffer.LineCount - 1) 
        Gtk.TextIter next_line = buffer.GetIterAtLine(iter.Line+1)
        next_line_has_depth = not ((NoteBuffer)buffer).FindDepthTag (next_line).nil?
      end

      at_empty_line = iter.EndsLine () && iter.StartsLine ()

      if (end_of_depth_line || (next_line_has_depth && (next_iter.EndsLine () || at_empty_line))) 
        # Close all tags in the tag_stack
        while (tag_stack.Count > 0) 
          existing_tag = tag_stack.Pop () as Gtk.TextTag

          # Any tags which continue across the indented
          # line are added to the continue_stack to be
          # reopened at the start of the next <list-item>
          if (!TagEndsHere (existing_tag, iter, next_iter)) 
            continue_stack.Push (existing_tag)
          end

          WriteTag (existing_tag, xml, false)
        end					
      else 
        iter.Tags.each do |tag|
          if (TagEndsHere (tag, iter, next_iter) && NoteTagTable.TagIsSerializable(tag) && !(tag is DepthNoteTag)) 
            while (tag_stack.Count > 0) 
              Gtk.TextTag existing_tag = tag_stack.Pop () as Gtk.TextTag

              if (!TagEndsHere (existing_tag, iter, next_iter)) 
                replay_stack.Push (existing_tag)
              end

              WriteTag (existing_tag, xml, false)
            end

            # Replay the replay queue.
            # Restart any tags that
            # overlapped with the ended
            # tag...
            while (replay_stack.Count > 0) 
              Gtk.TextTag replay_tag = replay_stack.Pop () as Gtk.TextTag
              tag_stack.Push (replay_tag)

              WriteTag (replay_tag, xml, true)
            end				
          end
        end
      end

      # At the end of the line record that it
      # was the last line encountered with a depth
      if (end_of_depth_line) 
        line_has_depth = false
        prev_depth_line = iter.Line
      end

      # If we are at the end of a line with a depth and the
      # next line does not have a depth line close all <list> 
      # and <list-item> tags that remain open
      if (end_of_depth_line && !next_line_has_depth) 
        i = prev_depth
        while (i>-1)
          # Close <list>
          xml.WriteFullEndElement ()
          # Close <list-item>
          xml.WriteFullEndElement ()
          i-=1
        end
        prev_depth = -1
      end

      iter.ForwardChar ()
      next_iter.ForwardChar ()
    end

    # Empty any trailing tags left in tag_stack..
    while (tag_stack.Count > 0) 
      Gtk.TextTag tail_tag = (Gtk.TextTag) tag_stack.Pop ()
      WriteTag (tail_tag, xml, false)
    end

    xml.WriteEndElement () # </note-content>
  end
end
