import os, ctypes

builddir = os.path.realpath(os.path.join(
    os.path.dirname(__file__),
    '..',
    '_build'))

libirmin = ctypes.CDLL(os.path.join(builddir, 'libirmin.so'))
libirmin.irmin_store_read.restype = ctypes.c_char_p

class Repository(object):

    def __init__(self, ptr=None):
        self._p = (libirmin.irmin_repository_create()
                   if ptr is None else ptr)

    def master_store(self):
        return Store(libirmin.irmin_repository_master_store(self._p))

    def __del__(self):
        if libirmin is not None:
            libirmin.irmin_repository_destroy(self._p)
        self._p = None

class Store(object):

    def __init__(self, ptr):
        self._p = ptr

    def __setitem__(self, k, v):
        if not isinstance(k, str) or not isinstance(v, str):
            raise TypeError
        libirmin.irmin_store_append(self._p, k, v)

    def __getitem__(self, k):
        if not isinstance(k, str):
            raise TypeError
        v = libirmin.irmin_store_read(self._p, k)
        if v in (0, None):
            raise KeyError, k
        else: return v

    def undo(self):
        history = list(self.history())
        if len(history) > 1:
            print 'setting history to %s' % (history[1],)
            libirmin.irmin_store_update_head(self._p, history[1])

    def history(self):
        return History(libirmin.irmin_store_history(self._p))

    def __del__(self):
        if libirmin is not None:
            libirmin.irmin_store_destroy(self._p)
        self._p = None

_walk_type = ctypes.CFUNCTYPE(ctypes.c_int,
                              ctypes.POINTER(ctypes.c_char))

class History(object):

    def __init__(self, ptr):
        self._p = ptr
        self._items = None

    def _cache_items(self):
        if self._items is None:
            self._items = []
            def f(v): self._items.append(ctypes.string_at(v)); return 1
            libirmin.irmin_history_walk(self._p, _walk_type(f))

    def __iter__(self):
        self._cache_items()
        return iter(self._items)

    def __del__(self):
        if libirmin is not None:
            libirmin.irmin_history_destroy(self._p)
        self._p = None

def _initialize_caml_runtime():
    caml_argv = ctypes.ARRAY(ctypes.POINTER(ctypes.c_char), 1)()
    caml_argv[0] = None
    libirmin.caml_startup(caml_argv)

_initialize_caml_runtime()
