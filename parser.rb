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

class NTermInst
	attr_accessor :nonTerminal, :decision, :children
	def initialize(nt)
		@nonTerminal = nt
		@decision = -1
		@children = []
	end
	def to_s(depth = 0)
		ind = "  " * depth
		ind + "[#{nonTerminal}/#{decision}" +
		if(children.size == 0)
			"]\n"
		else
			"\n" + children.map { |c| if(c.is_a?(String)) then ind + "  " + c.inspect + "\n" else c.to_s(depth+1) end }.join("") + ind + "]\n"
		end
	end
end

class DNode
	attr_accessor :nonTerminal, :index, :strIndex, :stack, :pnode, :pindex
	def initialize(n, i, s, si, pn)
		@nonTerminal = n
		@index = i
		@stack = s
		@strIndex = si
		@pnode = pn
		if(pn != nil)
			@pindex = pn.index
		end
	end
end

class Grammar < Hash
	attr_accessor :start
	def initialize(nn)
		nn.each { |n| self[n] = NonTerminal.new(n) }
		@start = nil
	end
	def parse(str)
		queue = []
		stack = [start]
		index = 0
		debug "STACK #{stack}\n"
		
		steps = 0
		while(!stack.empty? || index != str.length)
			steps += 1
			if(!stack.empty? && stack.last.is_a?(String) && (stack.last.length <= str.length-index) && str[index...index+stack.last.length] == stack.last)
				# Wegakzeptieren
				top = stack.pop
				debug("Akzeptiere String #{top.inspect}\n")
				index += top.length
			elsif(!stack.empty? && stack.last.is_a?(NonTerminal) && stack.last.rules.size == 1)
				# Regel direkt anwenden
				top = stack.pop
				debug "#{top} : Direkt ersetzen -> #{top.rules[0]}\n"
				stack.concat(top.rules[0].reverse)
			else
				if(!stack.empty? && stack.last.is_a?(NonTerminal))
					# Entscheidung einreihen
					top = stack.pop
					debug "#{top} : Einreihen\n"
					queue.push(DNode.new(top, -1, stack, index, if(queue.empty?) then nil else queue.first end))
				else
					# Sackgasse - Vergesse stack
				end


				# Nächsten in Schlange
				if(queue.empty? || (queue.first.index == queue.first.nonTerminal.rules.length - 1 && queue.size < 2))
					# Kann im aktuellen Pfad nichts mehr machen, andere Pfade gibt es nicht => Nicht akzeptiert
					return nil
				else
					decide = queue.first
					decide.index = decide.index+1
					if(decide.index == decide.nonTerminal.rules.length)
						debug("#{queue.first.nonTerminal} : Dead end go to #{queue[1].nonTerminal}/#{queue[1].index+1}")
						queue.delete_at(0)
						decide = queue.first
						decide.index = decide.index+1
						
#						$stdout.write "#{decide.nonTerminal}: Last Decision"
					else
						debug "#{decide.nonTerminal}: Decide #{decide.index}"
					end
					stack = decide.stack.clone
					debug " ++ #{decide.nonTerminal.rules[decide.index]}\n"
					stack.concat(decide.nonTerminal.rules[decide.index].reverse)
					index = decide.strIndex
				end
			end
			debug "STACK #{stack}\n"
		end
		trace = []
		if(!queue.empty?)
			d = queue.first
			trace << d.index
			while(d.pnode != nil)
				trace << d.pindex
				d = d.pnode
			end
		end
		
		
		root = NTermInst.new(start)
		stack = [root]
		while(!stack.empty?)
			top = stack.pop()
			top.decision = if(top.nonTerminal.rules.size>1) then trace.pop() else 0 end
			
			s = top.nonTerminal.rules[top.decision].size
			top.children = Array.new(s)
			
			(s-1).downto(0) { |i|
				sym = top.nonTerminal.rules[top.decision][i]
				top.children[i] = if(sym.is_a?(String))
					sym
				else
					x = NTermInst.new(sym)
					stack.push(x)
					x
				end
			}
		end
		
		debug "Akzeptiere mit #{steps} Schritten\n"
		root
	end
	def to_s
		map { |k,v|
			v.rules.map { |r|
				"#{v} => #{r}"
			}.join("\n")
		}.join("\n")
	end
	def debug(str)
#		$stdout.write(str)
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

p g.parse(str)
