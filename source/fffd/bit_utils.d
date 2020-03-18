module fffd.bit_utils;

struct Bitmask
{
    ulong[2] a;
}

pure Bitmask or(immutable Bitmask m, immutable Bitmask n) @safe nothrow @nogc
{
    Bitmask result;
    result.a[0] = m.a[0] | n.a[0];
    result.a[1] = m.a[1] | n.a[1];
    return result;
}

pure Bitmask and(immutable Bitmask m, immutable Bitmask n) @safe nothrow @nogc
{
    Bitmask result;
    result.a[0] = m.a[0] & n.a[0];
    result.a[1] = m.a[1] & n.a[1];
    return result;
}

pure Bitmask not(immutable Bitmask m) @safe nothrow @nogc
{
    Bitmask result;
    result.a[0] = ~m.a[0];
    result.a[1] = ~m.a[1];
    return result;
}

pure bool notZero(immutable Bitmask m) @safe nothrow @nogc
{
    return (m.a[0] != 0x0) || (m.a[1] != 0x0);
}

pure int bitCount(immutable ulong input) @safe nothrow @nogc
{
    int result = 0;
    ulong bit = 1;
    foreach (i; 0 .. 64)
    {
        if ((input & bit) != 0)
        {
            result++;
        }
        bit *= 2;
    }
    return result;
}

pure int bitCount(immutable Bitmask m) @safe nothrow @nogc
{
    return bitCount(m.a[0] + m.a[1]);
}

private ulong[] makeBitArray64() @safe
{
    ulong[] result = new ulong[64];

    ulong bit = 0b1UL;
    result[0] = bit;

    static foreach (i; 1 .. 64)
    {
        bit *= 2;
        result[i] = bit;
    }

    return result;
}

private enum bits = makeBitArray64();

void setTrue(ref Bitmask m, in int index) @safe nothrow
{
    const int aIndex = index / 64;
    m.a[aIndex] |= bits[index % 64];
}

void setFalse(ref Bitmask m, in int index) @safe nothrow
{
    const int aIndex = index / 64;
    m.a[aIndex] &= (~bits[index % 64]);
}

bool isSet(in Bitmask m, in int index) @safe nothrow
{
    const int aIndex = index / 64;
    return m.a[aIndex] == (m.a[aIndex] | bits[index % 64]);
}

pure string toBinaryString(in Bitmask m) @safe
{
    import std.conv;
    import std.format;
    return format("%064b %064b", m.a[0], m.a[1]);
}

class BitMap
{
    private Bitmask[] data;
    private immutable int h;
    private immutable int w;

    this(int h, int w, ubyte kernelMargin) @safe
    {
        assert(h > 0);
        assert(w > 0);

        assert(kernelMargin > 0);

        immutable int kernelWidth = kernelMargin + 1 + kernelMargin;
        assert((kernelWidth * kernelWidth) <= 128);

        this.data = new Bitmask[w * h];
        this.h = h;
        this.w = w;
    }

    const Bitmask opIndex(in int y, in int x) @safe pure @nogc
    {
        return data[this.w * y + x];
    }

    const int getH() @safe pure @nogc
    {
        return this.h;
    }

    const int getW() @safe pure @nogc
    {
        return this.w;
    }

    void setTrue(in int y, in int x, in int index) @safe
    {
        data[this.w * y + x].setTrue(index);
    }
}

unittest
{
    int h = 3;
    int w = 5;
    auto bitmap = new BitMap(h, w, 5);

    import fluentasserts.core.base;
    import std.stdio;

    foreach (y; 0 .. h)
    {
        foreach (x; 0 .. w)
        {
            Bitmask mask = bitmap[y, x];
            mask.a[0] = mask.a[0] | 0x1;
            mask.a[1] = mask.a[1] | 0x10;
            (mask.a[0] | mask.a[1]).should.equal(0x11UL);
        }
    }

    writeln("Test - BitMap indexing: Ok.");
}

unittest
{
    import fluentasserts.core.base;
    import std.stdio;

    bitCount(0).should.equal(0);
    bitCount(0b01).should.equal(1);
    bitCount(0b10).should.equal(1);
    bitCount(0b11).should.equal(2);
    bitCount(0b100011).should.equal(3);
    writeln("Test - bitCount(ulong): Ok.");
}

unittest
{
    import fluentasserts.core.base;
    import std.stdio;

    Bitmask mask;
    mask.a[0] = 0b11;
    mask.a[1] = 0x10;
    bitCount(mask).should.equal(3);

    writeln("Test - bitCount(Bitmask): Ok.");
}

unittest
{
    import fluentasserts.core.base;
    import std.stdio;

    Bitmask mask;
    mask.setTrue(2);
    mask.a[0].should.equal(0b100UL);
    mask.a[1].should.equal(0b0UL);

    writeln("Test - setTrue1: Ok.");
}

unittest
{
    import fluentasserts.core.base;
    import std.stdio;

    Bitmask mask;
    mask.setTrue(64);
    mask.a[0].should.equal(0b0UL);
    mask.a[1].should.equal(0b1UL);

    writeln("Test - setTrue2: Ok.");
}

unittest
{
    import fluentasserts.core.base;
    import std.stdio;

    Bitmask mask;
    mask.setTrue(0);
    mask.setTrue(1);
    mask.setFalse(1);
    mask.setTrue(3);
    mask.setFalse(4);
    mask.a[0].should.equal(0b1001UL);
    mask.a[1].should.equal(0b0UL);
    writeln("Test - setTrue, setFalse: Ok.");
}

unittest
{
    import fluentasserts.core.base;
    import std.stdio;

    Bitmask mask;
    mask.setTrue(2);
    mask.isSet(0).should.equal(false);
    mask.isSet(1).should.equal(false);
    mask.isSet(2).should.equal(true);

    foreach (i; 3 .. 64) {
        mask.isSet(i).should.equal(false);
    }

    writeln("Test - isSet1: Ok.");
}

unittest
{
    import fluentasserts.core.base;
    import std.stdio;

    Bitmask mask;
    mask.setTrue(50);

    foreach (i; 0 .. 50) {
        mask.isSet(i).should.equal(false);
    }

    mask.isSet(50).should.equal(true);

    foreach (i; 51 .. 64) {
        mask.isSet(i).should.equal(false);
    }

    writeln("Test - isSet2: Ok.");
}
