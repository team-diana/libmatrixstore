#include <matrixstore.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

int main(int argc, char **argv) {
	char cmd[32];
	msSparseMatrix_t *sm;
	int r, c, nr, nc, ret;
	int i, j;
	double *data;
	
	if (argc < 6) {
		fprintf(stderr, "Usage:\n"
			" $ %s dir row column nrows ncolumns\n", argv[0]);
		return 0;
	}

	sm = msSparseMatrixOpen(argv[1], 10, 10);
	if (!sm) {
		fprintf(stderr, "Can't open matrix at `%s': %s\n",
			argv[1], msGetError());
		return 0;
	}

	r = atoi(argv[2]);
	c = atoi(argv[3]);
	nr = atoi(argv[4]);
	nc = atoi(argv[5]);
	data = malloc(sizeof(*data) * nr * nc);
	
	cmd[0] = '\0';
	while (cmd[0] != 'q') {
		ret = msSparseMatrixRead(sm, data, r, c, nr, nc);
		if (ret == 0) {
			fprintf(stderr, "Couldn't read: %s\n", msGetError());
			break;
		}

		printf("         .");
		for(j=c; j < c+nc; j++)
			printf(" % 7d", j);
		printf("\n");
		for(i=r; i < r+nr; i++) {
			printf(" % 7d |", i);
			for(j=c; j < c+nc; j++)
				printf(" % 7.2F", data[i*nc + j]);
			putchar('\n');
		}
		
		if (!fgets (cmd, sizeof(cmd), stdin))
			break;
	}

	msSparseMatrixClose(sm);
}
