//
//  main.swift
//  Exterminator
//
//  Created by Tino Heth on 04.01.15.
//  Copyright (c) 2015 Tino Heth. All rights reserved.
//

import Foundation

enum FileExtension: String {
	case Project = "xcodeproj"
	case Workspace = "xcworkspace"
	case Breakpoints = "xcbkptlist"
	case SwiftSource = "swift"
}

func walk(root: NSXMLElement) {
	#if codebreak=false && enabled=false
	print(root.name!)
	#endif
	if let attributes = root.attributes {
		for attribute in attributes {
			if let name = attribute.name {
				#if codebreak=false && enabled=false
				print("\(name) = \(attribute.objectValue!)")
				#endif
			}
		}
	}
	if let children = root.children as? [NSXMLElement] {
		for elem in children {
			walk(elem)
		}
	}
}

func findSourceFiles(inDirectory directory: NSURL, suffixes: Set<String> = Set([FileExtension.SwiftSource.rawValue])) -> [NSURL] {
	func filter(url: NSURL) -> Bool {
		if let pathExtension = url.pathExtension where suffixes.contains(pathExtension) {
			return true
		} else {
			return false
		}
	}
	
	var result = [NSURL]()
	let iter = NSFileManager.defaultManager().enumeratorAtURL(directory, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.SkipsHiddenFiles, errorHandler: nil)
	while let current = iter?.nextObject() as? NSURL {
		if filter(current) {
			result.append(current)
		}
	}
	return result
}

extension NSScanner {
	func scanPastString(string: String) -> Bool {
		self.scanUpToString(string, intoString: nil)
		if self.scanString(string, intoString: nil) {
			return true
		} else {
			return false
		}
	}
}

func extractProjectFile(argument: String) -> (NSURL?, NSURL?) {
	var targetURL: NSURL?
	let baseURL: NSURL?
	if let user = NSProcessInfo.processInfo().environment["USER"] {
		let argURL = NSURL(fileURLWithPath: argument)
		targetURL = argURL.URLByAppendingPathComponent("xcuserdata/\(user).xcuserdatad/xcdebugger/Breakpoints_v2.xcbkptlist")
		baseURL = argURL.URLByDeletingLastPathComponent
	} else {
		baseURL = nil
	}
	return (targetURL, baseURL)
}

func main() {
#if codebreak=false && ignore=0 && enabled=true && MyTag && tag=Mark
	print("Hello!")
#endif

	var ignoreChangeDate = false
	let directory = NSFileManager.defaultManager().currentDirectoryPath
	print("Running in directory \(directory)")
	var targetURL: NSURL?
	var sourceFiles = [NSURL]()
	var baseURL: NSURL? = NSURL(fileURLWithPath: directory, isDirectory: true)
	var isDirectory: ObjCBool = false
	for argument in Process.arguments[1..<Process.arguments.count] {
		if argument.hasPrefix("-") {
			switch (argument) {
			case "-f", "--force":
				ignoreChangeDate = true
			default:
				break
			}
		} else {
			let argURL = NSURL(fileURLWithPath: argument)
			let type = argURL.pathExtension
			if type == FileExtension.SwiftSource.rawValue {
				sourceFiles.append(argURL)
			} else if type == FileExtension.Breakpoints.rawValue {
				targetURL = NSURL(fileURLWithPath: argument)
			} else if type == FileExtension.Workspace.rawValue || type == FileExtension.Project.rawValue {
				(targetURL, baseURL) = extractProjectFile(argument)
			} else if NSFileManager.defaultManager().fileExistsAtPath(argument, isDirectory: &isDirectory) && isDirectory {
				baseURL = NSURL(fileURLWithPath: argument, isDirectory: true)
			}
		}
	}
	if targetURL == nil {
		if let baseURL = baseURL {
			if let contents = try? NSFileManager.defaultManager().contentsOfDirectoryAtURL(baseURL, includingPropertiesForKeys: nil,
				options: NSDirectoryEnumerationOptions.SkipsHiddenFiles) {
				let candidates = contents.filter { current in
					return current.pathExtension == FileExtension.Project.rawValue || current.pathExtension == FileExtension.Workspace.rawValue
				}
				if let candidate = candidates.first where candidates.count == 1 {
					if let argument = candidate.path {
						(targetURL, _) = extractProjectFile(argument)
					}
				}
			}
		}
	}

	var updateNeeded = false
	if let targetURL = targetURL {
		print("Using file \(targetURL)")
		let doc = BreakpointFile(fileURL: targetURL)
		if let baseURL = baseURL where sourceFiles.count == 0 {
			sourceFiles = findSourceFiles(inDirectory: baseURL)
		} else {
			ignoreChangeDate = true
		}
		let extractor = BreakpointExtractor(handler: doc.addFileBreakpoint)
		for file: NSURL in sourceFiles {
			var date: AnyObject?
			if ignoreChangeDate {
				extractor.parseFile(file)
				updateNeeded = true
			} else {
				try! file.getResourceValue(&date, forKey: NSURLAttributeModificationDateKey)
				if date?.timeIntervalSinceDate(doc.lastUpdate) > 0 {
					extractor.parseFile(file)
					updateNeeded = true
				}
			}
		}
		doc.toXMLDocument().XMLDataWithOptions(Int(NSXMLNodePrettyPrint)).writeToURL(targetURL, atomically: true)
		if let components = targetURL.pathComponents where updateNeeded {
			let last = components.count - 5
			if last > 0 {
				let start = NSURL(fileURLWithPath: "/")
				let container = components[0...last].reduce(start) { url, component in
					return url.URLByAppendingPathComponent(component)
				}
				let projectFile = container.URLByAppendingPathComponent("project.pbxproj")
				do {
					try NSFileManager.defaultManager().setAttributes([NSFileModificationDate: NSDate()], ofItemAtPath: projectFile.path!)
				} catch let error as NSError {
					print(error)
				}
			}
		}
	}
}

main()