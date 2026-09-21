-- 哔哩哔哩 加速 · macOS 安装 / 卸载器
-- 编译方式：osacompile -o "哔哩哔哩 加速 安装器.app" installer.applescript

set appTitle to "哔哩哔哩 加速"
set resPath to (POSIX path of (path to me)) & "Contents/Resources"
set logPath to "/tmp/biliapp-installer.log"

try
	set choice to button returned of (display dialog appTitle & "

要安装（让客户端自动加速），还是卸载（恢复原样）？" buttons {"退出", "卸载", "安装"} default button "安装" with icon note with title appTitle)
on error
	return
end try

if choice is "安装" then
	set scriptPath to resPath & "/macos/install.sh"
	set logText to "（没有日志）"
	try
		set resultText to do shell script "/bin/zsh -c " & quoted form of ("/bin/zsh " & quoted form of scriptPath & " > " & quoted form of logPath & " 2>&1; echo EXIT=$?")
		set logText to do shell script "tail -n 16 " & quoted form of logPath
		if resultText contains "EXIT=0" then
			display dialog "✅ 安装完成！

" & logText buttons {"好"} default button "好" with title appTitle with icon note
		else
			display dialog "❌ 安装出错了，请把下面的内容发给我：

" & logText buttons {"好"} default button "好" with title appTitle with icon stop
		end if
	on error errMsg
		display dialog "❌ 安装失败：" & errMsg buttons {"好"} default button "好" with title appTitle with icon stop
	end try
else if choice is "卸载" then
	set scriptPath to resPath & "/macos/uninstall.sh"
	set logText to "（没有日志）"
	try
		set resultText to do shell script "/bin/zsh -c " & quoted form of ("/bin/zsh " & quoted form of scriptPath & " > " & quoted form of logPath & " 2>&1; echo EXIT=$?")
		set logText to do shell script "tail -n 16 " & quoted form of logPath
		if resultText contains "EXIT=0" then
			display dialog "✅ 卸载完成

" & logText buttons {"好"} default button "好" with title appTitle with icon note
		else
			display dialog "❌ 卸载出错了，请把下面的内容发给我：

" & logText buttons {"好"} default button "好" with title appTitle with icon stop
		end if
	on error errMsg
		display dialog "❌ 卸载失败：" & errMsg buttons {"好"} default button "好" with title appTitle with icon stop
	end try
end if
