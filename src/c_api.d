import matrix;

import std.c.string;
import std.string;
import core.memory;
import std.typecons;

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
	    if (numRows == 1 && numCols == 1) {
		sm[dstRow, dstCol] = *src;
		return 1;
	    }
	    
	    Matrix mtx = new MemoryMatrix(Index(numRows, numCols),
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
	    if (numRows == 1 && numCols == 1) {
		*dst = src[ofsRow, ofsCol];
		return 1;
	    }
		    
	    Matrix mtx = src.get(Index(ofsRow, ofsCol),
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
	    GC.collect();
	} catch(Exception exc) {
	    lastError = exc.msg.dup;
	    return 0;
	}

	return 1;
    }

    char* msGetError() {
	if (lastError.length) {
	    auto ptr = lastError.dup.ptr;
	    GC.addRoot(ptr);
	    return ptr;
	} else {
	    return null;
	}
    }
}

