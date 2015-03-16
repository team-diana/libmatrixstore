#ifndef _LIBMATRIX_H
#define _LIBMATRIX_H

#ifdef  __cplusplus
extern "C"
{
#endif

typedef struct msSparseMatrix msSparseMatrix_t;

extern msSparseMatrix_t* msSparseMatrixOpen(const char* directory,
											int defBlkRows, int defBlkCols);
	
extern int msSparseMatrixWrite(msSparseMatrix_t *sm, double *src,
								int numRows, int numCols,
								int dstRow, int dstCol);

extern int msSparseMatrixRead(msSparseMatrix_t *src, double* dst,
							   int ofsRow, int ofsCol,
							   int numRows, int numCols);

extern int msSparseMatrixClose(msSparseMatrix_t *sm);

extern char* msGetError(void);
	
#ifdef __cplusplus
} // extern "C"
#endif

#endif /* _LIBMATRIX_H */
