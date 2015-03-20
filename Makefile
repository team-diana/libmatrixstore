
libmatrixstore.so: src/matrix.d src/c_api.d obj/druntime_mgr.o 
	dmd -of$@ $^ -shared -gc -fPIC -defaultlib=libphobos2.so $(DMDFLAGS)


obj/druntime_mgr.o: src/druntime_mgr.c
	@mkdir -p obj
	$(CC) -c -g -o $@ $^ -g -lphobos2 -fPIC

ctest: src/ctest.c libmatrixstore.so 
	$(CC) -g -o ctest src/ctest.c -Iinclude -lmatrixstore -L.

smwatch: src/smwatch.c libmatrixstore.so 
	$(CC) -g -o smwatch src/smwatch.c -Iinclude -lmatrixstore -L.

clean:
	rm -r libmatrixstore.so obj/ *.o ctest
