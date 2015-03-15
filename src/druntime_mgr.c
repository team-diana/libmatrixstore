
extern void rt_init();
extern void rt_term();

void __attribute__ ((constructor)) libmatrix_init(void) {
	rt_init();
}

void __attribute__ ((destructor)) libmatrix_fini(void) {
	rt_term();
}


