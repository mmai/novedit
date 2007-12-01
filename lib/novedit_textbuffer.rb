require 'lib/novedit_texttag.rb'
require 'lib/novedit_xml.rb'
require 'lib/unicode.rb'

# Excepté la désérialisation, ce module est essentiellement une traduction en ruby 
# des fonctions de traitement de texte utilisées dans
# l'application Gtk Tomboy (http:#www.gnome.org/projects/tomboy/)
module NoveditTextbuffer

  #############################################
  #
  # GESTION DES PUCES
  #
  #############################################


  # Returns true if the cursor is inside of a bulleted list
  def is_bulleted_list_active?()
    insert_mark = self.get_mark('insert')
    iter = self.get_iter_at_mark(insert_mark)
    iter.line_offset = 0
    depth = find_depth_tag(iter)
    return !depth.nil?
  end

  # Returns true if the cursor is at a position that can
  # be made into a bulleted list
  def	can_make_bulleted_list?()
    insert_mark = self.get_mark('insert')
    iter = self.get_iter_at_mark(insert_mark)
    return (iter.line!=0)
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

  def add_newline(iter)
    return false if (!can_make_bulleted_list?)

    #iter = self.get_iter_at_mark(self.get_mark('insert'))
    insert_mark = self.create_mark(nil, iter, false)
    iter.line_offset = 0

    prev_depth = find_depth_tag(iter)

    # If the previous line has a bullet point on it we add a bullet
    # to the new line, unless the previous line was blank (apart from
    # the bullet), in which case we clear the bullet/indent from the
    # previous line.
    if (!prev_depth.nil?) #bullet
      iter.forward_char() #quelque chose sur la ligne ?

      insert = self.get_iter_at_mark(insert_mark)

      # See if the line was left contentless and remove the bullet if so.
      if (iter.ends_line?() || insert.line_offset < 3 )
        start = get_iter_at_line(iter.line)
        fin = start.dup
        fin.forward_to_line_end()

        if (fin.line_offset < 2) 
          fin = start.dup
        else 
          fin = self.get_iter_at_line_offset(iter.line, 2)
        end

        self.delete(start, fin)

        iter = get_iter_at_mark(insert_mark)
#        self.insert(iter, "\n")				
      else #On insere une puce sur la nouvelle ligne
        #					Undoer.FreezeUndo();
        iter = get_iter_at_mark(insert_mark)
        offset = iter.offset
        self.insert(iter, "\n")

        iter = get_iter_at_mark(insert_mark)
        start = get_iter_at_line(iter.line)
 
        # Set the direction of the bullet to be the same
        # as the first character on the new line
        #					Pango::DIRECTION_direction = prev_depth.direction
        if (iter.char != "\n" && iter.char.length > 0)
          direction = Pango.unichar_direction(iter.char[0])
        end

        insert_bullet(start, prev_depth.depth, direction)
        #					Undoer.ThawUndo();

        #					new_bullet_inserted(self, insert_bulletEventArgs.new(offset, prev_depth.depth, direction))
      end

      return true;
      # Replace lines starting with '*' or '-' with bullets
    elsif (iter.char=='*' || iter.char=='-') 		
      start = get_iter_at_line_offset(iter.line, 0)
      fin = get_iter_at_line_offset(iter.line, 1)

      # Remove the '*' character and any leading white space
      if (fin.char == " ")
        fin.forward_char()
      end

      # Set the direction of the bullet to be the same as
      # the first character after the '*' or '-'
      #				Pango::DIRECTION_direction = Pango::DIRECTION_LTR
      if (fin.char.length > 0)
        direction = Pango.unichar_direction(fin.char[0])
      end

      self.delete(start, fin)

      if (fin.ends_line?()) 
        increase_depth(start)
      else 
        increase_depth(start)

        iter = get_iter_at_mark(insert_mark)
        offset = iter.offset
        self.insert(iter, "\n")

        iter = get_iter_at_mark(insert_mark)
        iter.line_offset = 0

        #					Undoer.FreezeUndo();
        insert_bullet(iter, 0, direction)
        #					Undoer.ThawUndo();

        #        new_bullet_inserted(self, insert_bulletEventArgs.new(offset, 0, direction))
      end			

      return true
    end
    return false
  end

  # Returns true if the depth of the line was increased
  def add_tab()
    insert_mark = self.get_mark("insert")
    iter = get_iter_at_mark(insert_mark)
    iter.line_offset = 0		

    tag_depth = find_depth_tag(iter)

    # If the cursor is at a line with a depth and a tab has been
    # inserted then we increase the indent depth of that line.
    if (!tag_depth.nil?) 
      increase_depth(iter)
      return true
    end		

    return false
  end

  # Returns true if the depth of the line was decreased
  def remove_tab()
    insert_mark = self.get_mark("insert")
    iter = get_iter_at_mark(insert_mark)

    #On regarde si on se trouve au début de la ligne (juste après l'éventuelle puce)
    if (iter.line_offset < 3) 
      iter.line_offset = 0
      depth = find_depth_tag(iter)

      # If the cursor is at a line with depth and a tab has been
      # inserted, then we decrease the depth of that line.
      if (!depth.nil?) 
        decrease_depth(iter)
        return true
      end
    end

    return false
  end


  # Returns true if a bullet had to be removed
  # This is for the Delete key not Backspace
  def delete_key_handler()
    # See if there is a selection
    (start, fin, selected) = self.selection_bounds

    if (selection) 
      augment_selection(start, fin)
      self.delete(start, fin)
      return true
    elsif (start.ends_line?() && start.line < self.line_count)
      suivant = get_iter_at_line(start.line + 1)
      fin = start
      fin.forward_chars(3)

      depth = find_depth_tag(suivant)

      if (depth != null) 
        self.delete(start, fin)
        return true
      end
    else 
      suivant = start
      suivant.forward_char() if (suivant.line_offset != 0)

      depth = find_depth_tag(start)
      nextDepth = find_depth_tag(suivant)
      if !(depth.nil? && nextDepth.nil?) 
        decrease_depth(start)
        return true
      end
    end			

    return false
  end

  def backspace_key_handler()
    start
    fin

    selection = get_selection_bounds(start, fin)

    depth = find_depth_tag(start)

    if (selection) 
      augment_selection(start, fin)
      self.delete(start, fin)
      return true
    else 
      # See if the cursor is inside or just after a bullet region
      # ie. 
      # |* lorum ipsum
      #  ^^^
      # and decrease the depth if it is.

      prev = start

      if (prev.line_offset != 0)
        prev.BackwardChars(1)
      end

      DepthNoteTag prev_depth = find_depth_tag(prev);
      if (depth != null || prev_depth != null) 
        decrease_depth(start);
        return true
      end
    end

    return false
  end		

  # On an InsertEvent we change the selection (if there is one) 
  # so that it doesn't slice through bullets.
  #		[GLib.ConnectBefore]
  def check_selection()
    (start, fin, selected) = self.selection_bounds

    selection = get_selection_bounds(start, fin)

    if (selection) 
      augment_selection(start, fin)
    else 
      # If the cursor is at the start of a bulleted line
      # move it so it is after the bullet.
      if ((start.line_offset == 0 || start.line_offset == 1) && !find_depth_tag(start).nil?) 
        start.line_offset = 2
        self.select_range(start, start)
      end
    end
  end

  # Toggle the lines in the selection to have bullets or not
  def toggle_selection_bullets()
    (start, fin, selected) = self.selection_bounds

    start = get_iter_at_line_offset(start.line, 0)

    toggle_on = true
    if (!find_depth_tag(start).nil?) 
      bullet_end = get_iter_at_line_offset(start.line, 2)
      toggle_on = false
    end

    start_line = start.line
    end_line = fin.line

    start_line.upto(end_line) do |i|
      curr_line = get_iter_at_line(i)
      if(toggle_on && find_depth_tag(curr_line).nil?) 
        increase_depth(curr_line)
      elsif (!toggle_on && !find_depth_tag(curr_line).nil?) 
        bullet_end = get_iter_at_line_offset(curr_line.line, 2)
        self.delete(curr_line, bullet_end)
      end
    end
  end

  # Increase or decrease the depth of the line at the
  # cursor depending on wheather it is RTL or LTR
  def change_cursor_depth_directional(right)
    (start, fin, selected) = self.selection_bounds

    # If we are moving right then:
    #   RTL => decrease depth
    #   LTR => increase depth
    # We choose to increase or decrease the depth 
    # based on the fist line in the selection.
    increase = right
    start.line_offset = 0
    start_depth = find_depth_tag(start)

    rtl_depth = !start_depth.nil? && start_depth.direction == Pango::DIRECTION_RTL
    first_char_rtl = start.char.length > 0 && (Pango.Global.UnicharDirection(start.char[0]) == Pango.direction.Rtl)
    suivant = start

    if (!start_depth.nil?) 
      suivant.forward_chars(2)
    else 
      # Look for the first non-space character on the line
      # and use that to determine what direction we should go
      suivant.forward_sentence_end()
      suivant.backward_sentence_start()
      first_char_rtl = suivant.char.length > 0 && (Pango.Global.UnicharDirection(suivant.char[0]) == Pango::DIRECTION_RTL);				
    end

    if ((rtl_depth || first_char_rtl) && ((suivant.line == start.line) && !suivant.ends_line?())) 
      increase = !right
    end

    change_cursor_depth(increase)
  end	

  def change_cursor_depth(increase)
    (start, fin, selected) = self.selection_bounds

    get_selection_bounds(start, fin)

    curr_line = Gtk::TextIter.new

    start_line = start.line
    end_line = fin.line

    start_line.upto(end_line) do |i|
      curr_line = get_iter_at_line(i)
      if (increase)
        increase_depth(curr_line)
      else
        decrease_depth(curr_line)
      end
    end		
  end

  # Change the writing direction (ie. RTL or LTR) of a bullet.
  # This makes the bulleted line use the correct indent
  def change_bullet_direction(iter, direction)
    iter.line_offset = 0

    tag = find_depth_tag(iter)
    if (!tag.nil?) 
      if (tag.Direction != direction && direction != Pango::DIRECTION_Neutral) 
        note_table = self.tag_table

        # Get the depth tag for the given direction
        new_tag = note_table.get_depth_tag(tag.Depth, direction)

        suivant = iter
        suivant.forward_char()

        # Replace the old depth tag with the new one
        remove_all_tags(iter, suivant)
        apply_tag(new_tag, iter, suivant)
      end
    end
  end		

  def insert_bullet(iter, depth, direction)
    indent_bullets = [Unicode::U2022, Unicode::U2218, Unicode::U2023]
    note_table = self.tag_table
    tag = note_table.get_depth_tag(depth, direction)
    txt_bullet = indent_bullets[depth % indent_bullets.length] + " "
    self.insert(iter, txt_bullet, tag)
  end

  def remove_bullet(iter)
    (start, fin, selected) = self.selection_bounds
    line_end.forward_to_line_end()
    if (line_end.line_offset < 2) 
      fin = get_iter_at_line_offset(iter.line, 1)
    else 
      fin = get_iter_at_line_offset(iter.line, 2)
    end

    # Go back one more character to delete the \n as well
    iter = get_iter_at_line(iter.line - 1)
    iter.forward_to_line_end()

    self.delete(iter, fin)
  end	

  def increase_depth(iter)
    return if (!can_make_bulleted_list?())

    start = get_iter_at_line_offset(iter.line, 0)
    line_end = start.dup.forward_to_line_end()
    fin = start.dup
    fin.forward_chars(2)

    curr_depth = find_depth_tag(start)

    #			Undoer.FreezeUndo();
    if (curr_depth.nil?) 
      # Insert a brand new bullet
      suivant = start
      suivant.forward_sentence_end()
      suivant.backward_sentence_start()

      # Insert the bullet using the same direction
      # as the text on the line
      direction = Pango::DIRECTION_LTR
      if (suivant.char.length > 0 && suivant.line == start.line)
        direction = Pango.unichar_direction(suivant.char[0])
      end

      insert_bullet(start, 0, direction)
    else 
      start_mark = self.create_mark(nil, start, false)
      # Remove the previous indent
      self.delete(iter, fin)

      # Insert the indent at the new depth
      next_depth = curr_depth.depth + 1
      insert_bullet(get_iter_at_mark(start_mark), next_depth, curr_depth.direction)
    end	
    #			Undoer.ThawUndo();			
    #			change_text_depth(self, ChangeDepthEventArgs.new(start.line, true))
  end

  def decrease_depth(start)
    return if (!can_make_bulleted_list?())
    start = get_iter_at_line_offset(start.line, 0)

    line_end = start.dup
    line_end.forward_to_line_end()

    if (line_end.line_offset < 2 || start.ends_line?()) 
      fin = start.dup
    else
      fin = get_iter_at_line_offset(start.line, 2)
    end

    curr_depth = find_depth_tag(start)

    #			Undoer.FreezeUndo();
    if (!curr_depth.nil?) 
      # Remove the previous indent
      self.delete(start, fin)

      # Insert the indent at the new depth
      next_depth = curr_depth.depth - 1

      if (next_depth != -1) 
        insert_bullet(start, next_depth, curr_depth.direction)
      end
    end
    #			Undoer.ThawUndo();
    #			change_text_depth(self, ChangeDepthEventArgs.new(start.line, false))
  end

  ##################################################
  #
  # SERIALISATION
  #
  ##################################################
  def write_tag(tag, xml, start)
    if tag.instance_of?(NoteTag) or tag.instance_of?(DepthNoteTag)
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
    #    puts tag.name
  end


  def tag_ends_here(tag, iter, next_iter)
    endshere = (iter.has_tag?(tag) and (!next_iter.has_tag?(tag))) or next_iter.end?
    return endshere
  end

  def serialize() 
    xml = NoveditXml.new
    buffer = self
    #   buffer.extend(NoveditTextbuffer)
    startIter = buffer.start_iter
    endIter = buffer.end_iter

    tag_stack = Array.new()
    replay_stack = Array.new()
    continue_stack = Array.new()

    iter = startIter
    next_iter = startIter.dup 
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

    while (iternext_ok and !iter.equal?(endIter) )
      #      xml.WriteString("char:"+iter.char)
      print iter.char
      new_list = false
      depth_tag = find_depth_tag(iter)

      #Est-on sur le dernier charactère d'une ligne de liste ?
      end_of_depth_line = line_has_depth && iter.ends_line? 
      #La ligne est-elle vide ?
      at_empty_line = iter.ends_line? && iter.starts_line?
      #Est-ce que la prochaine ligne est une ligne de liste ?
      next_line_has_depth = false
      if (iter.line < buffer.line_count - 1) 
        iter_next_line = buffer.get_iter_at_line(iter.line+1)
        next_line_has_depth = !(buffer.find_depth_tag(iter_next_line).nil?)
      end

      # If we are at a character with a depth tag we are at the 
      # start of a bulleted line
      if (!depth_tag.nil? && iter.starts_line?)
        line_has_depth = true
        if (iter.line == prev_depth_line + 1) 
          # Line part of existing list, close previous <list-item>
          xml.WriteEndElement()
          if (depth_tag.depth == prev_depth)
            # Line same depth as previous
          elsif (depth_tag.depth > prev_depth)
            # Line of greater depth								
            #            xml.WriteStartElement(nil, "list", nil)
            i = prev_depth 
            while (i < depth_tag.depth)
              # Start a new nested list
              #              xml.WriteStartElement(nil, "list-item", nil)
              xml.WriteStartElement(nil, "list", nil)
              i+=1
            end			
          else 
            # Line of lesser depth, close previous <list-item> and nested <list>s
            xml.WriteEndElement()
            i = prev_depth
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
          #          xml.WriteStartElement(nil, "list", nil)
          i = 0
          while ( i <= depth_tag.depth) 
            #            xml.WriteStartElement(nil, "list-item", nil)
            xml.WriteStartElement(nil, "list", nil)
            i += 1
          end
          #            xml.WriteStartElement(nil, "list-item", nil)
          new_list = true
        end

        prev_depth = depth_tag.depth

        # Start a new <list-item>
        #        write_tag(depth_tag, xml, true)
        #        puts "---"
      end
      # fin gestion list/list-items


      if !end_of_depth_line
        # Output any tags that begin at the current position
        iter.tags.each do |tag|
          if (iter.begins_tag?(tag)) 
            #          if (NoteTagTable.TagIsSerializable(tag)) 
            write_tag(tag, xml, true)
            if (!(tag.instance_of?(DepthNoteTag)) && NoteTagTable.TagIsSerializable(tag)) 
              tag_stack << tag
            end
          end
        end

        # Reopen tags that continued across indented lines 
        # or into or out of lines with a depth
        compt = 0
        while (continue_stack.length > 0 && ((depth_tag.nil? && iter.starts_line?()) || iter.line_offset == 1))
          continue_tag = continue_stack.pop()
          if (!tag_ends_here(continue_tag, iter, next_iter) && iter.has_tag?(continue_tag))
            write_tag(continue_tag, xml, true)
            tag_stack << continue_tag
          end
        end			

        #On ecrit le caractère si ce n'est pas un caractère de liste
        if (depth_tag.nil? )
          #          if !(iter.char=="\n" and (prev_depth_line>-1) and (iter.line=prev_depth_line+1))
          xml.WriteString(iter.char)
          #          end
        end
      end


      if (end_of_depth_line || (next_line_has_depth && (iter.ends_line? || at_empty_line))) 
        # Close all tags in the tag_stack
        while (tag_stack.length > 0) 
          existing_tag = tag_stack.pop()

          # Any tags which continue across the indented line are added to
          # the continue_stack to be reopened at the start of the next <list-item>
          if (!tag_ends_here(existing_tag, iter, next_iter)) 
            continue_stack << existing_tag
          end
          write_tag(existing_tag, xml, false)
        end					
      else 
        iter.tags.each do |tag|
          if (tag_ends_here(tag, iter, next_iter) && NoteTagTable.TagIsSerializable(tag) && !(tag.instance_of?(DepthNoteTag))) 
            while (tag_stack.length > 0) 
              existing_tag = tag_stack.pop()
              if (!tag_ends_here(existing_tag, iter, next_iter)) 
                replay_stack << existing_tag
              end
              write_tag(existing_tag, xml, false)
            end

            # Replay the replay queue.
            # Restart any tags that overlapped with the ended tag...
            while (replay_stack.length > 0) 
              replay_tag = replay_stack.pop()
              tag_stack << replay_tag
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
        xml.WriteFullEndElement()
#        xml.WriteString("\n")
        prev_depth = -1
      end

      iternext_ok  = iter.forward_char()
      next_iter.forward_char()
    end
    # Fin de la boucle de traitement de chaque iter

    # Empty any trailing tags left in tag_stack..
    while (tag_stack.length > 0) 
      tail_tag = tag_stack.pop()
      write_tag(tail_tag, xml, false)
    end

    xml.WriteEndElement() # </note-content>

    #    puts "["+xml.to_s+"]"
    #    TTT
    File.open('tests/noveditbuffer.xml', 'w') do |f|
      f << xml.to_s
    end
    #/TTT
    return xml.to_s
  end

  require 'rexml/document'

  def deserialize (strXml) 
    buffer = self
    buffer.delete(buffer.start_iter, buffer.end_iter)
    startIter = buffer.start_iter
    offset = startIter.offset
    @deserialize_stack = Array.new
    @curr_depth = -1

    xmldoc = REXML::Document.new(strXml)
    xmldoc.elements.each do |element|
      lireXml(element, offset)
    end
  end

  def dbg(message)
    self.insert(self.end_iter, "|"+message)
  end

  def lireXml(element, offset)
    buffer = self
    note_table = buffer.tag_table
    case element.name
      #when "note-content" #Noeud racine
    when "t" #Noeud texte
      buffer.insert(buffer.end_iter, element.text)
    when "list"
      @curr_depth += 1
      element.elements.each do |elem|
        lireXml(elem, offset)
      end
      @curr_depth -= 1
    when "list-item"
      buffer.insert_bullet(buffer.end_iter, @curr_depth,direction = Pango::DIRECTION_LTR)
      element.elements.each do |elem|
        lireXml(elem, offset)
      end
      buffer.insert(buffer.end_iter, "\n")
    else
      if (!element.name.nil?)
        #Debut tag
        mark_start = buffer.create_mark(nil, buffer.end_iter, true)
        #Traitement des noeuds enfants
        element.elements.each do |elem|
          lireXml(elem, offset)
        end
        #Fin tag
        tag = buffer.tag_table[element.name]
        buffer.apply_tag(tag, buffer.get_iter_at_mark(mark_start), buffer.end_iter) if !tag.nil?
      end
    end
  end
end



