import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.functional;
import std.json;
import std.mmfile;
import std.path;
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
    
    Index opBinary(string op)(const Index rhs) inout {
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

    this(Index offset, Index size) {
        this.offset = offset;
        this.size = size;
    }
    
    int opApply(int delegate(Index) dg) {
	immutable Index last = offset + size;

        foreach(i; offset[0] .. last[0]) {
            foreach(j; offset[1] .. last[1]) {
                int ret = dg(Index(i,j));
                if (ret != 0)
                    return ret;
            }
        }
        
        return 0;
    }
}

class Matrix
{
    alias Element = double;

    abstract Index shape() const;
    abstract Element[] data();

    void lock(LockType) {}
    void unlock() {}
    
    private final int flatIndex(int[2] index) /*const*/ {
        return index[0] * shape[1] + index[1];
    }
    
    final Element opIndex(int[2] index ...) {
        return data[ flatIndex(index) ];
    }
    
    final Element opIndex(Index index) /*const*/ {
        return data[ flatIndex(index.indices) ];
    }
    
    final Element opIndexAssign(Element value, int index[2] ...) {
        return (data[ flatIndex(index) ] = value);
    }
    
    final Element opIndexAssign(Element value, Index index) {
        return (data[ flatIndex(index.indices) ] = value);
    }
    
    final Region region() const {
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

class MemoryMatrix : Matrix {
    private Element[] data_;
    private Index shape_;

    override Index shape() const { return shape_; }
    override Element[] data() { return data_; }

    this(int[2] shape, Element[] data) {
        assert (data.length == (shape[0] * shape[1]));
	shape_ = shape;
	data_ = data;
    }

    this(int[2] shape) {
        this(shape, new Element[ shape[0] * shape[1] ]);
    }

    this(int[2] shape...) {
	this(shape);
    }
}

class FileMatrix : Matrix {
    private {
        const Index shape_;
        MmFile mmfile;
        File *file;
    }
    const string filename;
    
    this(const(char)[] filename, int[2] shape) {
        this.shape_ = shape;

        immutable fileSize = shape[0] * shape[1] * Element.sizeof;
        bool alreadyExisted = exists(filename);
        
        this.filename = filename.idup;

        auto openMode = "w+";
        if (alreadyExisted)
            openMode = "r+";
        this.file = new File(this.filename, openMode);
        
        // the last 'null' parameter lets the OS choose the address for the mapping
        this.mmfile = new MmFile(*this.file, MmFile.Mode.readWrite, fileSize, null);

        if (!alreadyExisted) {
            // this actually writes into the new file (if it didn't,
            // it would be completely useless: every element in `data`
            // is already initialized to `Element.init`.)
            foreach (ref x; data)
                x = Element.init;
        }
    }

    ~this() {
	mmfile.destroy();
        debug writeln(" ~ mmfile destroyed");
    }
    
    override Element[] data() {
        return cast(Element[]) mmfile[];
    }

    override Index shape() const {
        return shape_;
    }
    
    override void lock(LockType lkType) {
        this.file.lock(lkType);
    }

    override void unlock() {
        this.file.unlock();
    }
}

class SparseMatrix {
    alias Element = Matrix.Element;
    
    private {
        FileMatrix[ Index ] matrices;
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
    
    private Matrix getBlock(Index blockIndex) {
        FileMatrix* ret = (blockIndex in matrices);
        if (ret !is null)
            return *ret;

        auto filename = blockFileName(blockIndex);        
        matrices[blockIndex] = new FileMatrix(filename, blockSize);
        return *(blockIndex in matrices);
    }

    private Index findBlock(Index offset) const {
	Index ret = offset / this.blockSize;
	// just a hack to correct the result of integer division
	// with negative arguments
	foreach(i; 0..2)
	    if (offset[i] < 0) ret[i] -= 1;
	return ret;
    }
    
    private auto spliceBlocks(const Index offset, Index size) {
	
        auto p = this;
        
        struct Splicer {
            int opApply(int delegate(ref Matrix block,
                                     Index offsetInBlock,
                                     Index offsetInMatrix,
                                     Index pieceSize) dg) {
		foreach(n; size)
		    if (n == 0)
			return 0;

		// these divisions are all integer divs, so all values are rounded
                // to floor
                Index startBlk = p.findBlock(offset);
                Index endBlk = p.findBlock(offset + size - Index(1,1));
                Index numBlocks = endBlk - startBlk + Index(1,1);

                auto blocks = Region(startBlk, numBlocks);
                debug writeln("writing on blocks ", blocks);
                
                foreach (blockIndex; blocks) {
                    Index blockPos = blockIndex * p.blockSize;
                    Index offsetInBlk = offset - blockPos;

                    Index offsetInMat = offsetInBlk;
                    foreach(ref x; offsetInMat)
                        x = max(0, x);

                    foreach(ref x; offsetInBlk)
                        x = max(0, -x);
                    
                    Index pieceSize = size - offsetInMat;
                    foreach(i; 0 .. 2)
                        pieceSize[i] = min(pieceSize[i],
                                           p.blockSize[i] - offsetInBlk[i]);

                    debug writefln("block %s @ %s x %s",
                                   blockIndex, offsetInBlk, pieceSize);

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

    final Element opIndex(int[2] index ...) {
	return opIndex(Index(index));
    }
    
    final Element opIndex(Index index) {
	auto blkIndex = this.findBlock(index);
	Index idxInBlock = index - blockSize * blkIndex;
        return getBlock(blkIndex)[idxInBlock];
    }
    
    final Element opIndexAssign(Element value, int index[2] ...) {
	return opIndexAssign(value, Index(index));
    }
    
    final Element opIndexAssign(Element value, Index index) {
	auto blkIndex = this.findBlock(index);
	Index idxInBlock = index - blockSize * blkIndex;
        return (getBlock(blkIndex)[idxInBlock] = value);
    }
    
    Matrix get(Index offset, Index size) {
        Matrix ret = new MemoryMatrix(size);

        foreach(block, offsetInBlk, offsetInMat, pieceSize;
                spliceBlocks(offset, size))
            {
                ret.lock(LockType.read);
                ret.blit(block,
                         Region(offsetInBlk, pieceSize),
                         offsetInMat);
                ret.unlock();
            }
        
        return ret;
    }
    
    void set(ref Matrix matrix, Index whereTo) {
        foreach(block, offsetInBlk, offsetInMat, pieceSize;
                spliceBlocks(whereTo, matrix.shape))
            {
                block.lock(LockType.readWrite);
                block.blit(matrix,
                           Region(offsetInMat, pieceSize),
                           offsetInBlk);
                block.unlock();
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

/+
 void main() {
 auto mat = new FileMatrix("test-file-matrix", [10, 20]);

 writeln(mat.data);
 foreach(ref x; mat.data) {
 x = uniform(0f, 15f);
 }
    
 // auto sparseMat = SparseMatrix.open("/tmp/sparse-matrix-test/", [10, 10]);

 // writeln(" --- Preparing test data");
 // Matrix matIn = new MemoryMatrix(12, 5);
 // foreach(ref elem; matIn.data)
 //         elem = uniform(0f, 15f);

 // writeln(" --- Writing to sparse matrix");
 // sparseMat.set(matIn, Index(2, 2));

 // writeln(" --- Reading some submatrix");
 // Matrix matOut = sparseMat.get(Index(7, 5), Index(5, 5));

 // writeln("IN matrix:");
 // writeln(matIn);
 // writeln();
 // writeln("OUT matrix:");
 // writeln(matOut);

 // {
 //         writeln("...... Matrix dtor check .......");
 //         auto blkIndices = sparseMat.matrices.keys;
 //         writeln(" === ", blkIndices.length, " blocks");
 //         auto victimIndex = blkIndices[ uniform(0, blkIndices.length) ];
 //         writeln(" Removing block ", victimIndex);
 //         sparseMat.matrices.remove(victimIndex);
 //         writeln("................................");
 // }
 }
 +/
