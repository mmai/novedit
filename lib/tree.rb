class TreeNode
  attr_accessor :parent, :leftchild, :rightbrother
  def initialize()
    @parent = nil
    @leftchild = nil
    @rightbrother = nil
  end
  
  def nodes_do(&func)
    yield(self)
    childs.each do |node|
      node.nodes_do(&func)
    end
  end
  
  def get_rightchild
    child = nil
    if @leftchild
      child = @leftchild
      while nextchild = child.rightbrother
        child = nextchild
      end
    end
    return child
  end
  
  def childs
    tabChilds = []
    node = @leftchild
    while not node.nil?
      tabChilds << node
      node = node.rightbrother
    end
    return tabChilds
  end
  
  def ancestors
    tabAncestors = []
    node = @parent
    while not node.nil?
      tabAncestors << node
      node = node.parent
    end
    return tabAncestors
  end
  
  def addNode(node, pos=nil) 
    #On interdit le déplacement d'un noeud dans sa sous-arborescence (boucle infinie)
    if ancestors.include?(node)
      raise TreeNodeException, "Impossible move", caller
    end
    
    if @leftchild.nil?
      @leftchild = node
      node.parent = self
    elsif pos.nil?
      rightchild = get_rightchild
      rightchild.rightbrother = node
      node.parent = self
    elsif pos == 0
      node.rightbrother = @leftchild
      @leftchild = node
      node.parent = self
    else
      curnode = @leftchild
      curpos = 0
      while curpos < (pos-1) and not curnode.rightbrother.nil?
        curnode = curnode.rightbrother
        curpos = curpos + 1
      end
      node.rightbrother = curnode.rightbrother
      node.parent = self
      curnode.rightbrother = node
    end
  end
  
  #Add a node to the node of path path
  def insert_node(path, node)
    parentNode = getNode(path)
    parentNode.addNode(node)
  end
  
  def move_to(new_parent, pos=nil)
    #On interdit le déplacement d'un noeud dans sa sous-arborescence (boucle infinie)
    if new_parent.ancestors.include?(self)
      raise TreeNodeException, "Impossible move", caller
    end
    detach
    new_parent.addNode(self, pos)
  end
  
  def move_node(pathIni, pathFin)
    #On interdit le déplacement d'un noeud dans sa sous-arborescence (boucle infinie)
    if pathFin.index(pathIni)==0
     raise TreeNodeException, "Impossible move", caller
    end
  
    #Noeud à déplacer
    node = getNode(pathIni)
    #Noeud de destination
    newParentNode = getNode(pathFin)
    
    #On détache le noeud de son emplacement actuel
    node.detach
    
    #On ajoute le noeud à son nouveau père
    newParentNode.addNode(node)
  end
  
  def remove(path)
    node = getNode(path)
    node.detach
    node = nil
  end
  
  def getNode(pathNode)
    currentNode = self
    path = pathNode.split(':')
    path.each do |nodePos| 
      currentNode = currentNode.leftchild
      nodePos.to_i.times {currentNode = currentNode.rightbrother}
    end
    return currentNode
  end
  
  def root
    node = self
    node = node.parent while not node.parent.nil?
    return node
  end
  
  def path
    tabPath = []
    node = self
    while not node.parent.nil?
      tabPath << node.pos
      node = node.parent
    end
    return tabPath.reverse.join(":")
  end
  
  def pos
    position = 0
    brother = @parent.leftchild
    while brother!= self
      brother = brother.rightbrother
      position = position + 1
    end
    return position
  end
  
  def detach
    #On détache le noeud de son emplacement actuel
    if @parent.leftchild == self
      @parent.leftchild = @rightbrother
    else
      leftbrother = @parent.leftchild
      while leftbrother.rightbrother != self
        leftbrother = leftbrother.rightbrother
      end
      leftbrother.rightbrother = @rightbrother
    end
    @rightbrother = nil
   end
  
end

class TreeNodeException < RuntimeError
  
end

#class TreeTexte < TreeNode
#  def initialize(texte)
#    super()
#    @texte = texte
#  end
#  
#  def print(level=0)
#    puts "-"*level + @texte
#    tabChilds = childs
#    tabChilds.each do |child|
#      child.print(level+1)
#    end
#  end
#end
#
#arbre = TreeTexte.new('racine')
#fils1 = TreeTexte.new('fils1')
#fils2 = TreeTexte.new('fils2')
#fifils = TreeTexte.new('fifils')
#fifils2 = TreeTexte.new('fifils2')
#arbre.addNode(fils1)
#arbre.addNode(fils2)
#fils1.addNode(fifils)
#fils1.addNode(fifils2)
#arbre.print
#arbre.nodes_do {|node| node.print}
