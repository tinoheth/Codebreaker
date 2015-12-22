//
//  main.swift
//  Test
//
//  Created by Tino Heth on 18.04.15.
//  Copyright (c) 2015 Tino Heth. All rights reserved.
//

import Foundation

print("Hello, World!")
#if codebreak=true && ignore=0 && enabled=true && MyTag && tag=Mark
	print("Look at me")
	print("I'm a breakpoint action")
	print("No self in here")
#endif
print("I'm done")
print("(really)")

