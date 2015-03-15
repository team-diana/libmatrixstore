import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.functional;
import std.json;
import std.mmfile;
import std.path;
import std.random;
import std.random;
import std.stdio;
import std.string;

struct Index {
    int[2] indices;
    alias indices this;

    this(int[2] indices) {
	this.indices = indices;
    }
    
    this(int[2] indices ...) {
	this.indices = indices;
    }
    
    void opAssign(int[2] indices) {
	this.indices = indices;
    }
    
    enum Index zero = Index.init;

    inout Index opBinary(string op)(inout Index rhs) inout {
	Index ret;
	foreach(i; 0 .. indices.length)
	    ret[i] = mixin("indices[i] " ~ op ~ " rhs[i]");
	return ret;
    }

    Index opUnary(string op)() const {
	Index ret = this;
	foreach(i; 0 .. indices.length)
	    ret[i] = mixin(op ~ "indices[i]");
	return ret;
    }
}

struct Region {
    Index offset, size;

    invariant() { assert(offset.length == size.length); }
    
    this(const Index offset, const Index size) {
	this.offset = offset;
	this.size = size;
    }
    
    int opApply(int delegate(Index) dg) {
	Index current = offset;
	const Index last = offset + size;

	foreach(i; current[0] .. last[0]) {
	    foreach(j; current[1] .. last[1]) {
		int ret = dg(Index(i,j));
		if (ret != 0)
		    return ret;
	    }
	}
	
	return 0;
    }
}

class Matrix {
    alias Element = double;

    const Index shape;
    private MmFile mmfile; // null if Matrix is not linked to a file
    const string filename; // null if Matrix is not linked to a file
    Element[] data_;

    this(int[2] shape) {
    	this.shape = shape;
    	this.data_ = new Element[ shape[0] * shape[1] ];

	this.mmfile = null;
	this.filename = null;
    }

    this(int[2] shape...) {
    	this(shape);
    }

    this(int[2] shape, Element[] data) {
	assert (data.length == (shape[0] * shape[1]));
    	this.shape = shape;
    	this.data_ = data;

	this.mmfile = null;
	this.filename = null;
    }
    

    this(const(char)[] filename, int[2] shape) {
	this.shape = shape;

	immutable fileSize = shape[0] * shape[1] * Element.sizeof;
	bool alreadyExisting = exists(filename);
	
	this.filename = filename.idup;
	// the last 'null' parameter lets the OS choose the address for the mapping
	this.mmfile = new MmFile(this.filename, MmFile.Mode.readWrite, fileSize, null);
	this.data_ = null;

	if (!alreadyExisting) {
	    foreach (ref x; data)
		x = Element.init;
	}
    }

    // @disable this(this);
    
    ~this() {
	mmfile.destroy();
    }

    Element[] data() {
	if (mmfile !is null)
	    return cast(Element[]) mmfile[];
	else
	    return data_;
    }
    
    private int flatIndex(int[2] index) // const
    {
	return index[0] * shape[1] + index[1];
    }
    
    Element opIndex(int[2] index ...) // const
    {
	return data[ flatIndex(index) ];
    }
    
    Element opIndex(Index index) // const
    {
	return data[ flatIndex(index.indices) ];
    }
    
    Element opIndexAssign(Element value, int index[2] ...) {
	return (data[ flatIndex(index) ] = value);
    }
    
    Element opIndexAssign(Element value, Index index) {
	return (data[ flatIndex(index.indices) ] = value);
    }
    
    Region region() const {
	return Region(Index(0, 0), this.shape);
    }

    void blit(ref Matrix src, Region srcRegion, Index whereTo) {
	debug writefln("blit %s -> %s", srcRegion, whereTo);
	Region windowReg = srcRegion;
	windowReg.offset = Index(0, 0);
	
	foreach(index; windowReg) {
	    auto dstIndex = whereTo + index;
	    auto srcIndex = srcRegion.offset + index;
	    debug writefln("writing %5s %s -> %s", src[srcIndex], srcIndex, dstIndex);
	    this[dstIndex] = src[srcIndex];
	}
    }

    void toString(scope void delegate(const(char)[]) sink) // const
    {
	sink("Matrix [\n");
	foreach(row; 0 .. shape[0]) {
	    sink("  [");
	    foreach(col; 0 .. shape[1])
		writef(" %6s", this[row, col]);
	    sink("]\n");
	}
	sink("]");
    }
}

class SparseMatrix {
    private {
	Matrix[ Index ] matrices;
	const Index blockSize;
	const string directory;
    }

    private this(const(char)[] directory, int[2] blockSize ...) {
	this.directory = directory.idup;
	this.blockSize = blockSize;
    }

    private string blockFileName(Index blockIndex) const {
	auto baseName = format("block-%08x%08x", blockIndex[0], blockIndex[1]);
	return buildPath([ this.directory, baseName ]);
    }
    
    private Matrix* getBlock(Index blockIndex) {
	Matrix* ret = (blockIndex in matrices);
	if (ret !is null)
	    return ret;

	auto filename = blockFileName(blockIndex);	
	matrices[blockIndex] = new Matrix(filename, blockSize);
	return (blockIndex in matrices);
    }

    private auto spliceBlocks(const Index offset, Index size) {
	auto p = this;
	
	struct Splicer {
	    int opApply(int delegate(Matrix *block,
				     Index offsetInBlock,
				     Index offsetInMatrix,
				     Index pieceSize) dg) {
		// these divisions are all integer divs, so all values are rounded
		// to floor
		Index startBlk = offset / p.blockSize;
		Index endBlk = (offset + size) / p.blockSize;
		Index numBlocks = endBlk - startBlk + Index(1,1);

		auto blocks = Region(startBlk, numBlocks);
		debug writeln("writing on blocks ", blocks);
		
		foreach (blockIndex; blocks) {
		    Index blockPos = blockIndex * p.blockSize;
		    Index offsetInBlk = offset - blockPos;

		    Index offsetInMat = offsetInBlk;
		    foreach(ref x; offsetInMat)
			x = max(0, -x);

		    foreach(ref x; offsetInBlk)
			x = max(0, x);
		    
		    Index pieceSize = size - offsetInMat;
		    foreach(i; 0 .. 2)
			pieceSize[i] = min(pieceSize[i],
					   p.blockSize[i] - offsetInBlk[i]);

		    debug {
			writefln("block %s @ %s x %s", blockIndex,
				 offsetInBlk, pieceSize);
		    }
		    auto block = p.getBlock(blockIndex);
		    int ret = dg(block, offsetInBlk, offsetInMat, pieceSize);
		    if (ret != 0)
			return ret;
		}
		
		return 0;
	    }
	}
	
	return Splicer();
    }
    
    Matrix get(Index offset, Index size) {
	Matrix ret = new Matrix(size);

	foreach(block, offsetInBlk, offsetInMat, pieceSize;
		spliceBlocks(offset, size))
	    {
		ret.blit(*block,
			 Region(offsetInBlk, pieceSize),
			 offsetInMat);
	    }
	
	return ret;
    }
    
    void set(ref Matrix matrix, Index whereTo) {
	foreach(block, offsetInBlk, offsetInMat, pieceSize;
		spliceBlocks(whereTo, matrix.shape))
	    {
		block.blit(matrix,
			   Region(offsetInMat, pieceSize),
			   offsetInBlk);
	    }
    }

    static SparseMatrix open(const(char)[] directory, int[2] defaultBlockSize)
    {
	if (!exists(directory)) {
	    mkdirRecurse(directory);
	} else {
	    auto attr = getAttributes(directory);
	    if (!attr.attrIsDir)
		throw new FileException(directory, "not a directory");
	}

	int[2] blockSize = defaultBlockSize;
	
	auto configFilePath = buildPath([directory, "params.json"]);
	if (!exists(configFilePath)) {
	    auto json = JSONValue(["blockSize": blockSize]);
	    auto buf = toJSON(&json, true);
	    debug writeln("Creating config: ", buf);
	    std.file.write(configFilePath, buf);
	} else {
	    auto attr = getAttributes(configFilePath);
	    if (!attr.attrIsFile)
		throw new FileException(configFilePath, "not a file");

	    auto buf = std.file.read(configFilePath);
	    auto json = buf.to!(char[]).parseJSON;
	    debug writeln("Read config: ", json);
	    auto jsonBlkSize = json["blockSize"].array;
	    blockSize[0] = jsonBlkSize[0].integer.to!int;
	    blockSize[1] = jsonBlkSize[1].integer.to!int;
	}

	return new SparseMatrix(directory, blockSize);
    }
}

// extern(C) void runTest() {
//     auto sparseMat = SparseMatrix.open("/tmp/sparse-matrix-test/", [10, 10]);

//     writeln(" --- Preparing test data");
//     Matrix matIn = new Matrix(12, 5);
//     foreach(ref elem; matIn.data)
// 	elem = uniform(0f, 15f);

//     writeln(" --- Writing to sparse matrix");
//     sparseMat.set(matIn, Index(2, 2));

//     writeln(" --- Reading some submatrix");
//     Matrix matOut = sparseMat.get(Index(7, 5), Index(5, 5));

//     writeln("IN matrix:");
//     writeln(matIn);
//     writeln();
//     writeln("OUT matrix:");
//     writeln(matOut);

//     {
// 	writeln("...... Matrix dtor check .......");
// 	auto blkIndices = sparseMat.matrices.keys;
// 	writeln(" === ", blkIndices.length, " blocks");
// 	auto victimIndex = blkIndices[ uniform(0, blkIndices.length) ];
// 	writeln(" Removing block ", victimIndex);
// 	sparseMat.matrices.remove(victimIndex);
// 	writeln("................................");
//     }
// }

