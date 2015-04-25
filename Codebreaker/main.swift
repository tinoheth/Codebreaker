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
	println(root.name!)
	if let attributes = root.attributes as? [NSXMLNode] {
		for attribute in attributes {
			if let name = attribute.name {
				println("\(name) = \(attribute.objectValue!)")
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
	var baseURL: NSURL?
	if let user = NSProcessInfo.processInfo().environment["USER"] as? String {
		targetURL = NSURL(fileURLWithPath: argument.stringByAppendingPathComponent("xcuserdata/\(user).xcuserdatad/xcdebugger/Breakpoints_v2.xcbkptlist"))
		baseURL = NSURL(fileURLWithPath: argument.stringByDeletingLastPathComponent, isDirectory: true)
	}
	return (targetURL, baseURL)
}

func main() {
	var ignoreChangeDate = false
	let directory = NSFileManager.defaultManager().currentDirectoryPath
	println("Running in directory \(directory)")
	var targetURL: NSURL?
	var sourceFiles = [NSURL]()
	var baseURL = NSURL(fileURLWithPath: directory, isDirectory: true)
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
			let type = argument.pathExtension
			if type == FileExtension.SwiftSource.rawValue {
				if let url = NSURL(fileURLWithPath: argument) {
					sourceFiles.append(url)
				}
			} else if type == FileExtension.Breakpoints.rawValue {
				targetURL = NSURL(fileURLWithPath: argument)
			} else if type == FileExtension.Workspace.rawValue || type == FileExtension.Project.rawValue {
				(targetURL, baseURL) = extractProjectFile(argument)
			} else if NSFileManager.defaultManager().fileExistsAtPath(argument, isDirectory: &isDirectory) && isDirectory {
				baseURL = NSURL(fileURLWithPath: argument, isDirectory: true)
			}
		}
	}
	#if codebreak=false && tag
println("Codebreak")
	#endif
	if targetURL == nil {
		if let baseURL = baseURL {
			if let contents = NSFileManager.defaultManager().contentsOfDirectoryAtURL(baseURL, includingPropertiesForKeys: nil,
				options: NSDirectoryEnumerationOptions.SkipsHiddenFiles, error: nil) {
				let candidates = contents.filter { current in
					return current.pathExtension == FileExtension.Project.rawValue || current.pathExtension == FileExtension.Workspace.rawValue
				}
				if let candidate = candidates.first as? NSURL where candidates.count == 1 {
					if let argument = candidate.path {
						(targetURL, _) = extractProjectFile(argument)
					}
				}
			}
		}
	}
	if let targetURL = targetURL {
		println("Using file \(targetURL)")
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
			} else if file.getResourceValue(&date, forKey: NSURLAttributeModificationDateKey, error: nil) && date?.timeIntervalSinceDate(doc.lastUpdate) > 0 {
				extractor.parseFile(file)
			}
		}
		doc.toXMLDocument().XMLDataWithOptions(Int(NSXMLNodePrettyPrint)).writeToURL(targetURL, atomically: true)
		if let components = targetURL.pathComponents as? [String] {
			let last = components.count - 5
			if last > 0 {
				let start = NSURL(fileURLWithPath: "/")!
				let container = components[0...last].reduce(start) { url, component in
					return url.URLByAppendingPathComponent(component)
				}
				let projectFile = container.URLByAppendingPathComponent("project.pbxproj")
				var err: NSError?
				if !NSFileManager.defaultManager().setAttributes([NSFileModificationDate: NSDate()], ofItemAtPath: projectFile.path!, error: &err) {
					println(err)
				}
			}
		}
	}
}

main()

