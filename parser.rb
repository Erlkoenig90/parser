# Nichtterminal-Symbol
class NonTerminal
	attr_reader :name		# String
	attr_accessor :rules	# Die möglichen Produktionsregeln für dieses Symbol. Array aus Arrays aus Strings oder anderen NonTerminal-Instanzen
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

# Ein geparstes Nichtterminalsymbol
class NTermInst
	attr_accessor :nonTerminal	# Das dazugehörige Nichtterminalsymbol
	attr_accessor :decision		# Index der angewandten Produktionsregel, um auf den geparsten Text zu kommen
	attr_accessor :children		# Instanzen der nach Anwendung der Produktionsregel produzierten Symbole; Array aus Strings und weiteren NTermInst-Instanzen
	def initialize(nt)
		@nonTerminal = nt
		@decision = -1
		@children = []
	end
	# Rekursive textuelle Darstellung (Parser-Baum)
	def to_s(depth = 0)
		ind = "  " * depth
		ind + "[#{nonTerminal}/#{decision}" +
		if(children.size == 0)
			"]\n"
		else
			"\n" + children.map { |c| if(c.is_a?(String)) then ind + "  " + c.inspect + "\n" else c.to_s(depth+1) end }.join("") + ind + "]\n"
		end
	end
	# Rekursiv aus allen Kind-Elementen diejenigen heraussuchen, die Instanzen des Nichtterminalsymbols contNT sind, und die enthaltenen
	# Kind-Elemente vom Typ childclass einsammeln und als Array zurückgeben. childclass kann ein NonTerminal oder eine ruby-Klasse sein.
	# Wird benutzt um rekursive Grammatik-Definitionen (Schleifen) als Array auszulesen
	def collectRecursive(contNT, childclass)
		@children.select { |c|
			(childclass.is_a?(Class) && c.is_a?(childclass)) ||
				(childclass.is_a?(NonTerminal) && c.is_a?(NTermInst) && c.nonTerminal == childclass) } +
			@children.select { |c| c.is_a?(NTermInst) && c.nonTerminal == contNT }.inject([]) { |old,obj| old+obj.collectRecursive(contNT, childclass) }
	end
	# Rekursiv alle eingelesenen Strings ( = Terminalsymbol-Folgen) zu einem String zusammenfügen.
	# Wird benutzt um die textuelle Darstellung dieser Instanz im Quell-Text zu ermitteln
	def collectString
		@children.map { |c| if(c.is_a?(String)) then c else c.collectString end }.join("")
	end
	def [](ind)
		@children[ind]
	end
end

# Repräsentiert einen Zweig im Entscheidungsbaum des NPDA. Wird in einer Warteschlange verwaltet um eine Breitensuche über den Entscheidungsbaum
# durchzuführen
class DNode
	attr_accessor :nonTerminal		# Das Nichtterminalsymbol, zwischen dessen Regeln man sich hier entscheidet
	attr_accessor :index			# Aktuell verfolgte Entscheidung (index für das NonTerminal#rules Array)
	attr_accessor :strIndex			# Index im Eingabetext
	attr_accessor :stack			# Stack zum Zeitpunkt der Entscheidung
	attr_accessor :pnode			# Vorheriger Zweig
	attr_accessor :pindex			# Entscheidung, die beim vorherigen Zweig gemacht wurde, um zu diesem Zweig zu gelangen
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

# Repräsentiert eine Grammatik in ruby-Objekten. Hash vom Namen der Nichtterminalsymbole auf NonTerminal -Instanzen.
class Grammar < Hash
	attr_accessor :start	# Startsymbol (Anfangsinhalt des Stacks)
	def initialize(nn,&block)
		nn.each { |n| self[n] = NonTerminal.new(n) }
		@start = nil
		if(block != nil) then block.call(self) end
	end
	# String mit dieser Grammatik parsen. Gibt nil zurück falls nicht akzeptiert, ansonsten eine DNode-Instanz für den Parser-Baum
	def parse(str)
		queue = []			# Warteschlange aus DNode-Objekten, für die Breitensuche im Entscheidungsbaum
		stack = [start]		# Stack des NPDA
		index = 0			# Position im Eingabestring
		debug "STACK #{stack}\n"
		
		while(!stack.empty? || index != str.length)
			if(!stack.empty? && stack.last.is_a?(String) && (stack.last.length <= str.length-index) && str[index...index+stack.last.length] == stack.last)
				# String Wegakzeptieren
				top = stack.pop
				debug("Akzeptiere String #{top.inspect}\n")
				index += top.length
			elsif(!stack.empty? && stack.last.is_a?(NonTerminal) && stack.last.rules.size == 1)
				# Regel direkt anwenden (keine Entscheidung nötig)
				top = stack.pop
				debug "#{top} : Direkt ersetzen -> #{top.rules[0]}\n"
				stack.concat(top.rules[0].reverse)
			else
				if(!stack.empty? && stack.last.is_a?(NonTerminal))
					# Entscheidung einreihen in Warteschlange
					top = stack.pop
					debug "#{top} : Einreihen\n"
					queue.push(DNode.new(top, -1, stack, index, if(queue.empty?) then nil else queue.first end))
				else
					# Sackgasse - Vergesse stack
				end


				# Nächste Entscheidung in Schlange anwenden
				if(queue.empty? || (queue.first.index == queue.first.nonTerminal.rules.length - 1 && queue.size < 2))
					# Kann im aktuellen Pfad nichts mehr machen, andere Pfade gibt es nicht => Nicht akzeptiert
					return nil
				else
					decide = queue.first
					decide.index = decide.index+1
					# Letzte Entscheidung für dieses DNode-Objekt; nächstes nehmen
					if(decide.index == decide.nonTerminal.rules.length)
						debug("#{queue.first.nonTerminal} : Dead end go to #{queue[1].nonTerminal}/#{queue[1].index+1}")
						queue.delete_at(0)
						decide = queue.first
						decide.index = decide.index+1
						
#						$stdout.write "#{decide.nonTerminal}: Last Decision"
					else
						# Nächste Entscheidung für diesen Zweig
						debug "#{decide.nonTerminal}: Decide #{decide.index}"
					end
					# Stack dieses Zweigs übernehmen
					stack = decide.stack.clone
					debug " ++ #{decide.nonTerminal.rules[decide.index]}\n"
					# Entschieden -> Produktionsregel anwenden (Stack auffüllen)
					stack.concat(decide.nonTerminal.rules[decide.index].reverse)
					# Zur Position dieses Zweigs im String springen
					index = decide.strIndex
				end
			end
			debug "STACK #{stack}\n"
		end
		# Zurückverfolgen, wann welche Entscheidung getroffen wurde, und Array aus den Indicis generieren (rückwärts)
		trace = []
		if(!queue.empty?)
			d = queue.first
			trace << d.index
			while(d.pnode != nil)
				trace << d.pindex
				d = d.pnode
			end
		end
		
		# Parserbaum erzeugen
		root = NTermInst.new(start)
		stack = [root]
		while(!stack.empty?)
			top = stack.pop()
			# Einlesen, welche Entscheidung hier getroffen wurde
			top.decision = if(top.nonTerminal.rules.size>1) then trace.pop() else 0 end
			
			s = top.nonTerminal.rules[top.decision].size
			top.children = Array.new(s)
			
			# Für alle Symbole auf der rechten Seite dieser Produktionsregel...
			(s-1).downto(0) { |i|
				sym = top.nonTerminal.rules[top.decision][i]
				top.children[i] = if(sym.is_a?(String))
					# String ( = Terminalsymbol-Folge) => In Parserbaum einfügen
					sym
				else
					# Nichtterminalsymbol => auf Stack
					x = NTermInst.new(sym)
					stack.push(x)
					x
				end
			}
		end
		
		debug "Akzeptiere\n"
		root # Parserbaum zurückgeben
	end
	# BNF-Darstellung dieser Grammatik zurückgeben
	def to_s
		map { |k,v|
			v.to_s + " ::= " + v.rules.map { |r| r.map{|e| e.inspect}.join(" ") }.join(" | ")
		}.join("\n")
	end
	def debug(str)
#		$stdout.write(str)
	end
	# Gibt die Grammatik für die modifzierte BNF zurück. Diese erlaubt die Eingabe beliebiger Sonderzeichen
	def Grammar.BNF
		@@bnf ||= Grammar.new(["BNF", "Def", "Rules", "Rule", "Symbol", "String", "Chars", "Char", "NTerm", "Name", "Name2", "SpaceE", "Space", "Alpha", "Alnum"]) { |g|
			g["BNF"].rules = [[g["Def"], "\n", g["BNF"]], [g["Def"]], []]
			g["Def"] << [g["SpaceE"], g["NTerm"], g["SpaceE"], "::=", g["Rules"]]
			g["Rules"] << [g["Rule"], "|", g["Rules"]]
			g["Rules"] << [g["Rule"]]
			g["Rule"] << [g["SpaceE"]]
			g["Rule"] << [g["SpaceE"], g["Symbol"], g["Rule"]]

			g["Symbol"].rules = [[g["String"]], [g["NTerm"]]]
			g["String"] << ["\"", g["Chars"], "\""]
			g["Chars"] << []
			g["Chars"] << [g["Char"], g["Chars"]]
			for i in 0..255 do
				g["Char"] << [[i].pack("C").inspect[1..-2]]
			end

			g["NTerm"] << ["<", g["Name"], ">"]
			g["Name"] << [g["Alpha"]]
			g["Name"] << [g["Alpha"], g["Name2"]]
			g["Name2"] << [g["Alnum"], g["Name2"]]
			g["Name2"] << []

			g["SpaceE"] << [g["Space"]]
			g["SpaceE"] << []
			g["Space"] << [" ",  g["SpaceE"]]
			g["Space"] << ["\t", g["SpaceE"]]
			g["Space"] << ["\r", g["SpaceE"]]

			for i in 0..25 do
				a = [[[65 + i].pack("C")], [[97 + i].pack("C")]]
				g["Alpha"].rules.concat(a)
				g["Alnum"].rules.concat(a)
			end
			for i in 0..9 do
				g["Alnum"] << [[48 + i].pack("C")]
			end
			g.start = g["BNF"]
		}
	end
	# Grammatik aus BNF einlesen und als Instanz von 'Grammar' zurückgeben. Verwendet die BNF-Grammatik.
	def Grammar.fromBNF(str)
		b = Grammar.BNF
		Grammar[b.parse(str).collectRecursive(b["BNF"], b["Def"]).map { |df|
#			puts "foobar"
			name = df[1][1].collectString
			nt = NonTerminal.new(name)
			nt.rules = df[4].collectRecursive(b["Rules"], b["Rule"]).map { |rule|
				rule.collectRecursive(b["Rule"], b["Symbol"]).map { |sym|
					if(sym.decision == 0)
						eval(sym[0].collectString)
					else
						b[sym[0][1].collectString]
					end
				}
			}
			[name, nt]
		}]
	end
end

# == Beispiele ==
txtBnf = Grammar.BNF.to_s	# Grammatik für BNF in Textform umwandeln
puts txtBnf
puts "==============================="
g = Grammar.fromBNF(txtBnf)	# Die Grammatik in Textform parsen, Grammar-Objekt erzeugen
puts g.to_s					# Textform des Grammar-Objekts ausgeben. Sollte das selbe ausgeben wie oben


