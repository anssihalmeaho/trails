
ns trails

new-value-object = func(initial version)
	import lens

	create-value-object = func(target-value log)
		set-to = func(path value)
			call(create-value-object
				call(lens.set-to path target-value value)
				append(log list('put' path value))
			)
		end

		del-from = func(path)
			call(create-value-object
				last(call(lens.del-from path target-value))
				append(log list('del' path))
			)
		end

		# value object
		map(
			# new stuff
			'set-to'   set-to
			'del-from' del-from
			'get-from' func(path) call(lens.get-from path target-value) end

			# methods for getting log and latest value and version
			'log'     func() log end
			'value'   func() target-value end
			'version' func() version end
		)
	end

	call(create-value-object initial list(list('start' initial version)))
end

# create new base
init-base = proc(storer)
	import stdvar
	import lens

	create-value-from-log = func(action-list base-value)
		loopy = func(act-list result)
			if(empty(act-list)
				result
				call(func()
					action = head(act-list)
					op = head(action)
					case(op
						# just skip, base value already taken
						'start' call(loopy rest(act-list) result)

						'put'
						call(func()
							key val = rest(action):
							call(loopy
								rest(act-list)
								call(lens.set-to key result val)
							)
						end)

						'del'
						call(func()
							key = rest(action):
							_ nextval = call(lens.del-from key result):
							call(loopy rest(act-list) nextval)
						end)
					)
				end)
			)
		end

		call(loopy action-list base-value)
	end

	# read initial value from storage
	map-value = call(proc()
		open-ok open-err = call(get(storer 'open')):
		if(open-ok 'ok' error(sprintf('storage open failed: %s' open-err)))

		ok err action-list base-value = call(get(storer 'read')):
		if(ok 'ok' error(sprintf('reading from storage failed: %s' err)))
		call(create-value-from-log action-list base-value)
	end)

	is-open-ref = call(stdvar.new true)
	server-chan = chan()

	# server fiber
	spawn(call(
		proc(my-value)
			proce replych = recv(server-chan):
			new-val retval = call(proce my-value call(get(my-value 'version'))):
			send(replych retval)
			while(true new-val 'whatever')
		end
		call(new-value-object map-value 10)
	))

	# get latest value object
	get-value-object = proc()
		getter = proc(mval) list(mval mval) end

		call(proc()
			replych = chan()
			send(server-chan list(getter replych))
			recv(replych)
		end)
	end

	# closing
	close = proc()
		closer = proc(mval)
			call(get(storer 'close'))
			list(mval 'closed')
		end

		replych = chan()
		send(server-chan list(closer replych))
		recv(replych)
		# TODO: in theory there is small time window in which some
		# method may get to running...
		call(stdvar.set is-open-ref false)
		true
	end

	# write new value
	commit = proc(with-value-ob)
		committer = proc(mval prev-version)
			new-version = call(get(with-value-ob 'version'))
			new-v = call(get(with-value-ob 'value'))
			change-log = call(get(with-value-ob 'log'))

			if( eq(new-version prev-version)
				call(proc()
					write-ok write-err = call(get(storer 'write') change-log new-v):
					if(write-ok
						call(proc()
							# lets make new value so that its log is initialized
							newval = call(new-value-object new-v plus(prev-version 1))
							list(newval list(true '' newval))
						end)

						list(mval list(false write-err mval))
					)
				end)

				list(mval list(false 'version conflict' mval))
			)
		end

		replych = chan()
		send(server-chan list(committer replych))
		recv(replych)
	end

	# method wrapper for handling closed check
	closed-wrapper = proc(method)
		proc()
			is-open = call(stdvar.value is-open-ref)
			if(is-open 'ok' error('closed'))
			call(method argslist():)
		end
	end

	# base -object
	map(
		'get-value-object' call(closed-wrapper get-value-object)
		'commit'           call(closed-wrapper commit)
		'close'            close
	)
end

endns

