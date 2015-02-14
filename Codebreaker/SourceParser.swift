//
//  SourceParser.swift
//  Codebreaker
//
//  Created by Tino Heth on 14.02.15.
//  Copyright (c) 2015 Tino Heth. All rights reserved.
//

import Foundation

class BreakpointExtractor {
	class Context {
		let fileURL: NSURL
		var lineNumber = 1
		let handler: (Breakpoint) -> Void
		
		init(fileURL: NSURL, handler: (Breakpoint) -> Void) {
			self.fileURL = fileURL
			self.handler = handler
		}
	}
	
	typealias CharacterHandler = (Character, Context) -> ()
	
	class Scanner {
		func scanChar(input: Character, context: Context) -> Scanner {
			return self
		}
	}
	
	class Skipper: Scanner {
		override func scanChar(input: Character, context: Context) -> BreakpointExtractor.Scanner {
			if input == "#" {
				return StringScanner(string: "if", nextStep: SkippingStringScanner(string: "codebreak", nextStep: ConfigurationScanner(fileURL: context.fileURL)))
			} else {
				return self
			}
		}
	}
	
	class StringScanner: Scanner {
		let string: String
		var index: String.Index
		let nextStep: Scanner
		
		init(string: String, nextStep: Scanner) {
			self.string = string
			self.nextStep = nextStep
			index = string.startIndex
		}
		
		override func scanChar(input: Character, context: Context) -> BreakpointExtractor.Scanner {
			if input == string[index] {
				index++
				if index < string.endIndex {
					return self
				} else {
					return nextStep
				}
			} else {
				return Skipper()
			}
		}
	}
	
	class SkippingStringScanner: StringScanner {
		let skipCharacters: NSCharacterSet
		
		init(string: String, nextStep: Scanner, skipCharacters: NSCharacterSet = NSCharacterSet.whitespaceCharacterSet()) {
			self.skipCharacters = skipCharacters
			super.init(string: string, nextStep: nextStep)
		}
		
		override func scanChar(input: Character, context: Context) -> BreakpointExtractor.Scanner {
			let uni = String(input).utf16
			if skipCharacters.characterIsMember(uni[uni.startIndex]) {
				return self
			} else {
				return super.scanChar(input, context: context)
			}
		}
	}
	
	class ConfigurationScanner: Scanner {
		var quote = false
		var bufferString = ""
		var breakpoint: FileBreakpoint
		private var history: Character = " "
		
		init(breakpoint: FileBreakpoint) {
			self.breakpoint = breakpoint
		}
		
		convenience init(fileURL: NSURL) {
			self.init(breakpoint: FileBreakpoint(path: fileURL.path!, lineNumber: 0))
		}
		
		override func scanChar(input: Character, context: Context) -> BreakpointExtractor.Scanner {
			if quote {
				if input == "\"" && history != "\\" {
					quote = false
				} else {
					bufferString.append(input)
				}
			} else {
				switch (input) {
				case " ":
					break
				case "=":
					// key scanned, look for value...
					break
				default:
					bufferString.append(input)
				}
			}
			history = input
			return self
		}
	}
	
	class ActionScanner: ConfigurationScanner {
		override func scanChar(input: Character, context: Context) -> BreakpointExtractor.Scanner {
			if quote {
				if input == "\"" && history != "\\" {
					quote = false
				} else {
					bufferString.append(input)
				}
			} else if input == "\n" {
				if history != "{" {
					bufferString.append(Character(";"))
				}
			} else if input == "\"" {
				bufferString.append(input)
				quote = true
			} else if input == "#" {
				breakpoint.startingLineNumber = UInt(context.lineNumber)
				breakpoint.actions.append(DebuggerCommandAction(command: bufferString))
				context.handler(breakpoint)
				return Skipper()
			} else {
				bufferString.append(input)
			}
			history = input
			return self
		}
	}
	
	private let handler: (Breakpoint) -> Void
	
	init(handler: (Breakpoint) -> Void) {
		self.handler = handler
	}
	
	func parseFile(url: NSURL) {
		if let input = String(contentsOfURL: url, usedEncoding: nil, error: nil) {
			let context = Context(fileURL: url, handler: handler)
			var scanner: Scanner = Skipper()
			var index = input.startIndex
			while index < input.endIndex {
				let current = input[index]
				if current == "\n" {
					context.lineNumber++
				}
				scanner = scanner.scanChar(current, context: context)
				index++
			}
		}
	}
}

func extractBreakpoints(fromURL url: NSURL) -> [FileBreakpoint] {
	func lookForStart(scanner: NSScanner, path: String, lineNumber: Int) {
		if scanner.scanPastString("#if") {
			if scanner.scanString("codebreak", intoString: nil) {
				let br = FileBreakpoint(path: path, lineNumber: UInt(lineNumber + 1))
				br.ignoreCount = 99
				//result.append(br)
			}
			
			#if codebreak
				println("It works!\nBreak an \(path)")
			#endif
		}
	}
	func lookForEnd() {
	}
	
	var result = [FileBreakpoint]()
	if let path = url.relativePath, lines = String(contentsOfURL: url, usedEncoding: nil, error: nil)?.componentsSeparatedByString("\n") {
		var action = lookForStart
		var lineNumber = 0
		while lineNumber < lines.count {
			let line = lines[lineNumber]
			let scanner = NSScanner(string: line)
			//action(scanner, path, lineNumber)
		}
	}
	return result
}
