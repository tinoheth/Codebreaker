# Hobby
Ugly tool to manage Xcode breakpoints inline (Swift only)

Let's try an example:

	print("I'm going to do something strange")
	#if codebreak=false && ignore=10
		print("Look at me")
		print("I'm a breakpoint action")
	#endif
	print("I'm done")

This code will just print two lines in the console, quite boring... but if you run Hobby on the project, three things will happen:

1. Xcode crashes (not always - but but for many projects, it will just happen if you modify them while they are open)
2. The code will still print just two lines in the console - unless you hit that location eleven times.
From there on, you will have two additional lines in your shell.
3. The "#endif" line will be marked with a breakpoint

#####"Mhh, okay... I guess this is a really cool, but actually, I'm rather busy right now..."
That's fine, I'm not sure how useful this tool will be for myself... but the approach has some benefits, and I would be glad to see the breakpoint support in Xcode improve (it has been better back when it was ProjectBuilder):
Breakpoint actions are quite powerful, but no fun to use, because the GUI is complicated, and leaves you only a single line for your scripts.

###What can it do for me?
In the example, the only function used is `print`, and imho this one is used way to often in the wild...
Breakpoints never show up in shipped code, and, even better, you can toggle them while you are debugging and modify the behavior of your programm.
Theoretically, you can do "fix & continue" with breakpoint actions, but I guess there is a reason why this feature was so flaky that it got removed from Xcode.

###How does it work?
The `#if` is just to make sure the compiler ignores the breakpoint action (unless you have crazy defines...). Comments could do the same, but than you loose syntax checks, which are quite useful.
The breakpoints are created by a parser that looks for `#if codebreak`, and changes the breakpoints file in your project accordingly. Then, it has to refresh the project, which might cause 1) :-(

###Features?
Yes ;-). As show in the example, you can set the ignore count and configure the breakpoint not to stop your programm (`codebreak=true` or just `codebreak` creates a really breaking breakpoint).
Additionally, `shouldBeEnabled` can be used to (you'll figure out it's meaning).
Actually, there are even more "parameters", but those aren't that useful right now (but I'm thinking of support tools to toggle whole groups of breakpoints).

###So... how does this really work?
1. Clone the repo
2. Open your terminal and navigate to the project directory
3. Run `xcodebuild install`
4. Curse the stupid author because the default install location will be `/opt/bin`
5. Navigate to you own project, type `/opt/bin/hobby -f`
6. Nothing happens... but it should when you change your own source to include at least one `#if codebreaker` (there is also a Workflow that will enclose Xcodes current selection in such an ifdef)
