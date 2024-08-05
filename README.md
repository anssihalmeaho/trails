# trails
Library for [FunL programs](https://github.com/anssihalmeaho/funl) to access
data easily as key-value trees, in pure functional way and storing data efficient
way to permanent storge.

## Install

Fetch repository with **--recursive** option (so that needed **fuse** submodule is included):

```
git clone --recursive https://github.com/anssihalmeaho/trails.git
```

## Background
There's tension between using pure immutable values in functional programming language
and storing values efficiently to permanent storage.
With **trails** value objects can be used in pure functional way and additionally keep 
record of changes so that only differences can be written to permanent storage.

In-memory value is maintained by **trails** and log of changes is written to permanent storage.

Value object is basically key-value tree so that it consists of nested maps.
Client can access nested data by giving **path** (list of keys) to target data.
By giving path client can read, write and remove values to/from value object.
It's many times easier to give path to target value than traversing nested maps recursively.
Value object manipulation is purely functional (immutable) so pure functions can use those.

Similar way of accessing data in nested immutable maps is used in [lens library](https://github.com/anssihalmeaho/fuse/tree/main/lens)
(actually **trails** uses **lens**).

**trails** is continuation for earlier [mimic library](https://github.com/anssihalmeaho/mimic) and part of implementation
is based on that.

## Solution building blocks
There are two kind of objects (maps of functions/procedures) in **trails**:

1. **base objects**
2. **value objects**

In addition there's **storer**-interface which provides methods for writing and reading log of changes.

**base** object is container for **value object**. Client can get latest **value object** from it
and then do processing with value objects. Client uses **commit**-method for writing new value object to base.
**base** assures that changes are based on same version of value object (value object contains version when
it's read from base). Also all commits are made by one fiber to prevent concurrent access in writing.

**storer**-object is given as parameter when **base** object is created. **base** uses **storer**
for reading and writing actions (change operations) to permanent storage (append only file etc.).
It's possible to have any implementation for that which satisfies **storer**-interface
(**open/write/read/close** -methods).

There is couple of possible storer-implementations in __/stores__ directory:

* __dummy-in-mem__: just dummy test implementation which holds log in memory
* __logfile-store__: append only log file implementation (endlessly fills log file which should be improved in real usage)


### Base object
Base object is created by calling **trails.init-base** procedure.
Storer object needs to be given as argument.
Return value is base object (map).

```
call(trails.init-base <storer-object>) -> <base-object>
```

Base object contains following methods:

method name | usage
----------- | -----
'get-value-object' | read current value object
'commit' | update to given value object
'close' | shutdown base usage

#### 'get-value-object' method
Returns current stored value object.

```
call(get(base 'get-value-object')) -> <value-object>
```

#### 'commit' method
Updates base to contain given value object.
Base checks that version is originating from previous value object.
Calls storer -interface for permanent storing of change log.

```
call(get(base 'commit') <value-object>) -> list(bool string <value-object>)
```

Return value is list which contains:

1. commit successful (**true** if success, **false** if not)
2. error text in case commit failed
3. latest value object

#### 'close' method
Shutdown for base.

```
call(get(base 'close')) -> true
```

### Value object
Value object contains following methods:

method name | usage
----------- | -----
'get-from' | reads value from given path
'set-to' | writes value to given path
'del-from' | removes given path
'value' | returns whole nested data structure

There are also 'log' and 'version' -methods but those
are called by **base** object (no real usage for client).

#### 'get-from' method
Reads value from path which is given as argument.

```
call(get(<value-object> 'get-from') <path:list>) -> list(bool <value>)
```

Return value is list of:

1. bool: if path found **true**, **false** if not found
2. if path was found contains value from that path

#### 'set-to' method
Writes given value to given path. Returns new, updated value object.
Arguments are:

1. path to which value is written
2. value to be written

If such nested map is not found to which path refers then maps are created.
If there's already value behind given path then it's replaced with given value.

```
call(get(<value-object> 'set-to') <path:list> <value>) -> <value-object>
```

Return value is new value object which contains change.

#### 'del-from' method
Removes path (given as argument) from value-object.

```
call(get(<value-object> 'del-from') <path:list>) -> <value-object>
```

Return value is new value object from which given path is removed.

#### 'value' method
Returns whole nested value (map).

```
call(get(<value-object> 'value')) -> <map>
```

### Storer -interface
Storer interface is used by **base** for storing action log and for reading it.

There are following methods assumed by **base** for **storer** interface:

method name | usage
----------- | -----
'open' | opening storage
'write' | writing action log
'read' | reading action log
'close' | closing storage

Action log is list which may contain following kind of items:

* list('start' initial-value) -> initial value
* list('put' path value) -> add value for path
* list('del' path) -> remove path


#### 'open' method
Opens storage.

```
call(get(storer 'open')) -> list(bool string)
```

Returns list of:

1. bool: **true** if success, **false** is failed
2. error description if failed

#### 'write' method
Writes given action list or given value to storage.
Arguments are:

1. action list
2. latest whole value

Storer implementation can decide when to create new append-only log file
(as otherwise it would increase without limit).
Storer can for example create new file and start it with **list('start' latest-value)**.
Or store whole value to separate file and clear append-only log file.
So storer can decide when to use just action list and when the whole value.

```
call(get(<storer> 'write') <action-log:list> <whole-value:map>) -> list(bool string)
```

Return value is list of:

1. bool: **true** if success, **false** is failed
2. error description if failed

#### 'read' method
Reads all stored actions.

```
call(get(<storer> 'read')) -> list(bool string <action-log:list> <baseline-value>)
```

Returns list of:

1. bool: **true** if success, **false** is failed
2. error description if failed
3. list of actions (if success)
4. baseline value (to which actions are to be applied)

#### 'close' method
Closes storage.

```
call(get(<storer> 'close')) -> true
```

## Example code

Example code shows some example ways to use **trails**.

Run example like:

```
funla example.fnl
```

Output is:

```
person 1: list(true, map('name' : 'Bob', 'age' : 50))
person 2: list(true, map('name' : 'Ben', 'age' : 30))
person 1 age before: list(true, 50)
person 1 age after: list(true, 53)
person 2 age before del: list(true, 30)
person 2 age after del: list(false, '')
close: true
'
Latest content:

map(
        'persons'
        map(
                1
                map(
                        'name'
                        'Bob'
                        'age'
                        53
                )
                2
                map(
                        'name'
                        'Ben'
                )
        )
)'
```

Example program creates **oplog.txt** file which contains log of changes (in serialized format).

## ToDo
Some things to do in future perhaps:

* support for having lists as part of nested data (having indexes as path keys)
* composite operations for value object
