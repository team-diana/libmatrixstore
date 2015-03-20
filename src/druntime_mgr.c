
extern void rt_init();
extern void rt_term();

void __attribute__ ((constructor)) libmatrixstore_init(void) {
	rt_init();
}

void __attribute__ ((destructor)) libmatrixstore_fini(void) {
	rt_term();
}


