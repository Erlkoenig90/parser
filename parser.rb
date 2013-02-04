class NonTerminal
	attr_reader :name
	attr_accessor :rules
	def initialize(n)
		@name = n
		@rules = []
	end
	def <<(r)
		@rules << r
	end
	def to_s
		"<" + @name + ">"
	end
end

class DNode
	attr_accessor :nonTerminal, :index, :strIndex, :stack
	def initialize(n, i, s, si)
		@nonTerminal = n
		@index = i
		@stack = s
		@strIndex = si
	end
end

class Grammar < Hash
	attr_accessor :start
	def initialize(nn)
		nn.each { |n| self[n] = NonTerminal.new(n) }
		@start = nil
	end
	def parse(str)
		track = []
		stack = [start]
		index = 0
		puts "STACK #{stack}"
		
		while(!stack.empty? || index != str.length)
			if(!stack.empty? && stack.last.is_a?(String) && (stack.last.length <= str.length-index) && str[index...index+stack.last.length] == stack.last)
				# Wegakzeptieren
				top = stack.pop
				puts("Akzeptiere String #{top.inspect}")
				index += top.length
				if(top == "();")
					puts "FOOBAR #{index}/#{str.length}   #{stack}"
				end
			elsif(!stack.empty? && stack.last.is_a?(NonTerminal))
				top = stack.pop
				if(top.rules.size == 1)
					puts "#{top} : Direkt ersetzen -> #{top.rules[0]}"
				else
					puts "#{top} : Entscheide #0   -> #{top.rules[0]}"
					# Entscheiden
					track.push(DNode.new(top, 0, stack.clone, index))
				end
				stack.concat(top.rules[0].reverse)
			else
				# Backtrack
				if(track.empty?)
					raise("Not accepted")
				else
					decide = track.last
					decide.index = decide.index+1
					if(decide.index == decide.nonTerminal.rules.length-1)
						stack = decide.stack
						track.pop()
						$stdout.write "#{decide.nonTerminal}: Last Backtrack"
					else
						stack = decide.stack.clone
						$stdout.write "#{decide.nonTerminal}: Backtrack #{decide.index}"
					end
					puts " -> #{decide.nonTerminal.rules[decide.index]}"
					stack.concat(decide.nonTerminal.rules[decide.index].reverse)
					index = decide.strIndex
				end
			end
			puts "STACK #{stack}"
		end
		puts "Akzeptiere"
	end
	def to_s
		map { |k,v|
			v.rules.map { |r|
				"#{v} => #{r}"
			}.join("\n")
		}.join("\n")
	end
end

g = Grammar.new(["Global", "Func", "Type", "Name", "Name2", "SpaceE", "Space", "Alpha", "Alnum"])
g["Global"] << [g["Func"], g["Global"]]
g["Global"] << [g["Space"], g["Global"]]
g["Global"] << []
g["Func"] << [g["Type"], g["Space"], g["Name"], g["SpaceE"], "();"]
g["Type"] << ["int"]
g["Type"] << ["void"]
g["Name"] << [g["Alpha"]]
g["Name"] << [g["Alpha"], g["Name2"]]
g["Name2"] << [g["Alnum"], g["Name2"]]
g["Name2"] << []
g["SpaceE"] << [g["Space"]]
g["SpaceE"] << []
g["Space"] << [" ",  g["SpaceE"]]
g["Space"] << ["\t", g["SpaceE"]]
g["Space"] << ["\n", g["SpaceE"]]
g["Space"] << ["\r", g["SpaceE"]]

for i in 0..25 do
	a = [[[65 + i].pack("C")], [[97 + i].pack("C")]]
	g["Alpha"].rules.concat(a)
	g["Alnum"].rules.concat(a)
end
for i in 0..9 do
	g["Alnum"] << [[48 + i].pack("C")]
end
g.start = g["Global"]

# puts g.to_s

str = "   int deineMutter ();\nvoid yourmom ();  "

g.parse(str)