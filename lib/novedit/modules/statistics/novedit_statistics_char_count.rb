class NoveditStatisticsCharCount
  def initialize()
    @name = "charcount"
  end
  
  def to_s(node)
    node.text.size.to_s
  end
end
