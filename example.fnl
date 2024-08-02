
ns main

import trails
import logfile-store
import dummy-in-mem
import stdpp

#store = call(dummy-in-mem.get-store)
store = call(logfile-store.get-store 'oplog.txt')

main = proc()
	# create base object
	base = call(trails.init-base store)
	# get current (empty) value object
	vob-1 = call(get(base 'get-value-object'))

	# lets add some fields there
	vob-2 = call(get(vob-1 'set-to') list('persons' 1 'name') 'Bob')
	vob-3 = call(get(vob-2 'set-to') list('persons' 1 'age') 50)
	vob-4 = call(get(vob-3 'set-to') list('persons' 2) map('name' 'Ben' 'age' 30))

	# we can read certain field values from value object too
	print('person 1: ' call(get(vob-4 'get-from') list('persons' 1)))
	print('person 2: ' call(get(vob-4 'get-from') list('persons' 2)))

	# field value can be updated with new value (like age here 50 -> 53)
	print('person 1 age before: ' call(get(vob-4 'get-from') list('persons' 1 'age')))
	vob-5 = call(get(vob-4 'set-to') list('persons' 1 'age') 53)
	print('person 1 age after: ' call(get(vob-5 'get-from') list('persons' 1 'age')))

	# removing field age from person 2
	print('person 2 age before del: ' call(get(vob-5 'get-from') list('persons' 2 'age')))
	vob-6 = call(get(vob-5 'del-from') list('persons' 2 'age'))
	print('person 2 age after del: ' call(get(vob-6 'get-from') list('persons' 2 'age')))

	# lets then commit changes to base object
	call(get(base 'commit') vob-6)

	# now we can ask latest value object from base and it contains
	# latest updates
	latest-vob = call(get(base 'get-value-object'))
	# with 'value' method all content of value object can be asked
	retv = call(stdpp.pform
		call(get(latest-vob 'value'))
	)

	# in the end it's good to close base object
	print('close: ' call(get(base 'close')))

	sprintf('\nLatest content:\n%s' retv)
end

endns

