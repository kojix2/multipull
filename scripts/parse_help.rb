str = `git pull -h`

ary = str.split("\n")
         .map { |l| l.strip }
         .filter { |l| l.start_with?('-') }

def has_short_option?(line)
  line.match(/^-[a-z]+/)&.[](0)
end

def has_long_option?(line)
  line.match(/--[a-z\-]+/)&.[](0)
end

def has_required_argument?(line)
  line.match(/<.*>/)&.[](0)
end

def has_argument?(line)
  line.match(/\[.*\]/)&.[](0)
end

ary.each do |l|
  str = 'opt.on('
  opts = []
  opts << has_short_option?(l)
  opts << has_long_option?(l)
  opts << has_required_argument?(l)
  opts << has_argument?(l)
  p opts
end
