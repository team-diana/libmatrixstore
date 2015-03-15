#include <libmatrix.h>
#include <stdio.h>

#define OUT_ROWS 10
#define OUT_COLS 6

int main() {
	double test_mat[4][3] = {
		{ 3.32, 2.12, -32.12 },
		{ 3.32, 2.12, -32.12 },
		{ 3.32, 2.12, -32.12 },
		{ 3.32, 2.12, -32.12 },
	};

	double test_output[OUT_ROWS][OUT_COLS];

	int i, j;

	msSparseMatrix_t *spmat = msSparseMatrixOpen("/tmp/sparse-matrix-ctest/", 10, 10);

	msSparseMatrixWrite(spmat, &test_mat[0][0], 4, 3, 0, 0);

	msSparseMatrixRead(spmat, &test_output[0][0], -1, -1, OUT_ROWS, OUT_COLS);

	for(i=0; i < OUT_ROWS; i++) {
		for(j=0; j < OUT_COLS; j++) {
			printf(" %2.2lf", test_output[i][j]);
		}
		putchar('\n');
	}

	return 0;
}

