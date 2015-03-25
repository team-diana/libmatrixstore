#include <matrixstore.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

int main(int argc, char **argv) {
	msSparseMatrix_t *sm;
	int r, c, nr, nc, ret;
	int i, j;
	double *data;
	
	if (argc < 6) {
		fprintf(stderr, "Usage:\n"
			" $ %s dir row column nrows ncolumns\n", argv[0]);
		return 1;
	}

	sm = msSparseMatrixOpen(argv[1], 10, 10);
	if (!sm) {
		fprintf(stderr, "Can't open matrix at `%s': %s\n",
			argv[1], msGetError());
		return 1;
	}

	r = atoi(argv[2]);
	c = atoi(argv[3]);
	nr = atoi(argv[4]);
	nc = atoi(argv[5]);
	data = malloc(sizeof(*data) * nr * nc);
	
	ret = msSparseMatrixRead(sm, data, r, c, nr, nc);
	if (ret == 0) {
		fprintf(stderr, "Couldn't read: %s\n", msGetError());
		return 1;
	}
	
	fwrite(data, sizeof(*data), nr*nc, stdout);

	msSparseMatrixClose(sm);
	return 0;
}

