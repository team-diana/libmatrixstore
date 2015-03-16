#include <libmatrix.h>
#include <stdio.h>
#include <stdlib.h>

#define IN_ROWS 4
#define IN_COLS 3
#define OUT_ROWS 10
#define OUT_COLS 6

int main(int argc, char **argv) {
	double value = 0.0;
	double test_mat[IN_ROWS][IN_COLS];
	double test_output[OUT_ROWS][OUT_COLS];
	int i, j;

	if (argc >= 2)
		value = atof(argv[1]);
	
	printf("value = %lf\n", value);
	
	for (i=0; i < IN_ROWS; i++)
		for (j=0; j < IN_COLS; j++)
			test_mat[i][j] = value;
	
	const char *matPath = "/tmp/sparse-matrix-ctest/";
	msSparseMatrix_t *spmat = msSparseMatrixOpen(matPath, 10, 10);
	if (spmat == NULL) {
		fprintf(stderr, "Couldn't open matrix at %s: %s\n", matPath, msGetError());
		return 0;
	}
	
	if (!msSparseMatrixWrite(spmat, &test_mat[0][0], IN_ROWS, IN_COLS, 0, 0)) {
		fprintf(stderr, "Couldn't write matrix: %s\n", msGetError());
		return 0;
	}

	if (!msSparseMatrixRead(spmat, &test_output[0][0], -1, -1, OUT_ROWS, OUT_COLS)) {
		fprintf(stderr, "Couldn't read matrix: %s\n", msGetError());
		return 0;
	}

	msSparseMatrixClose(spmat);
	
	for(i=0; i < OUT_ROWS; i++) {
		for(j=0; j < OUT_COLS; j++) {
			printf(" %2.2lf", test_output[i][j]);
		}
		putchar('\n');
	}

	return 0;
}

