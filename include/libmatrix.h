#ifndef _LIBMATRIX_H
#define _LIBMATRIX_H

#ifdef  __cplusplus
extern "C"
{
#endif

typedef struct msSparseMatrix msSparseMatrix_t;

extern msSparseMatrix_t* msSparseMatrixOpen(const char* directory,
											int defBlkRows, int defBlkCols);
	
extern void msSparseMatrixWrite(msSparseMatrix_t *sm, double *src,
								int numRows, int numCols,
								int dstRow, int dstCol);

extern void msSparseMatrixRead(msSparseMatrix_t *src, double* dst,
							   int ofsRow, int ofsCol,
							   int numRows, int numCols);

extern void msSparseMatrixClose(msSparseMatrix_t *sm);

#ifdef __cplusplus
} // extern "C"
#endif

#endif /* _LIBMATRIX_H */
