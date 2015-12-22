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
		let handler: (FileBreakpoint) -> Void
		
		init(fileURL: NSURL, handler: (FileBreakpoint) -> Void) {
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

	class BasicScanner: Scanner {
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
	}

	class ConfigurationScanner: BasicScanner {
		var key: String?

		override init(breakpoint: FileBreakpoint) {
			super.init(breakpoint: breakpoint)
			bufferString = "codebreak"
		}

		func handleConfiguration(key: String?, value: String) {
			if let key = key {
				#if codebreak=false && enabled=false
				print("\(key) = \(bufferString)")
				#endif
				switch (key) {
				case "codebreak":
					breakpoint.continueAfterRunningActions = (value == "false")
				case "enabled":
					breakpoint.enabled = (value == "true")
				case "ignore":
					breakpoint.ignoreCount = (value as NSString).integerValue
				case "tag":
					breakpoint.tags.append(value)
				default:
					fatalError("Codebreaker: \(key) is not a valid identifier")
					break
				}
			} else if value != "" {
				breakpoint.tags.append(value)
			}
		}

		override func scanChar(input: Character, context: Context) -> BreakpointExtractor.Scanner {
			if quote {
				if input == "\"" && history != "\\" {
					quote = false
				}
				bufferString.append(input)
			} else {
				switch (input) {
				case " ", "&":
					handleConfiguration(key, value: bufferString)
					key = nil
					bufferString = ""
					break
				case "=":
					// key scanned, look for value...
					#if codebreak=false && enabled=false
					print("Key found " + bufferString)
					#endif
					key = bufferString
					bufferString = ""
					break
				case "\n":
					self.handleConfiguration(key, value: bufferString)
					return ActionScanner(breakpoint: breakpoint)
				default:
					bufferString.append(input)
				}
			}
			history = input
			return self
		}
	}
	
	class ActionScanner: BasicScanner {
		override func scanChar(input: Character, context: Context) -> BreakpointExtractor.Scanner {
			if quote {
				if input == "\"" && history != "\\" {
					quote = false
				}
				bufferString.append(input)
			} else if input == "\n" {
				if history != "{" {
					bufferString.append(Character(";"))
				}
			} else if input == "\"" {
				bufferString.append(input)
				quote = true
			} else if input == "#" {
				#if codebreak=false
				print("Found breakpoint in \(context.fileURL) at \(context.lineNumber)")
				#endif
				breakpoint.startingLineNumber = UInt(context.lineNumber)
				breakpoint.actions.append(DebuggerCommandAction(command: "expr " + bufferString.stringByTrimmingCharactersInSet(.whitespaceCharacterSet())))
				context.handler(breakpoint)
				return Skipper()
			} else {
				bufferString.append(input)
			}
			history = input
			return self
		}
	}
	
	private let handler: (FileBreakpoint) -> Void
	
	init(handler: (FileBreakpoint) -> Void) {
		self.handler = handler
	}
	
	func parseFile(url: NSURL) {
		print("Parsing file \(url)")
		if let input = try? String(contentsOfURL: url, usedEncoding: nil) {
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
