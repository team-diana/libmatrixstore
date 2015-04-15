#include <matrixstore.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define IN_ROWS 4
#define IN_COLS 3

int main(int argc, char **argv) {
	double value = 0.0;
	double test_mat[IN_ROWS][IN_COLS];
	double test_output[IN_ROWS+4][IN_COLS+4];
	int i, j;

	srand (time (0));
	
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

	i = (float)rand() / RAND_MAX * 10 - 5;
	j = (float)rand() / RAND_MAX * 10 - 5;
	printf("Written to (%d,%d)x(%d,%d)\n", i, j, IN_ROWS, IN_COLS);
	if (!msSparseMatrixWrite(spmat, &test_mat[0][0], IN_ROWS, IN_COLS, i, j)) {
		fprintf(stderr, "Couldn't write matrix: %s\n", msGetError());
		return 0;
	}

	printf("Reading from (%d,%d)x(%d,%d)\n", 
		i-2, j-2, IN_ROWS+4, IN_COLS+4);
	if (!msSparseMatrixRead(spmat, &test_output[0][0], i-2, j-2, IN_ROWS+4, IN_COLS+4)) {
		fprintf(stderr, "Couldn't read matrix: %s\n", msGetError());
		return 0;
	}

	msSparseMatrixClose(spmat);
	
	for(i=0; i < IN_ROWS+4; i++) {
		for(j=0; j < IN_COLS+4; j++) {
			printf(" % 7.2F", test_output[i][j]);
		}
		putchar('\n');
	}

	return 0;
}

