#!/usr/bin/env python
import os
os.chdir('lib')
exec open('irmin.py').read()

r = Repository ()
store = r.master_store ()
list(store.history())

store['a'] = 'b'

print store['a']

print list(store.history())

store['a'] = 'c'

store.undo()
print list(store.history())
print store['a']
print list(store.history())
store.undo()

print store['a']
