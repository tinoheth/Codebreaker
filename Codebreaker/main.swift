//
//  main.swift
//  Exterminator
//
//  Created by Tino Heth on 04.01.15.
//  Copyright (c) 2015 Tino Heth. All rights reserved.
//

import Foundation
import LibXcbkptlist

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
	var doc = parse(NSURL(fileURLWithPath: "/Users/tinoheth/Projekte/Coolspot/Coolspot.xcworkspace/xcuserdata/tinoheth.xcuserdatad/xcdebugger/Breakpoints_v2.xcbkptlist")!)
	switch doc {
	case .success(data: let xml):
		walk(xml.rootElement()!)
	default: break
	}
}

main()

