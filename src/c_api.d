import matrix;

import std.c.string;
import std.string;
import core.memory;

private char[] lastError;

extern(C) {
    static assert (is(Matrix.Element : double));

    SparseMatrix msSparseMatrixOpen(const(char)* directory,
				 int defBlkRows, int defBlkCols)
    {
	int[2] defBlkSize = [defBlkRows, defBlkCols];

	try {
	    SparseMatrix ret = SparseMatrix.open(directory.fromStringz, defBlkSize);
	    GC.addRoot(&ret);
	    return ret;
	} catch(Exception exc) {
	    lastError = exc.msg.dup;
	    return null;
	}
    }
    
    int msSparseMatrixWrite(SparseMatrix sm,
			     double *src, int numRows, int numCols,
			     int dstRow, int dstCol)
    {
	try { 
	    Matrix mtx = new Matrix(Index(numRows, numCols),
				    src[0 .. (numRows*numCols)]);
	    
	    sm.set(mtx, Index(dstRow, dstCol));
	} catch(Exception exc) {
	    lastError = exc.msg.dup;
	    return 0;
	}
	return 1;
    }

    int msSparseMatrixRead(SparseMatrix src,
			    double* dst,
			    int ofsRow, int ofsCol,
			    int numRows, int numCols)
    {
	try { 
	    scope Matrix mtx = src.get(Index(ofsRow, ofsCol),
				       Index(numRows, numCols));
	    memcpy(dst, mtx.data.ptr,
		   Matrix.Element.sizeof * mtx.shape[0] * mtx.shape[1]);
	    
	} catch(Exception exc) {
	    lastError = exc.msg.dup;
	    return 0;
	}
	return 1;
    }

    int msSparseMatrixClose(SparseMatrix sm)
    {
	try {
	    sm.destroy();
	    GC.removeRoot(&sm);
	    return 1;
	} catch(Exception exc) {
	    lastError = exc.msg.dup;
	    return 0;
	}
    }

    char* msGetError() {
	if (lastError.length)
	    return lastError.dup.ptr;
	else
	    return null;
    }
}

