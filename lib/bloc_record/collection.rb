module BlocRecord
  class Collection < Array
    def update_all(updates)
      ids = self.map(&:id)
      self.any? ? self.first.class.update(ids, updates) : false
    end

    def take(num=1)
      col = BlocRecord::Collection.new
      num.times do
        col << self.shift
      end
      col
    end

    def where(arg)
      self.map do |item|
        item if item[arg.key] == arg.value
      end
    end

    def not(arg)
      self.map do |item|
        item if item[arg.key] != arg.value
      end
    end

    def destroy_all
      self.each do |item|
        item.destroy
      end
    end
  end
end
