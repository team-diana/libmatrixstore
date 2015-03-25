
VER_MAJOR = 0
VER_MINOR = 0
VER_REV   = 1
VERSION = $(VER_MAJOR).$(VER_MINOR).$(VER_REVISION)

LIB_INSTALL_PATH = /usr/lib
INCLUDE_INSTALL_PATH = /usr/include

libmatrixstore.so: src/matrix.d src/c_api.d obj/druntime_mgr.o 
	dmd -of$@ $^ -shared -gc -fPIC -O -defaultlib=libphobos2.so $(DMDFLAGS)

obj/druntime_mgr.o: src/druntime_mgr.c
	@mkdir -p obj
	$(CC) -c -g -o $@ $^ -g -lphobos2 -fPIC

ctest: src/ctest.c libmatrixstore.so 
	$(CC) -g -o ctest src/ctest.c -Iinclude -lmatrixstore -L.

smwatch: src/smwatch.c libmatrixstore.so 
	$(CC) -g -o smwatch src/smwatch.c -Iinclude -lmatrixstore -L.

read: src/read.c libmatrixstore.so 
	$(CC) -g -o $@ $< -Iinclude -lmatrixstore -L.

clean:
	rm -rf libmatrixstore.so obj/ *.o ctest read smwatch

install: include/matrixstore.h libmatrixstore.so
	install -t $(INCLUDE_INSTALL_PATH) include/matrixstore.h
	install	-t $(LIB_INSTALL_PATH) libmatrixstore.so
	ln -f -s $(LIB_INSTALL_PATH)/libmatrixstore.so $(LIB_INSTALL_PATH)/libmatrixstore.so.$(VER_MAJOR)
	ln -f -s $(LIB_INSTALL_PATH)/libmatrixstore.so $(LIB_INSTALL_PATH)/libmatrixstore.so.$(VER_MAJOR).$(VER_MINOR)
	ln -f -s $(LIB_INSTALL_PATH)/libmatrixstore.so $(LIB_INSTALL_PATH)/libmatrixstore.so.$(VER_MAJOR).$(VER_MINOR).$(VER_REV)

uninstall:
	rm $(INCLUDE_INSTALL_PATH)/matrixstore.h
	rm $(LIB_INSTALL_PATH)/libmatrixstore.so
	rm $(LIB_INSTALL_PATH)/libmatrixstore.so.$(VER_MAJOR)
	rm $(LIB_INSTALL_PATH)/libmatrixstore.so.$(VER_MAJOR).$(VER_MINOR)
	rm $(LIB_INSTALL_PATH)/libmatrixstore.so.$(VER_MAJOR).$(VER_MINOR).$(VER_REV)
