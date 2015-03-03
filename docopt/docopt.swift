//
//  docopt.swift
//  docopt
//
//  Created by Pavel S. Mazurin on 2/28/15.
//  Copyright (c) 2015 kovpas. All rights reserved.
//

import Foundation

class DocoptValue: Equatable { }
typealias DocoptResult = Dictionary<String, DocoptValue>

public struct Docopt {
    public var result: AnyObject!
    public let doc: String

    private let arguments: Array<String>
    
    public init(_ doc: String, argv: Array<String> = [""], help: Bool = false, optionsFirst: Bool = false) {
        self.doc = doc
        arguments = argv
        result = parse(optionsFirst)
    }
    
    private func parse(optionsFirst: Bool) -> AnyObject {
        let usageSections = Docopt.parseSection("usage:", source: doc)
//        if count(usageSections) == 0 {
//            return "user-error"
//        } else if count(usageSections) > 1 {
//            return "user-error"
//        }
        
        var options = Docopt.parseDefaults(doc)
        let pattern = Docopt.parsePattern(Docopt.formalUsage(usageSections[0]), options: options)
        let argv = Docopt.parseArgv(Tokens(arguments), options: options, optionsFirst: optionsFirst)
        let patternOptions = Set(pattern.flat(Option))
        
        for optionsShortcut in pattern.flat(OptionsShortcut) {
            let docOptions = Set(Docopt.parseDefaults(doc))
            optionsShortcut.children = Array(docOptions.subtract(patternOptions))
        }

//        extras(help, version, argv, doc)
        
        let (matched, left, collected) = pattern.fix().match(argv)
        
        if matched && left.isEmpty {
            return "user-error" //(pattern.flat() as! [Pattern] + collected)
        }

        return "user-error"
    }
    
    static internal func parseSection(name: String, source: String) -> Array<String> {
      return source.findAll("^([^\n]*\(name)[^\n]*\n?(?:[ \t].*?(?:\n|$))*)", flags: .CaseInsensitive | .AnchorsMatchLines )
    }
    
    static internal func parseDefaults(doc: String) -> Array<Option> {
        var defaults = Array<Option>()
        let optionsSection = parseSection("options:", source: doc)
        for s in optionsSection {
            // FIXME corner case "bla: options: --foo"
            let (_, _, s) = s.partition(":")  // get rid of "options:"
            var split = ("\n" + s).splitByRegex("\n[ \t]*(-\\S+?)")
            var u = Array<String>()
            for var i = 1; i < count(split); i += 2 {
                u.append(split[i - 1].strip() + split[i])
            }
            split = u
            defaults += split.filter({$0.hasPrefix("-")}).map {
                Option.parse($0)
            }
        }
        return defaults
    }
    
    static internal func parseLong(tokens: Tokens, var options: [Option]) -> Array<Option> {
        var (long, eq, val) = tokens.move()!.partition("=")
        assert(long.hasPrefix("--"))
        var value: String?
        if eq == "" && val == "" {
            value = nil
        } else {
            value = val
        }
        var similar = options.filter {$0.long == long}
        
        if tokens.error is DocoptExit && similar == [] {  // if no exact match
            similar = options.filter {($0.long as String! == long) ?? false}
        }

        var o: Option? = nil
        if count(similar) > 1 {
            //exception
            println("!!!!!")
            return []
        } else if count(similar) < 1 {
            let argCount: UInt = (eq == "=") ? 1 : 0
            o = Option(nil, long: long, argCount: argCount, value: nil)
            options.append(o!)
            if tokens.error is DocoptExit {
                o = Option(nil, long: long, argCount: argCount, value: argCount > 0 ? value : true)
            }
        } else {
            o = Option(similar[0])
            if o!.argCount == 0 {
                if value != nil {
//                    raise tokens.error('%s must not have an argument' % o.long)
                }
            } else {
                if value == nil {
                    if let current = tokens.current() where current != "--" {
                        value = tokens.move()
                    } else {
//                        raise tokens.error('%s requires argument' % o.long)
                    }
                }
            }
            if tokens.error is DocoptExit {
                o!.value = value ?? true
            }
        }
        return [o!]
    }
    
    static internal func parseShorts(tokens: Tokens, var options: [Option]) -> [Option] {
        let token = tokens.move()!
        assert(token.hasPrefix("-") && !token.hasPrefix("--"))
        var left = token.stringByReplacingOccurrencesOfString("-", withString: "", options: .AnchoredSearch, range: nil)
        var parsed = [Option]()
        while left != "" {
            let short = "-" + left.substringToIndex(advance(left.startIndex, 1))
            left = left.substringFromIndex(advance(left.startIndex, 1))
            let similar = options.filter {$0.short == short}
            var o: Option? = nil
            if count(similar) > 1 {
                //exception
                println("!!!!!")
            } else if count(similar) < 1 {
                o = Option(short)
                options.append(o!)
                if tokens.error is DocoptExit {
                    o = Option(short, value: true)
                }
            } else {
                o = Option(short, long: similar[0].long, argCount: similar[0].argCount, value: similar[0].value)
                var value: String? = nil
                if o!.argCount != 0 {
                    if left == "" {
                        if let current = tokens.current() where current != "--" {
                            value = tokens.move()
                        } else {
//                            exception 
                            println("!!!!!")
                        }
                    } else {
                        value = left
                        left = ""
                    }
                }
                if tokens.error is DocoptExit {
                    o!.value = value ?? true
                }
            }
            if let o = o {
                parsed.append(o)
            }
        }
        return parsed
    }
    
    static internal func parseAtom(tokens: Tokens, var options: [Option]) -> [Pattern] {
        var token = tokens.current()!
        var result = [Pattern]()
        if contains(["(", "["], token) {
            tokens.move()
            var matching: String? = nil
            var u = parseExpr(tokens, options: options)
            switch token {
            case "(":
                matching = ")"
                result = [Required(u)]
                break;
            case "[" :
                matching = "]"
                result = [Optional(u)]
                break;
            default:
                // Exception
                break;
            }
            
            if tokens.move() != matching {
                // Exception
            }
            
            return result
        }
        
        if token == "options" {
            tokens.move()
            return [OptionsShortcut()]
        }
        
        if token.hasPrefix("--") && token != "--" {
            return parseLong(tokens, options: options)
        }
        if token.hasPrefix("-") && !(token == "--" || token == "-") {
            return parseShorts(tokens, options: options)
        }
        if (token.hasPrefix("<") && token.hasSuffix(">")) || (token.uppercaseString == token) {
            return [Argument(tokens.move()!)]
        }
        
        return [Command(tokens.move()!)]
    }

    static internal func parseSeq(tokens: Tokens, options: [Option]) -> [Pattern] {
        var result = [Pattern]()
        while true {
            var current = tokens.current()
            if let current = current where !contains(["]", ")", "|"], current) {
                var atom = parseAtom(tokens, options: options)
                if tokens.current() == "..." {
                    atom = [OneOrMore(atom)]
                    tokens.move()
                }
                result += atom
                continue
            }
            break
        }

        return result
    }
    
    static internal func parseExpr(tokens: Tokens, var options: [Option]) -> [Pattern] {
        var seq = parseSeq(tokens, options: options)
        if tokens.current() != "|" {
            return seq
        }
        var result = seq
        if count(seq) > 1 {
            result = [Required(seq)]
        }
        while tokens.current() == "|" {
            tokens.move()
            seq = parseSeq(tokens, options: options)
            if count(seq) > 1 {
                result += [Required(seq)]
            } else {
                result += seq
            }
        }
        
        if count(result) > 1 {
            return [Either(result)]
        }
        return result
    }

    static internal func parseArgv(tokens: Tokens, var options: [Option], optionsFirst: Bool = false) -> [LeafPattern] {
        var parsed = Array<LeafPattern>()
        while let current = tokens.current() {
            if tokens.current() == "--" {
                while let token = tokens.move() {
                    parsed.append(Argument(nil, value: token))
                }
                return parsed
            }
            else if current.hasPrefix("--") {
//                parsed += parseLong(tokens, options: options)
                for arg in parseLong(tokens, options: options) {
                    parsed.append(arg)
                }
            } else if current.hasPrefix("-") && current != "-" {
//                parsed += parseShorts(tokens, options: options)
                for arg in parseShorts(tokens, options: options) {
                    parsed.append(arg)
                }
            } else if optionsFirst {
                while let token = tokens.move() {
                    parsed.append(Argument(nil, value: token))
                }
                return parsed
            } else {
                parsed.append(Argument(nil, value: tokens.move()))
            }
        }
        return parsed
    }
    
    static internal func parsePattern(source: String, var options: [Option]) -> Pattern {
        let tokens = Tokens.fromPattern(source)
        let result: Array<Pattern> = parseExpr(tokens, options: options)
        
//        if (tokens.current() != null) {
//            throw tokens.error("unexpected ending: %s", join(" ", tokens));
//        }
        
        return Required(result)
    }
    
    static internal func formalUsage(section: String) -> String {
        let (_, _, s) = section.partition(":") // drop "usage:"
        var pu = s.split()
        let u = pu[0]
        pu.removeAtIndex(0)
        var result = "( "
        if !pu.isEmpty {
            for str in pu {
                if str == u {
                    result += ") | ("
                } else {
                    result += str
                }
                result += " "
            }
            result = (result as NSString).substringToIndex(count(result) - 1)
        }
        
        result += " )"
        return result
    }
}

func ==(lhs: DocoptValue, rhs: DocoptValue) -> Bool {
    return lhs == rhs
}