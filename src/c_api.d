import matrix;

import std.c.string;
import std.string;
import core.memory;

extern(C) {
    static assert (is(Matrix.Element : double));
    
    SparseMatrix msSparseMatrixOpen(const(char)* directory,
				 int defBlkRows, int defBlkCols)
    {
	int[2] defBlkSize = [defBlkRows, defBlkCols];

	SparseMatrix ret = SparseMatrix.open(directory.fromStringz, defBlkSize);
	GC.addRoot(&ret);
	return ret;
    }
    
    void msSparseMatrixWrite(SparseMatrix sm,
			     double *src, int numRows, int numCols,
			     int dstRow, int dstCol)
    {
	Matrix mtx = new Matrix(Index(numRows, numCols),
				src[0 .. (numRows*numCols)]);
	sm.set(mtx, Index(dstRow, dstCol));
    }

    void msSparseMatrixRead(SparseMatrix src,
			    double* dst,
			    int ofsRow, int ofsCol,
			    int numRows, int numCols)
    {
	scope Matrix mtx = src.get(Index(ofsRow, ofsCol),
			     Index(numRows, numCols));
	memcpy(dst, mtx.data.ptr,
	       Matrix.Element.sizeof * mtx.shape[0] * mtx.shape[1]);
    }

    void msSparseMatrixClose(SparseMatrix sm)
    {
	sm.destroy();
	GC.removeRoot(&sm);
    }
}

