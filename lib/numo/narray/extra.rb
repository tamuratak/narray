module Numo
  class NArray

    # @example
    #   p a = Numo::DFloat[[1, 2], [3, 4]]
    #   # Numo::DFloat#shape=[2,2]
    #   # [[1, 2],
    #   #  [3, 4]]
    #
    #   p b = Numo::DFloat[[5, 6]]
    #   # Numo::DFloat#shape=[1,2]
    #   # [[5, 6]]
    #
    #   p Numo::NArray.concatenate([a,b],axis:0)
    #   # Numo::DFloat#shape=[3,2]
    #   # [[1, 2],
    #   #  [3, 4],
    #   #  [5, 6]]
    #
    #   p Numo::NArray.concatenate([a,b.transpose], axis:1)
    #   # Numo::DFloat#shape=[2,3]
    #   # [[1, 2, 5],
    #   #  [3, 4, 6]]

    def self.concatenate(arrays,axis:0)
      klass = (self==NArray) ? NArray.array_type(arrays) : self
      nd = 0
      arrays.map! do |a|
        case a
        when NArray
          # ok
        when Numeric
          a = klass.new(1).store(a)
        when Array
          a = klass.cast(a)
        else
          raise TypeError,"not Numo::NArray"
        end
        if a.ndim > nd
          nd = a.ndim
        end
        a
      end
      if axis < 0
        axis += nd
      end
      if axis < 0 || axis >= nd
        raise ArgumentError,"axis is out of range"
      end
      new_shape = nil
      sum_size = 0
      arrays.each do |a|
        a_shape = a.shape
        if nd != a_shape.size
          a_shape = [1]*(nd-a_shape.size) + a_shape
        end
        sum_size += a_shape.delete_at(axis)
        if new_shape
          if new_shape != a_shape
            raise ShapeError,"shape mismatch"
          end
        else
          new_shape = a_shape
        end
      end
      new_shape.insert(axis,sum_size)
      result = klass.zeros(*new_shape)
      lst = 0
      refs = [true] * nd
      arrays.each do |a|
        fst = lst
        lst = fst + (a.shape[axis-nd]||1)
        refs[axis] = fst...lst
        result[*refs] = a
      end
      result
    end

    def self.vstack(arrays)
      self.concatenate(arrays,axis:0)
    end

    def self.hstack(arrays)
      self.concatenate(arrays,axis:1)
    end

    def self.dstack(arrays)
      self.concatenate(arrays,axis:2)
    end

    # @example
    #   p a = Numo::DFloat[[1, 2], [3, 4]]
    #   # Numo::DFloat#shape=[2,2]
    #   # [[1, 2],
    #   #  [3, 4]]
    #
    #   p b = Numo::DFloat[[5, 6]]
    #   # Numo::DFloat#shape=[1,2]
    #   # [[5, 6]]
    #
    #   p a.concatenate(b,axis:0)
    #   # Numo::DFloat#shape=[3,2]
    #   # [[1, 2],
    #   #  [3, 4],
    #   #  [5, 6]]
    #
    #   p a.concatenate(b.transpose, axis:1)
    #   # Numo::DFloat#shape=[2,3]
    #   # [[1, 2, 5],
    #   #  [3, 4, 6]]

    def concatenate(*arrays,axis:0)
      axis = check_axis(axis)
      self_shape = shape
      self_shape.delete_at(axis)
      sum_size = shape[axis]
      arrays.map! do |a|
        case a
        when NArray
          # ok
        when Numeric
          a = self.class.new(1).store(a)
        when Array
          a = self.class.cast(a)
        else
          raise TypeError,"not Numo::NArray"
        end
        if a.ndim > ndim
          raise ShapeError,"dimension mismatch"
        end
        a_shape = a.shape
        sum_size += a_shape.delete_at(axis-ndim) || 1
        if self_shape != a_shape
          raise ShapeError,"shape mismatch"
        end
        a
      end
      self_shape.insert(axis,sum_size)
      result = self.class.zeros(*self_shape)
      lst = shape[axis]
      refs = [true] * ndim
      refs[axis] = 0...lst
      result[*refs] = self
      arrays.each do |a|
        fst = lst
        lst = fst + (a.shape[axis-ndim] || 1)
        refs[axis] = fst...lst
        result[*refs] = a
      end
      result
    end

    # @example
    #   p x = Numo::DFloat.new(9).seq
    #   # Numo::DFloat#shape=[9]
    #   # [0, 1, 2, 3, 4, 5, 6, 7, 8]
    #
    #   pp x.split(3)
    #   # [Numo::DFloat(view)#shape=[3]
    #   # [0, 1, 2],
    #   #  Numo::DFloat(view)#shape=[3]
    #   # [3, 4, 5],
    #   #  Numo::DFloat(view)#shape=[3]
    #   # [6, 7, 8]]
    #
    #   p x = Numo::DFloat.new(8).seq
    #   # Numo::DFloat#shape=[8]
    #   # [0, 1, 2, 3, 4, 5, 6, 7]
    #
    #   pp x.split([3, 5, 6, 10])
    #   # [Numo::DFloat(view)#shape=[3]
    #   # [0, 1, 2],
    #   #  Numo::DFloat(view)#shape=[2]
    #   # [3, 4],
    #   #  Numo::DFloat(view)#shape=[1]
    #   # [5],
    #   #  Numo::DFloat(view)#shape=[2]
    #   # [6, 7],
    #   #  Numo::DFloat(view)#shape=[0][]]

    def split(indices_or_sections, axis:0)
      axis = check_axis(axis)
      size_axis = shape[axis]
      case indices_or_sections
      when Integer
        div_axis, mod_axis = size_axis.divmod(indices_or_sections)
        if mod_axis != 0
          raise "not equally divide the axis"
        end
        refs = [true]*ndim
        indices_or_sections.times.map do |i|
          refs[axis] = i*div_axis ... (i+1)*div_axis
          self[*refs]
        end
      when NArray
        split(indices_or_sections.to_a,axis:axis)
      when Array
        refs = [true]*ndim
        fst = 0
        (indices_or_sections + [size_axis]).map do |lst|
          lst = size_axis if lst > size_axis
          refs[axis] = (fst < size_axis) ? fst...lst : -1...-1
          fst = lst
          self[*refs]
        end
      else
        raise TypeError,"argument must be Integer or Array"
      end
    end

    # @example
    #   p x = Numo::DFloat.new(4,4).seq
    #   # Numo::DFloat#shape=[4,4]
    #   # [[0, 1, 2, 3],
    #   #  [4, 5, 6, 7],
    #   #  [8, 9, 10, 11],
    #   #  [12, 13, 14, 15]]
    #
    #   pp x.hsplit(2)
    #   # [Numo::DFloat(view)#shape=[4,2]
    #   # [[0, 1],
    #   #  [4, 5],
    #   #  [8, 9],
    #   #  [12, 13]],
    #   #  Numo::DFloat(view)#shape=[4,2]
    #   # [[2, 3],
    #   #  [6, 7],
    #   #  [10, 11],
    #   #  [14, 15]]]
    #
    #   pp x.hsplit([3, 6])
    #   # [Numo::DFloat(view)#shape=[4,3]
    #   # [[0, 1, 2],
    #   #  [4, 5, 6],
    #   #  [8, 9, 10],
    #   #  [12, 13, 14]],
    #   #  Numo::DFloat(view)#shape=[4,1]
    #   # [[3],
    #   #  [7],
    #   #  [11],
    #   #  [15]],
    #   #  Numo::DFloat(view)#shape=[4,0][]]

    def vsplit(indices_or_sections)
      split(indices_or_sections, axis:0)
    end

    def hsplit(indices_or_sections)
      split(indices_or_sections, axis:1)
    end

    def dsplit(indices_or_sections)
      split(indices_or_sections, axis:2)
    end

    # @example
    #   p a = Numo::NArray[0,1,2]
    #   # Numo::Int32#shape=[3]
    #   # [0, 1, 2]
    #
    #   p a.tile(2)
    #   # Numo::Int32#shape=[6]
    #   # [0, 1, 2, 0, 1, 2]
    #
    #   p a.tile(2,2)
    #   # Numo::Int32#shape=[2,6]
    #   # [[0, 1, 2, 0, 1, 2],
    #   #  [0, 1, 2, 0, 1, 2]]
    #
    #   p a.tile(2,1,2)
    #   # Numo::Int32#shape=[2,1,6]
    #   # [[[0, 1, 2, 0, 1, 2]],
    #   #  [[0, 1, 2, 0, 1, 2]]]
    #
    #   p b = Numo::NArray[[1, 2], [3, 4]]
    #   # Numo::Int32#shape=[2,2]
    #   # [[1, 2],
    #   #  [3, 4]]
    #
    #   p b.tile(2)
    #   # Numo::Int32#shape=[2,4]
    #   # [[1, 2, 1, 2],
    #   #  [3, 4, 3, 4]]
    #
    #   p b.tile(2,1)
    #   # Numo::Int32#shape=[4,2]
    #   # [[1, 2],
    #   #  [3, 4],
    #   #  [1, 2],
    #   #  [3, 4]]
    #
    #   p c = Numo::NArray[1,2,3,4]
    #   # Numo::Int32#shape=[4]
    #   # [1, 2, 3, 4]
    #
    #   p c.tile(4,1)
    #   # Numo::Int32#shape=[4,4]
    #   # [[1, 2, 3, 4],
    #   #  [1, 2, 3, 4],
    #   #  [1, 2, 3, 4],
    #   #  [1, 2, 3, 4]]

    def tile(*arg)
      arg.each do |i|
        if !i.kind_of?(Integer) || i<1
          raise ArgumentError,"argument should be positive integer"
        end
      end
      ns = arg.size
      nd = self.ndim
      shp = self.shape
      new_shp = []
      src_shp = []
      res_shp = []
      (nd-ns).times do
        new_shp << 1
        new_shp << (n = shp.shift)
        src_shp << :new
        src_shp << true
        res_shp << n
      end
      (ns-nd).times do
        new_shp << (m = arg.shift)
        new_shp << 1
        src_shp << :new
        src_shp << :new
        res_shp << m
      end
      [nd,ns].min.times do
        new_shp << (m = arg.shift)
        new_shp << (n = shp.shift)
        src_shp << :new
        src_shp << true
        res_shp << n*m
      end
      self.class.new(*new_shp).store(self[*src_shp]).reshape(*res_shp)
    end

    # @example
    #   p Numo::NArray[3].repeat(4)
    #   # Numo::Int32#shape=[4]
    #   # [3, 3, 3, 3]
    #
    #   p x = Numo::NArray[[1,2],[3,4]]
    #   # Numo::Int32#shape=[2,2]
    #   # [[1, 2],
    #   #  [3, 4]]
    #
    #   p x.repeat(2)
    #   # Numo::Int32#shape=[8]
    #   # [1, 1, 2, 2, 3, 3, 4, 4]
    #
    #   p x.repeat(3,axis:1)
    #   # Numo::Int32#shape=[2,6]
    #   # [[1, 1, 1, 2, 2, 2],
    #   #  [3, 3, 3, 4, 4, 4]]
    #
    #   p x.repeat([1,2],axis:0)
    #   # Numo::Int32#shape=[3,2]
    #   # [[1, 2],
    #   #  [3, 4],
    #   #  [3, 4]]

    def repeat(arg,axis:nil)
      case axis
      when Integer
        axis = check_axis(axis)
        c = self
      when NilClass
        c = self.flatten
        axis = 0
      else
        raise ArgumentError,"invalid axis"
      end
      case arg
      when Integer
        if !arg.kind_of?(Integer) || arg<1
          raise ArgumentError,"argument should be positive integer"
        end
        idx = c.shape[axis].times.map{|i| [i]*arg}.flatten
      else
        arg = arg.to_a
        if arg.size != c.shape[axis]
          raise ArgumentError,"repeat size shoud be equal to size along axis"
        end
        arg.each do |i|
          if !i.kind_of?(Integer) || i<0
            raise ArgumentError,"argument should be non-negative integer"
          end
        end
        idx = arg.each_with_index.map{|a,i| [i]*a}.flatten
      end
      ref = [true] * c.ndim
      ref[axis] = idx
      c[*ref].copy
    end


    def check_axis(axis)
      if axis < 0
        axis += ndim
      end
      if axis < 0 || axis >= ndim
        raise ArgumentError,"invalid axis"
      end
      axis
    end

  end
end
