class NoveditInfoWordCount
  def initialize()
    @name = "wordcount"
  end
  
  def to_s(node)
    node.text.split.size.to_s
  end
end
