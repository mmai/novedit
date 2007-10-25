require 'lib/novedit_texttag.rb'

module NoveditTextbuffer

 	def write_tag(tag, xml, start)
    if tag.instance_of?(NoteTag)
      note_tag = tag
    else
			note_tag = NoteTag.new(tag)
    end
    if (!note_tag.nil?) 
      note_tag.Write(xml, start)
    elsif (NoteTagTable.TagIsSerializable(tag)) 
      if (start)
        xml.WriteStartElement(null, tag.Name, null)
      else 
        xml.WriteEndElement()
      end
    end
  end

  def find_depth_tag(iter)
    depth_tag = nil
    iter.tags.each do |tag|
      if (NoteTagTable.TagHasDepth(tag))
          depth_tag = tag
          break
      end
    end
    return depth_tag
  end

	def tag_ends_here(tag, iter, next_iter)
    endshere = (iter.has_tag?(tag) and (!next_iter.has_tag?(tag))) or next_iter.end?
    return endshere
  end


  # This is taken almost directly from GAIM.  There must be a
  # better way to do this...
  #		def Serialize (Gtk.TextBuffer buffer, Gtk.TextIter   start, Gtk.TextIter   end, XmlTextWriter  xml) 
  #def serialize(buffer, startIter, endIter, xml) 
  def serialize(xml) 
    buffer = self
    startIter = buffer.start_iter
    endIter = buffer.end_iter

    tag_stack = Array.new()
    replay_stack = Array.new()
    continue_stack = Array.new()

    iter = startIter
    next_iter = startIter.dup #dup from henri
    iternext_ok = next_iter.forward_char()

    line_has_depth = false
    prev_depth_line = -1
    prev_depth = -1

    xml.WriteStartElement(nil, "note-content", nil)
    xml.WriteAttributeString("version", "0.1")

    # Insert any active tags at startIter into tag_stack...
    startIter.tags.each do |start_tag|
      if (!startIter.toggles_tag?(start_tag)) 
        tag_stack << start_tag
        write_tag(start_tag, xml, true)
      end
    end

#    while (!iter.equal?(endIter) && !iter.char.nil?)
    while (iternext_ok and !iter.equal?(endIter) )
      new_list = false

      buffer.extend(NoveditTextbuffer)
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
            xml.WriteEndElement()

          elsif (depth_tag.depth > prev_depth)
            # Line of greater depth								
            xml.WriteStartElement(nil, "list", nil)

            i = prev_depth + 2
            while (i <= depth_tag.depth)
              # Start a new nested list
              xml.WriteStartElement(nil, "list-item", nil)
              xml.WriteStartElement(nil, "list", nil)
              i+=1
            end			
          else 
            # Line of lesser depth
            # Close previous <list-item>
            # and nested <list>s
            xml.WriteEndElement()

            int i = prev_depth
            while (i > depth_tag.depth) 
              # Close nested <list>
              xml.WriteEndElement()
              # Close <list-item>
              xml.WriteEndElement()
              i-=1
            end
          end	
        else 
          # Start of new list
          xml.WriteStartElement(nil, "list", nil)
          int i = 1
          while ( i <= depth_tag.depth) 
            xml.WriteStartElement(nil, "list-item", nil)
            xml.WriteStartElement(nil, "list", nil)
            i += 1
          end
          new_list = true
        end

        prev_depth = depth_tag.depth

        # Start a new <list-item>
        write_tag(depth_tag, xml, true)
      end

      # Output any tags that begin at the current position
      iter.tags.each do |tag|
        if (iter.begins_tag?(tag)) 
#          if (!(tag.instance_of?(DepthNoteTag)) && NoteTagTable.TagIsSerializable(tag)) 
#          if (NoteTagTable.TagIsSerializable(tag)) 
            write_tag(tag, xml, true)
            tag_stack << tag
          #end
        end
      end

      # Reopen tags that continued across indented lines 
      # or into or out of lines with a depth
      compt = 0
      while (continue_stack.length > 0 && ((depth_tag.nil? && iter.starts_line?()) || iter.line_offset == 1))
        continue_tag = continue_stack.pop()
        puts compt+=1

        if (!tag_ends_here(continue_tag, iter, next_iter) && iter.has_tag(continue_tag))
          write_tag(continue_tag, xml, true)
          tag_stack.push(continue_tag)
        end
      end			

      # Hidden character representing an anchor
      if (iter.char[0] == 0xFFFC) 
        puts("Got child anchor!!!")
        if (iter.child_anchor != nil) 
          string serialize = iter.child_anchor.data["serialize"].to_s
          xml.WriteRaw(serialize) unless serialize.nil? 
        end
      elsif (depth_tag.nil?) 
        xml.WriteString(iter.char)
      end

      end_of_depth_line = line_has_depth && next_iter.ends_line?()

      next_line_has_depth = false
      if (iter.line < buffer.line_count - 1) 
        next_line = buffer.get_iter_at_line(iter.line+1)
        next_line_has_depth = !(buffer.find_depth_tag(next_line).nil?)
      end

      at_empty_line = iter.ends_line? && iter.starts_line?

      if (end_of_depth_line || (next_line_has_depth && (next_iter.ends_line() || at_empty_line))) 
        # Close all tags in the tag_stack
        while (tag_stack.Count > 0) 
          existing_tag = tag_stack.pop()

          # Any tags which continue across the indented
          # line are added to the continue_stack to be
          # reopened at the start of the next <list-item>
          if (!tag_ends_here(existing_tag, iter, next_iter)) 
            continue_stack.push(existing_tag)
          end

          write_tag(existing_tag, xml, false)
        end					
      else 
        iter.tags.each do |tag|
          if (tag_ends_here(tag, iter, next_iter) && NoteTagTable.TagIsSerializable(tag) && !(tag.instance_of?(DepthNoteTag))) 
            while (tag_stack.length > 0) 
              existing_tag = tag_stack.pop()

              if (!tag_ends_here(existing_tag, iter, next_iter)) 
                replay_stack.push(existing_tag)
              end

              write_tag(existing_tag, xml, false)
            end

            # Replay the replay queue.
            # Restart any tags that
            # overlapped with the ended
            # tag...
            while (replay_stack.length > 0) 
              replay_tag = replay_stack.pop()
              tag_stack.push(replay_tag)
              write_tag(replay_tag, xml, true)
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
          xml.WriteFullEndElement()
          # Close <list-item>
          xml.WriteFullEndElement()
          i-=1
        end
        prev_depth = -1
      end

      iternext_ok  = iter.forward_char()
      next_iter.forward_char()
    end

    # Empty any trailing tags left in tag_stack..
    while (tag_stack.length > 0) 
      tail_tag = tag_stack.pop()
      write_tag(tail_tag, xml, false)
    end

    xml.WriteEndElement() # </note-content>
    return xml.to_s
  end

  def deserialize (buffer, startIter, xml) 
    offset = startIter.offset
    stack = Array.new
    tag_start = TagStart.new
    note_table = buffer.tag_table
    curr_depth = -1

    # A stack of boolean values which mark if a
    # list-item contains content other than another list
    list_stack = Array.new

    while (xml.read()) 
      case (xml.NodeType) 
      when XmlNodeType.Element
        break if (xml.Name == "note-content")
        tag_start = TagStart.new
        tag_start.Start = offset
        if (!note_table.nil? && note_table.IsDynamicTagRegistered(xml.Name)) 
          tag_start.Tag = note_table.CreateDynamicTag(xml.Name)
        elsif (xml.Name == "list") 
          curr_depth += 1
          break
        elsif (xml.Name == "list-item") 
          if (curr_depth >= 0) 
            if (xml.GetAttribute("dir") == "rtl") 
              tag_start.Tag = note_table.GetDepthTag(curr_depth, Pango.Direction.Rtl)
            else
              tag_start.Tag = note_table.GetDepthTag(curr_depth, Pango.Direction.Ltr)
            end							
            list_stack << false
          else 
            Logger.Error("</list> tag mismatch");
          end
        else 
          tag_start.Tag = buffer.TagTable.Lookup(xml.Name)
        end
        if (tag_start.Tag.instance_of(NoteTag)) 
          tag_start.Tag.Read(xml, true)
        end

        stack << tag_start
      when XmlNodeType.Text
      when XmlNodeType.Whitespace
      when XmlNodeType.SignificantWhitespace
        insert_at = buffer.GetIterAtOffset(offset)
        buffer.insert(insert_at, xml.Value)

        offset += xml.Value.Length

        # If we are inside a <list-item> mark off 
        # that we have encountered some content 
        if (list_stack.Count > 0) 
          list_stack.pop()
          list_stack << true
        end
      when XmlNodeType.EndElement
        break if (xml.Name == "note-content")

        if (xml.Name == "list") 
          curr_depth -=1
          break
        end

        tag_start = stack.pop()
        break if (tag_start.Tag.nil?)

        apply_start = buffer.GetIterAtOffset(tag_start.Start)
        apply_end = buffer.GetIterAtOffset(offset)

        if (tag_start.Tag.instance_of(NoteTag)) 
          tag_start.Tag.Read(xml, false)
        end

        # Insert a bullet if we have reached a closing 
        # <list-item> tag, but only if the <list-item>
        # had content.
        depth_tag = DepthNoteTag.new(tag_start.Tag)

        if (!depth_tag.nil? && list_stack.pop()) 
          buffer.InsertBullet(apply_start, depth_tag.Depth, depth_tag.Direction)
          buffer.RemoveAllTags(apply_start, apply_start)
          offset += 2
        elsif(depth_tag == null) 
          buffer.ApplyTag(tag_start.Tag, apply_start, apply_end)
        end
        break
      else
        Logger.Log("Unhandled element {0}. Value: '{1}'", xml.NodeType, xml.Value)
      end
    end
  end
end

class TagStart
  attr_reader :start, :tag
end


