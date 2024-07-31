
ns logfile-store

get-store = proc(filename)
	import stdfiles
	import stdser
	import stdbytes

	open-file = proc(fname)
		fh = call(stdfiles.open fname plus(stdfiles.a stdfiles.r))
		if(eq(type(fh) 'string')
			call(proc()
				file = call(stdfiles.create fname)
				if(eq(type(file) 'string')
					list(false file '')
					list(true '' file)
				)
			end)
			list(true '' fh)
		)
	end

	# method for writing action log (& value)
	write = proc(file action-list as-value)
		loopy = proc(actions result)
			if(empty(actions)
				result
				call(proc()
					action = head(actions)
					if(eq(head(action) 'start')
						# op is 'start', then skip that
						call(loopy rest(actions) result)

						call(proc()
							ser-ok ser-err encoded = call(stdser.encode action):
							if(ser-ok
								call(proc()
									as-str = call(stdbytes.string encoded)
									call(stdfiles.writeln file as-str)
									call(loopy rest(actions) result)
								end)
								list(false ser-err)
							)
						end)
					)
				end)
			)
		end

		# storer can decide to store whole value, just to demonstrate that
		# but it should create new file 1st...('start' only in beginning)
		write-whole-value = proc()
			action = list('start' as-value)
			_ _ encoded = call(stdser.encode action):
			as-str = call(stdbytes.string encoded)
			call(stdfiles.writeln file as-str)
			list(true '')
		end

		if(true
			# append actions from log
			call(loopy action-list list(true ''))
			# writing value as whole: not used for now
			call(write-whole-value)
		)
	end

	# method for reading base value & action log
	read = proc(file)
		loopy = func(linelist result)
			if(empty(linelist)
				result
				call(func()
					as-bytes = call(stdbytes.str-to-bytes head(linelist))
					dec-ok dec-err action = call(stdser.decode as-bytes):
					if(dec-ok
						call(func()
							_ _ act-list = result:
							call(loopy rest(linelist) list(true '' append(act-list action)))
						end)
						list(false dec-err list())
					)
				end)
			)
		end

		lines = call(stdfiles.readlines file)

		# read base value if it exists as 1st line in log
		basev = if(empty(lines)
			map()
			call(func()
				as-bytes = call(stdbytes.str-to-bytes head(lines))
				dec-ok dec-err action = call(stdser.decode as-bytes):
				if(dec-ok 'ok' error(dec-err))
				if( eq(head(action) 'start')
					head(rest(action))
					map()
				)
			end)
		)

		if(eq(type(lines) 'string')
			list(false lines list() map())
			append(
				call(loopy lines list(true '' list()))
				basev
			)
		)
	end

	# wraps method with file open/close handler
	file-wrapper = func(procedure)
		proc()
			open-ok open-err fh = call(open-file filename):
			retv = if(open-ok
				call(procedure fh argslist():)
				list(false open-err map())
			)
			call(stdfiles.close fh)
			retv
		end
	end

	# store object
	map(
		'open'   proc() list(true '') end
		'write'  call(file-wrapper write)
		'read'   call(file-wrapper read)
		'close'  proc() true end
	)
end

endns

