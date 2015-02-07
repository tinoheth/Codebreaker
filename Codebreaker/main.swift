//
//  main.swift
//  Exterminator
//
//  Created by Tino Heth on 04.01.15.
//  Copyright (c) 2015 Tino Heth. All rights reserved.
//

import Foundation

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

func main() {
	let directory = NSFileManager.defaultManager().currentDirectoryPath
	println("Running in directory \(directory)")
	var targetURL: NSURL?
	var sourceFiles = [NSURL]()
	for argument in Process.arguments[1..<Process.arguments.count] {
		let type = argument.pathExtension
		if type == "m" {
			if let url = NSURL(fileURLWithPath: argument) {
				sourceFiles.append(url)
			}
		} else if type == "xcbkptlist" {
			targetURL = NSURL(fileURLWithPath: argument)
		} else if type == "xcworkspace" || type == "xcodeproj" {
			if let user = NSProcessInfo.processInfo().environment["USER"] as? String {
				targetURL = NSURL(fileURLWithPath: directory.stringByAppendingPathComponent(argument).stringByAppendingPathComponent("xcuserdata/\(user).xcuserdatad/xcdebugger/Breakpoints_v2.xcbkptlist"))
			}
		}
	}
	if let targetURL = targetURL {
		println("Using file \(targetURL)")
		if let data = NSData(contentsOfURL: targetURL) {
			if let xml = NSXMLDocument(data: data, options: 0, error: nil) {
				let doc = BreakpointFile(xmlDocument: xml)
				let list = doc.fileBreakpointsForPath(doc.registeredFiles().first)
				if let br = list.last {
					br.ignoreCount = 44
				}
				if let br = list.first {
					doc.deleteBreakpoint(br)
					br.startingLineNumber = 33
					doc.addFileBreakpoint(br)
				}
				doc.toXMLDocument().XMLDataWithOptions(Int(NSXMLNodePrettyPrint)).writeToURL(targetURL, atomically: true)
			}
		}
		
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

