//
//  main.swift
//  Test
//
//  Created by Tino Heth on 18.04.15.
//  Copyright (c) 2015 Tino Heth. All rights reserved.
//

import Foundation

println("Hello, World!")
#if codebreak=true && ignore=40 && enabled=true && MyTag && tag=Mark
	println("Look at me")
	println("I'm a breakpoint action")
	println("No self in here")
#endif
println("I'm done")
println("(really)")

