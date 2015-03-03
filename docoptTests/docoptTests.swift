//
//  DocoptTests.swift
//  docoptTests
//
//  Created by Pavel S. Mazurin on 2/28/15.
//  Copyright (c) 2015 kovpas. All rights reserved.
//

import Cocoa
import XCTest

class DocoptTests: XCTestCase {
    
    func testTestCasesFileExists() {
        let fileManager: NSFileManager = NSFileManager.defaultManager()
        let filePath: String? = fixturesFilePath()
        XCTAssertNotNil(filePath, "Fixtures file testcases.docopt does not exist in testing bundle")
        if let filePath = filePath {
            let exists: Bool = fileManager.fileExistsAtPath(filePath)
            XCTAssertTrue(exists, "Fixtures file testcases.docopt does not exist in testing bundle")
        }
    }
    
    func testFixturesFileCanBeOpened() {
        XCTAssertNotNil(fixturesFileContents(), "Could not read fixtures file")
    }
    
//    func testTestCases() {
//        var rawTestCases = fixturesFileContents();
//        var parser: DocoptTestCaseParser = DocoptTestCaseParser(stringOfTestCases: rawTestCases!)
//        
//        for testCase in parser.testCases {
//            let docopt: Docopt = Docopt(doc: testCase.usage, argv: testCase.arguments)
//            let result: AnyObject = docopt.result
//            let expectedOutput: AnyObject = testCase.expectedOutput
//            switch expectedOutput {
//            case let expectedOutput as NSDictionary:
//                if let result = result as? NSDictionary {
//                    XCTAssertTrue(result == expectedOutput, "Test \(testCase.name) failed");
//                } else {
////                    XCTFail("Test \(testCase.name) failed. Unexpected result type: \(result.dynamicType). Expected: \(expectedOutput.dynamicType)")
//                }
//                
//            case let expectedOutput as String:
//                if let result = result as? String {
//                    XCTAssertTrue(result == expectedOutput, "Test \(testCase.name) failed");
//                } else {
//                    XCTFail("Test \(testCase.name) failed. Unexpected result type: \(result.dynamicType). Expected: \(expectedOutput.dynamicType)")
//                }
//            default:
//                XCTFail("Test \(testCase.name) failed. Unexpected result type: \(result.dynamicType). Expected: \(expectedOutput.dynamicType)")
//            }
//        }
//    }
    
    func testPatternFlat() {
        XCTAssertEqual(Required([OneOrMore(Argument("N")), Option("-a"), Argument("M")]).flat(), [Argument("N"), Option("-a"), Argument("M")])
        XCTAssertEqual(Required([Optional(OptionsShortcut()), Optional(Option("-a"))]).flat(OptionsShortcut), [OptionsShortcut()])
    }

    func testParseDefaults() {
        let section = "options:\n\t-a        Add\n\t-r        Remote\n\t-m <msg>  Message"
        let options = Docopt.parseDefaults(section)
        var expected = Array<Option>()
        expected += [Option("-a")]
        expected += [Option("-r")]
        expected += [Option("-m", argCount: 1)]
        XCTAssertEqual(options, expected)
    }
    
    func testParseSection() {
        let usage = "usage: this\nusage:hai\nusage: this that\nusage: foo\n       bar\nPROGRAM USAGE:\n foo\n bar\nusage:\n\ttoo\n\ttar\nUsage: eggs spam\nBAZZ\nusage: pit stop"
        XCTAssertEqual(Docopt.parseSection("usage:", source: "foo bar fizz buzz"), [])
        XCTAssertEqual(Docopt.parseSection("usage:", source: "usage: prog"), ["usage: prog"])
        XCTAssertEqual(Docopt.parseSection("usage:", source: "usage: -x\n -y"), ["usage: -x\n -y"])
        XCTAssertEqual(Docopt.parseSection("usage:", source: usage), [
            "usage: this",
            "usage:hai",
            "usage: this that",
            "usage: foo\n       bar",
            "PROGRAM USAGE:\n foo\n bar",
            "usage:\n\ttoo\n\ttar",
            "Usage: eggs spam",
            "usage: pit stop",
            ])
    }
    
    func testFormalUsage() {
        let doc = "\nUsage: prog [-hv] ARG\n        prog N M\n\n        prog is a program."
        let usage = Docopt.parseSection("usage:", source: doc)[0]
        let formalUsage = Docopt.formalUsage(usage)
        
        XCTAssertEqual(usage, "Usage: prog [-hv] ARG\n        prog N M")
        XCTAssertEqual(formalUsage, "( [-hv] ARG ) | ( N M )")
    }
    
    func testParseArgv() {
        var o = [Option("-h"), Option("-v", long: "--verbose"), Option("-f", long:"--file", argCount: 1)]
        var TS = {(s: String) in return Tokens(s, error: DocoptExit()) }
        
        XCTAssertEqual(Docopt.parseArgv(TS(""), options: o), [])
        XCTAssertEqual(Docopt.parseArgv(TS("-h"), options: o), [Option("-h", value: true)])
        XCTAssertEqual(Docopt.parseArgv(TS("-h --verbose"), options:o),
            [Option("-h", value: true), Option("-v", long: "--verbose", value: true)])
        XCTAssertEqual(Docopt.parseArgv(TS("-h --file f.txt"), options:o),
            [Option("-h", value: true), Option("-f", long: "--file", argCount: 1, value: "f.txt")])
        XCTAssertEqual(Docopt.parseArgv(TS("-h --file f.txt arg"), options:o),
            [Option("-h", value: true),
                Option("-f", long: "--file", argCount: 1, value: "f.txt"),
                Argument(nil, value: "arg")])
        XCTAssertEqual(Docopt.parseArgv(TS("-h --file f.txt arg arg2"), options:o),
            [Option("-h", value: true),
                Option("-f", long: "--file", argCount: 1, value: "f.txt"),
                Argument(nil, value: "arg"),
                Argument(nil, value: "arg2")])
        XCTAssertEqual(Docopt.parseArgv(TS("-h arg -- -v"), options:o),
            [Option("-h", value: true),
                Argument(nil, value: "arg"),
                Argument(nil, value: "--"),
                Argument(nil, value: "-v")])
    }
    
    func testOptionParse() {
        XCTAssertEqual(Option.parse("-h"), Option("-h"))
        XCTAssertEqual(Option.parse("--help"), Option(long: "--help"))
        XCTAssertEqual(Option.parse("-h --help"), Option("-h", long: "--help"))
        XCTAssertEqual(Option.parse("-h, --help"), Option("-h", long: "--help"))

        XCTAssertEqual(Option.parse("-h TOPIC"), Option("-h", argCount: 1))
        XCTAssertEqual(Option.parse("--help TOPIC"), Option(long: "--help", argCount: 1))
        XCTAssertEqual(Option.parse("-h TOPIC --help TOPIC"), Option("-h", long: "--help", argCount: 1))
        XCTAssertEqual(Option.parse("-h TOPIC, --help TOPIC"), Option("-h", long: "--help", argCount: 1))
        XCTAssertEqual(Option.parse("-h TOPIC, --help=TOPIC"), Option("-h", long: "--help", argCount: 1))

        XCTAssertEqual(Option.parse("-h  Description..."), Option("-h"))
        XCTAssertEqual(Option.parse("-h --help  Description..."), Option("-h", long: "--help"))
        XCTAssertEqual(Option.parse("-h TOPIC  Description..."), Option("-h", argCount: 1))

        XCTAssertEqual(Option.parse("    -h"), Option("-h"))

        XCTAssertEqual(Option.parse("-h TOPIC  Descripton... [default: 2]"),
            Option("-h", argCount: 1, value: "2"))
        XCTAssertEqual(Option.parse("-h TOPIC  Descripton... [default: topic-1]"),
            Option("-h", argCount: 1, value: "topic-1"))
        XCTAssertEqual(Option.parse("--help=TOPIC  ... [default: 3.14]"),
            Option(long: "--help", argCount: 1, value: "3.14"))
        XCTAssertEqual(Option.parse("-h, --help=DIR  ... [default: ./]"),
            Option("-h", long: "--help", argCount: 1, value: "./"))
        XCTAssertEqual(Option.parse("-h TOPIC  Descripton... [dEfAuLt: 2]"),
            Option("-h", argCount: 1, value: "2"))
    }
    
    func testOptionName() {
        XCTAssertEqual(Option("-h").name!, "-h")
        XCTAssertEqual(Option("-h", long: "--help").name!, "--help")
        XCTAssertEqual(Option(long: "--help").name!, "--help")
    }
    
    func testParsePattern() {
        var o = [Option("-h"), Option("-v", long: "--verbose"), Option("-f", long:"--file", argCount: 1)]
        XCTAssertEqual(Docopt.parsePattern("[ -h ]", options: o), Required(Optional(Option("-h"))))
        XCTAssertEqual(Docopt.parsePattern("[ ARG ... ]", options: o), Required(Optional(OneOrMore(Argument("ARG")))))
        XCTAssertEqual(Docopt.parsePattern("[ -h | -v ]", options: o), Required(Optional(Either([Option("-h"), Option("-v", long: "--verbose")]))))
        XCTAssertEqual(Docopt.parsePattern("( -h | -v [ --file <f> ] )", options: o),
            Required(Required(
                Either([Option("-h"),
                    Required([Option("-v", long: "--verbose"),
                        Optional(Option("-f", long: "--file", argCount: 1))])]))))
        XCTAssertEqual(Docopt.parsePattern("(-h|-v[--file=<f>]N...)", options: o),
            Required(Required(Either([Option("-h"),
                Required([Option("-v", long: "--verbose"),
                    Optional(Option("-f", long: "--file", argCount: 1)),
                    OneOrMore(Argument("N"))])]))))
        XCTAssertEqual(Docopt.parsePattern("(N [M | (K | L)] | O P)", options: []),
            Required(Required(Either([
                Required([Argument("N"),
                    Optional(Either([Argument("M"),
                        Required(Either([Argument("K"),
                            Argument("L")]))]))]),
                Required([Argument("O"), Argument("P")])]))))
        XCTAssertEqual(Docopt.parsePattern("[ -h ] [N]", options: o),
            Required([Optional(Option("-h")),
                Optional(Argument("N"))]))
        XCTAssertEqual(Docopt.parsePattern("[options]", options: o),
            Required(Optional(OptionsShortcut())))
        XCTAssertEqual(Docopt.parsePattern("[options] A", options: o),
            Required([Optional(OptionsShortcut()),
                Argument("A")]))
        XCTAssertEqual(Docopt.parsePattern("-v [options]", options: o),
            Required([Option("-v", long: "--verbose"),
                Optional(OptionsShortcut())]))
        XCTAssertEqual(Docopt.parsePattern("ADD", options: o), Required(Argument("ADD")))
        XCTAssertEqual(Docopt.parsePattern("<add>", options: o), Required(Argument("<add>")))
        XCTAssertEqual(Docopt.parsePattern("add", options: o), Required(Command("add")))
    }
    
    func testOptionMatch() {
        XCTAssertTrue(Option("-a").match([Option("-a", value: true)]) ==
            (true, [], [Option("-a", value: true)]))
        XCTAssertTrue(Option("-a").match([Option("-x")]) ==
            (false, [Option("-x")], []))
        XCTAssertTrue(Option("-a").match([Argument("N")]) ==
            (false, [Argument("N")], []))
        XCTAssertTrue(Option("-a").match([Option("-x"), Option("-a"), Argument("N")]) ==
            (true, [Option("-x"), Argument("N")], [Option("-a")]))
        XCTAssertTrue(Option("-a").match([Option("-a", value: true), Option("-a")]) ==
            (true, [Option("-a")], [Option("-a", value: true)]))
    }
    
    func testArgumentMatch() {
        XCTAssertTrue(Argument("N").match(Argument(nil, value: 9)) ==
            (true, [], [Argument("N", value: 9)]))
        XCTAssertTrue(Argument("N").match(Option("-x")) ==
            (false, [Option("-x")], []))
        XCTAssertTrue(Argument("N").match([Option("-x"), Option("-a"), Argument(nil, value: 5)]) ==
            (true, [Option("-x"), Option("-a")], [Argument("N", value: 5)]))
        XCTAssertTrue(Argument("N").match([Argument(nil, value: 9), Argument(nil, value: 0)]) ==
            (true, [Argument(nil, value: 0)], [Argument("N", value: 9)]))
    }
    
    func testCommandMatch() {
        XCTAssertTrue(Command("c").match(Argument(nil, value: "c")) ==
            (true, [], [Command("c", value: true)]))
        XCTAssertTrue(Command("c").match(Option("-x")) ==
            (false, [Option("-x")], []))
        XCTAssertTrue(Command("c").match([Option("-x"), Option("-a"), Argument(nil, value: "c")]) ==
            (true, [Option("-x"), Option("-a")], [Command("c", value: true)]))
        XCTAssertTrue(Either([Command("add"), Command("rm")]).match(Argument(nil, value: "rm")) ==
            (true, [], [Command("rm", value: true)]))
    }
    
    func testOptionalMatch() {
        XCTAssertTrue(Optional(Option("-a")).match([Option("-a")]) ==
            (true, [], [Option("-a")]));
        XCTAssertTrue(Optional(Option("-a")).match([]) == (true, [], []));
        XCTAssertTrue(Optional(Option("-a")).match([Option("-x")]) ==
            (true, [Option("-x")], []));
        XCTAssertTrue(Optional([Option("-a"), Option("-b")]).match([Option("-a")]) ==
            (true, [], [Option("-a")]));
        XCTAssertTrue(Optional([Option("-a"), Option("-b")]).match([Option("-b")]) ==
            (true, [], [Option("-b")]));
        XCTAssertTrue(Optional([Option("-a"), Option("-b")]).match([Option("-x")]) ==
            (true, [Option("-x")], []));
        XCTAssertTrue(Optional(Argument("N")).match([Argument(nil, value: 9)]) ==
            (true, [], [Argument("N", value: 9)]));
        XCTAssertTrue(Optional([Option("-a"), Option("-b")]).match(
            [Option("-b"), Option("-x"), Option("-a")]) ==
            (true, [Option("-x")], [Option("-a"), Option("-b")]));
    }
    
    func testRequiredMatch() {
        XCTAssertTrue(Required(Option("-a")).match([Option("-a")]) ==
            (true, [], [Option("-a")]));
        XCTAssertTrue(Required(Option("-a")).match([]) == (false, [], []));
        XCTAssertTrue(Required(Option("-a")).match([Option("-x")]) ==
            (false, [Option("-x")], []));
        XCTAssertTrue(Required([Option("-a"), Option("-b")]).match([Option("-a")]) ==
            (false, [Option("-a")], []));
    }
    
    func testEitherMatch() {
        XCTAssertTrue(Either([Option("-a"), Option("-b")]).match(
            [Option("-a")]) == (true, [], [Option("-a")]));
        XCTAssertTrue(Either([Option("-a"), Option("-b")]).match(
            [Option("-a"), Option("-b")]) ==
            (true, [Option("-b")], [Option("-a")]));
        XCTAssertTrue(Either([Option("-a"), Option("-b")]).match(
            [Option("-x")]) == (false, [Option("-x")], []));
        XCTAssertTrue(Either([Option("-a"), Option("-b"), Option("-c")]).match(
            [Option("-x"), Option("-b")]) ==
            (true, [Option("-x")], [Option("-b")]));
        XCTAssertTrue(Either([Argument("M"),
            Required([Argument("N"), Argument("M")])]).match(
                [Argument(nil, value: 1), Argument(nil, value: 2)]) ==
            (true, [], [Argument("N", value: 1), Argument("M", value: 2)]));
    }
    
    func testOneOrMoreMatch() {
        XCTAssertTrue(OneOrMore(Argument("N")).match([Argument(nil, value: 9)]) ==
            (true, [], [Argument("N", value: 9)]));
        XCTAssertTrue(OneOrMore(Argument("N")).match([]) == (false, [], []));
        XCTAssertTrue(OneOrMore(Argument("N")).match([Option("-x")]) ==
            (false, [Option("-x")], []));
        XCTAssertTrue(OneOrMore(Argument("N")).match(
            [Argument(nil, value: 9), Argument(nil, value: 8)]) == (
                true, [], [Argument("N", value: 9), Argument("N", value: 8)]));
        XCTAssertTrue(OneOrMore(Argument("N")).match(
            [Argument(nil, value: 9), Option("-x"), Argument(nil, value: 8)]) == (
                true, [Option("-x")], [Argument("N", value: 9), Argument("N", value: 8)]));
        XCTAssertTrue(OneOrMore(Option("-a")).match(
            [Option("-a"), Argument(nil, value: 8), Option("-a")]) ==
            (true, [Argument(nil, value: 8)], [Option("-a"), Option("-a")]));
        XCTAssertTrue(OneOrMore(Option("-a")).match([Argument(nil, value: 8),
            Option("-x")]) ==
            (false, [Argument(nil, value: 8), Option("-x")], []));
        XCTAssertTrue(OneOrMore(Required([Option("-a"), Argument("N")])).match(
            [Option("-a"), Argument(nil, value: 1), Option("-x"),
                Option("-a"), Argument(nil, value: 2)]) ==
            (true, [Option("-x")],
                [Option("-a"), Argument("N", value: 1), Option("-a"), Argument("N", value: 2)]));
        XCTAssertTrue(OneOrMore(Optional(Argument("N"))).match([Argument(nil, value: 9)]) ==
            (true, [], [Argument("N", value: 9)]));
    }
    
    func testPatternEither() {
        XCTAssertEqual(Pattern.transform(Option("-a")), Either(Required(Option("-a"))));
        XCTAssertEqual(Pattern.transform(Argument("A")), Either(Required(Argument("A"))));
        XCTAssertEqual(Pattern.transform(Required([Either([Option("-a"), Option("-b")]),
            Option("-c")])),
            Either([Required([Option("-a"), Option("-c")]),
                Required([Option("-b"), Option("-c")])]));
        XCTAssertEqual(Pattern.transform(Optional([Option("-a"), Either([Option("-b"),
            Option("-c")])])),
            Either([Required([Option("-b"), Option("-a")]),
                Required([Option("-c"), Option("-a")])]));
        XCTAssertEqual(Pattern.transform(Either([Option("-x"),
            Either([Option("-y"), Option("-z")])])),
            Either([Required(Option("-x")),
                Required(Option("-y")),
                Required(Option("-z"))]));
        XCTAssertEqual(Pattern.transform(OneOrMore([Argument("N"), Argument("M")])),
            Either(Required([Argument("N"), Argument("M"),
                Argument("N"), Argument("M")])));
    }
    
    func testFixRepeatingArguments() {
        XCTAssertEqual(Option("-a").fixRepeatingArguments(), Option("-a"));
        XCTAssertEqual(Argument("N").fixRepeatingArguments(), Argument("N"));
        XCTAssertEqual(Required([Argument("N"),
            Argument("N")]).fixRepeatingArguments(),
            Required([Argument("N", value: []), Argument("N", value: [])]));
        XCTAssertEqual(Either([Argument("N"),
            OneOrMore(Argument("N"))]).fix(),
            Either([Argument("N", value: []), OneOrMore(Argument("N", value: []))]));
    }
    
    func testListArgumentMatch() {
        XCTAssertTrue(Required([Argument("N"), Argument("N")]).fix().match(
            [Argument(nil, value: "1"), Argument(nil, value: "2")]) ==
            (true, [], [Argument("N", value: ["1", "2"])]));
        XCTAssertTrue(OneOrMore(Argument("N")).fix().match(
            [Argument(nil, value: "1"), Argument(nil, value: "2"), Argument(nil, value: "3")]) ==
            (true, [], [Argument("N", value: ["1", "2", "3"])]));
        XCTAssertTrue(Required([Argument("N"), OneOrMore(Argument("N"))]).fix().match(
            [Argument(nil, value: "1"), Argument(nil, value: "2"), Argument(nil, value: "3")]) ==
            (true, [], [Argument("N", value: ["1", "2", "3"])]));
        XCTAssertTrue(Required([Argument("N"), Required(Argument("N"))]).fix().match(
            [Argument(nil, value: "1"), Argument(nil, value: "2")]) ==
            (true, [], [Argument("N", value: ["1", "2"])]));
    }
    
    func testBasicPatternMatch() {
        // ( -a N [ -x Z ] )
        let pattern = Required([Option("-a"), Argument("N"), Optional([Option("-x"), Argument("Z")])])
        
        // -a N
        XCTAssertTrue(pattern.match([Option("-a"), Argument(nil, value: 9)]) ==
            (true, [], [Option("-a"), Argument("N", value: 9)]))
        // -a -x N Z
        XCTAssertTrue(pattern.match([Option("-a"), Option("-x"), Argument(nil, value: 9), Argument(nil, value: 5)]) ==
            (true, [], [Option("-a"), Argument("N", value: 9), Option("-x"), Argument("Z", value: 5)]))
        // -x N Z  # BZZ!
        XCTAssertTrue(pattern.match([Option("-x"), Argument(nil, value: 9), Argument(nil, value: 5)]) ==
            (false, [Option("-x"), Argument(nil, value: 9), Argument(nil, value: 5)], []))
    }
    
    func testSet() {
        XCTAssertEqual(Argument("N"), Argument("N"))
        XCTAssertEqual(Set([Argument("N"), Argument("N")]), Set([Argument("N")]))
    }
    
//    func testDocopt() {
//        let doc = "Usage: prog [-v] A\n\n           Options: -v  Be verbose."
//        let result: Dictionary<String, DocoptValue> = Docopt(doc, argv: ["arg"]).result as! DocoptResult
//        XCTAssertTrue(result.description == ["-v": false, "A": "arg"].description)
//    }
    
    private func fixturesFilePath() -> String? {
        let testBundle: NSBundle = NSBundle(forClass: self.dynamicType)
        return testBundle.pathForResource("testcases", ofType: "docopt")
    }
    
    private func fixturesFileContents() -> String? {
        if let filePath = self.fixturesFilePath() {
            let fileContents = String(contentsOfFile: filePath, encoding: NSUTF8StringEncoding, error: nil)
            return fileContents
        }
        return nil;
    }
}

internal func ==<K: Hashable, V: DocoptValue>(lhs: [K: V], rhs: [K: V]) -> Bool {
    if lhs.count != rhs.count { return false }
    
    for (key, lhsub) in lhs {
        if let rhsub = rhs[key] {
            if lhsub != rhsub {
                return false
            }
        } else {
            return false
        }
    }
    
    return true
}