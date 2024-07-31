
ns dummy-in-mem

get-store = proc()
	import lens
	import stdvar
	import stdfu

	store-ref = call(stdvar.new list())

	# method for writing action log
	write = proc(action-list as-value)
		adder = func(action result)
			append(result action)
		end

		new-actions = call(stdfu.ploop adder action-list call(stdvar.value store-ref))
		call(stdvar.set store-ref new-actions)
		list(true '')
	end

	# method for reading action log
	read = proc()
		list(true '' call(stdvar.value store-ref) map())
	end

	# open method (dummy)
	open = proc()
		list(true '')
	end

	# close method (dummy)
	close = proc()
		true
	end

	# store object
	map(
		'open'  open
		'write' write
		'read'  read
		'close' close
	)
end

endns

