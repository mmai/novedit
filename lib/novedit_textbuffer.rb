module NoveditTextbuffer

 	def write_tag (tag, xml, start)
			note_tag = tag
			if (!note_tag.nil?) 
				note_tag.Write (xml, start)
			elsif (NoteTagTable.TagIsSerializable (tag)) 
				if (start)
					xml.WriteStartElement (null, tag.Name, null)
				else 
					xml.WriteEndElement ()
        end
      end
  end

  def find_depth_tag (iter)
    depth_tag = nil?
    iter.tags.each do |tag|
      if (NoteTagTable.TagHasdepth (tag)
          depth_tag = tag
          break
      end
    end
    return depth_tag
  end

	def tag_ends_here(tag, iter, next_iter)
			return (iter.has_tag(tag) and !next_iter.has_tag(tag)) or next_iter.is_end
  end


  # This is taken almost directly from GAIM.  There must be a
  # better way to do this...
  #		def Serialize (Gtk.TextBuffer buffer, Gtk.TextIter   start, Gtk.TextIter   end, XmlTextWriter  xml) 
  def serialize (buffer, startIter, endIter, xml) 
    tag_stack = Array.new ()
    replay_stack = Array.new ()
    continue_stack = Array.new ()

    iter = startIter
    next_iter = startIter
    next_iter.forward_char ()

    line_has_depth = false
    prev_depth_line = -1
    prev_depth = -1

    xml.WriteStartElement (nil, "note-content", nil)
    xml.WriteAttributeString ("version", "0.1")

    # Insert any active tags at startIter into tag_stack...
    startIter.tags.each do |start_tag|
      if (!startIter.toggles_tag? (start_tag)) 
        tag_stack << start_tag
        write_tag (start_tag, xml, true)
      end
    end

    while (!iter.equal?(endIter) && !iter.char.nil?)
      new_list = false

      buffer.extends(NoveditTextBuffer)
      depth_tag = buffer.find_depth_tag(iter)

      # If we are at a character with a depth tag we are at the 
      # start of a bulleted line
      if (!depth_tag.nil? && iter.starts_line?)
        line_has_depth = true

        if (iter.line == prev_depth_line + 1) 
          # Line part of existing list

          if (depth_tag.depth == prev_depth)
            # Line same depth as previous
            # Close previous <list-item>
            xml.WriteEndElement ()

          elsif (depth_tag.depth > prev_depth)
            # Line of greater depth								
            xml.WriteStartElement (nil, "list", nil)

            i = prev_depth + 2
            while (i <= depth_tag.depth)
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
            while (i > depth_tag.depth) 
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
          while ( i <= depth_tag.depth) 
            xml.WriteStartElement (nil, "list-item", nil)
            xml.WriteStartElement (nil, "list", nil)
            i += 1
          end
          new_list = true
        end

        prev_depth = depth_tag.depth

        # Start a new <list-item>
        write_tag (depth_tag, xml, true)
      end

      # Output any tags that begin at the current position
      iter.tags.each do |tag|
        if (iter.begins_tag?(tag)) 
          if (!(tag.instance_of?(depthNoteTag)) && NoteTagTable.TagIsSerializable(tag)) 
            write_tag (tag, xml, true)
            tag_stack << tag
          end
        end
      end

      # Reopen tags that continued across indented lines 
      # or into or out of lines with a depth
      while (continue_stack.count > 0 && ((depth_tag.nil? && iter.starts_line ()) || iter.line_offset == 1))
        continue_tag = continue_stack.pop()

        if (!tag_ends_here (continue_tag, iter, next_iter) && iter.has_tag (continue_tag))
          write_tag (continue_tag, xml, true)
          tag_stack.push (continue_tag)
        end
      end			

      # Hidden character representing an anchor
      if (iter.char[0] == (char) 0xFFFC) 
        puts ("Got child anchor!!!")
        if (iter.child_anchor != nil) 
          string serialize = (string) iter.child_anchor.data ["serialize"]
          xml.WriteRaw (serialize) unless serialize.nil? 
        end
      elsif (depth_tag == nil) 
        xml.WriteString (iter.Char)
      end

      end_of_depth_line = line_has_depth && next_iter.ends_line ()

      next_line_has_depth = false
      if (iter.Line < buffer.line_count - 1) 
        next_line = buffer.get_iter_at_line(iter.line+1)
        next_line_has_depth = not buffer.find_depth_tag(next_line).nil?
      end

      at_empty_line = iter.ends_line () && iter.starts_line ()

      if (end_of_depth_line || (next_line_has_depth && (next_iter.ends_line () || at_empty_line))) 
        # Close all tags in the tag_stack
        while (tag_stack.Count > 0) 
          existing_tag = tag_stack.pop()

          # Any tags which continue across the indented
          # line are added to the continue_stack to be
          # reopened at the start of the next <list-item>
          if (!tag_ends_here (existing_tag, iter, next_iter)) 
            continue_stack.push(existing_tag)
          end

          write_tag (existing_tag, xml, false)
        end					
      else 
        iter.tags.each do |tag|
          if (tag_ends_here (tag, iter, next_iter) && NoteTagTable.TagIsSerializable(tag) && !(tag.instance_of?(depthNoteTag))) 
            while (tag_stack.count > 0) 
              existing_tag = tag_stack.pop()

              if (!tag_ends_here (existing_tag, iter, next_iter)) 
                replay_stack.push (existing_tag)
              end

              write_tag (existing_tag, xml, false)
            end

            # Replay the replay queue.
            # Restart any tags that
            # overlapped with the ended
            # tag...
            while (replay_stack.Count > 0) 
              Gtk.TextTag replay_tag = replay_stack.pop()
              tag_stack.push(replay_tag)
              write_tag (replay_tag, xml, true)
            end				
          end
        end
      end

      # At the end of the line record that it
      # was the last line encountered with a depth
      if (end_of_depth_line) 
        line_has_depth = false
        prev_depth_line = iter.line
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

      iter.forward_char ()
      next_iter.forward_char ()
    end

    # Empty any trailing tags left in tag_stack..
    while (tag_stack.Count > 0) 
      tail_tag = tag_stack.pop()
      write_tag (tail_tag, xml, false)
    end

    xml.WriteEndElement () # </note-content>
  end
end
