module fffd.xyz;

import fffd.bit_utils;

import std.bitmanip;
import mir.ndslice;
import fffd.adjacent_matrix_holder : Offset;

class Xyz
{
    private Slice!(float*, 2) yXYZ;
    private Slice!(float*, 2) xXYZ;
    private Slice!(float*, 2) zXYZ;

    this(Slice!(float*, 2) yXYZ, Slice!(float*, 2) xXYZ, Slice!(float*, 2) zXYZ) @safe
    {
        this.yXYZ = yXYZ;
        this.xXYZ = xXYZ;
        this.zXYZ = zXYZ;
    }

    ~this()
    {
    }

    const @property @safe size_t length(size_t dimension)()
    {
        return yXYZ.length!dimension;
    }

    const BitMap makeEqualityMasks(ubyte kernelMargin, float yThreshold, in Offset[] offsets) @safe
    {
        import std.conv;
        import std.algorithm;

        import mir.algorithm.iteration;
        import std.math;

        const int h = to!int(this.length!0);
        const int w = to!int(this.length!1);

        BitMap result = new BitMap(h, w, kernelMargin);

        alias maxVal = (a) => mir.algorithm.iteration.reduce!fmax(-float.infinity, a);
        alias minVal = (a) => mir.algorithm.iteration.reduce!fmin(float.infinity, a);

        assert(minVal(this.yXYZ) >= 0.0);
        assert(minVal(this.xXYZ) >= 0.0);
        assert(minVal(this.zXYZ) >= 0.0);

        assert(maxVal(this.yXYZ) <= 1.0);
        assert(maxVal(this.xXYZ) <= 1.0);
        assert(maxVal(this.zXYZ) <= 1.089);

        foreach (y; 0 .. h)
        {
            foreach (x; 0 .. w)
            {
                foreach (offsetIndex; 0 .. offsets.length)
                {
                    const Offset offset = offsets[offsetIndex];

                    if ((0 == offset.y) && (0 == offset.x))
                    {
                        continue;
                    }

                    int outboundY2 = y - offset.y;
                    int outboundX2 = x - offset.x;

                    int yToCompare = min(max(0, outboundY2), (h - 1));
                    int xToCompare = min(max(0, outboundX2), (w - 1));

                    bool invertLightness = (outboundY2 != yToCompare) != (outboundX2 != xToCompare); // logical XOR

                    if (this.eq(y, x, yToCompare, xToCompare, yThreshold, invertLightness))
                    {
                        result.setTrue(y, x, to!int(offsetIndex));
                    }

                }
            }
        }

        return result;
    }

    const bool eq(in int y, in int x, in int y2, in int x2, in float yThreshold,
            in bool invertLightness) @safe
    {
        import std.math;

        const int chromaThresholdFactor = 4;
        const float tf = yThreshold * chromaThresholdFactor;

        const float l2 = this.yXYZ[y2, x2];
        const float probablyInvertedLightness = invertLightness ? (-l2) : l2;
        const bool yEqual = abs(this.yXYZ[y, x] - probablyInvertedLightness) < yThreshold;

        const auto xd = abs(this.xXYZ[y, x] - this.xXYZ[y2, x2]);
        const auto zd = abs(this.zXYZ[y, x] - this.zXYZ[y2, x2]);

        return yEqual && ((xd < tf && zd < tf) // Close chroma.
                 || (this.yXYZ[y, x] <= (25.0f / 255.0f) || this.yXYZ[y2, x2] <= (25.0f / 255.0f)) // Both too dark.
                 || ((this.yXYZ[y, x] > 0.5f || this.yXYZ[y2, x2] > 0.5f)
                && (xd < tf * 2) && (zd < tf * 2)) // Both bright and a little close chroma.
        );
    }
}

/**
  * White is not very important for this filter.
*/
private float whiteLoweringFunction(float gammaCorrectedLuma) pure nothrow @safe
{
    auto t = 0.7;
    if (gammaCorrectedLuma > t)
    {
        return gammaCorrectedLuma - gammaCorrectedLuma * 0.25 * ((gammaCorrectedLuma - t) / (1 - t));
    }
    else
    {
        return gammaCorrectedLuma;
    }
}

Xyz xyzFromLinearRgba(Slice!(float*, 3) linearRgba) @safe
{
    import fffd.linear_srgb_conv;

    Slice!(float*, 2) y = slice!float(linearRgba.length!0, linearRgba.length!1);
    Slice!(float*, 2) x = slice!float(linearRgba.length!0, linearRgba.length!1);
    Slice!(float*, 2) z = slice!float(linearRgba.length!0, linearRgba.length!1);

    auto r = linearRgba[0 .. $, 0 .. $, 0];
    auto g = linearRgba[0 .. $, 0 .. $, 1];
    auto b = linearRgba[0 .. $, 0 .. $, 2];

    y[] = r * 0.2126;
    y[] += g * 0.7152;
    y[] += b * 0.0722;
    y.each!((ref a) { a = whiteLoweringFunction(linearToSrgbGammaCorrection(a)); });

    x[] = r * 0.4124;
    x[] += g * 0.3576;
    x[] += b * 0.1805;

    z[] = r * 0.0193;
    z[] += g * 0.1192;
    z[] += b * 0.9505;

    return new Xyz(y, x, z);
}

version (unittest)
{
    import fffd.flood;
    import fffd.adjacent_matrix_holder;

    import fluentasserts.core.base;
    import std.path : buildPath;

    import std.conv;
    import std.stdio;
    import std.csv;
    import std.typecons;
    import std.format;

    void makeEqualityMasksTest(string csvString, string csvOffsets, Slice!(float*, 3) linearRgba) @safe
    {
        const int kernelMargin = 4;
        const int kernelDiameter = kernelMargin + 1 + kernelMargin;

        const auto adjacencyMartixHolder = new AdjacentMatrixHolder(kernelMargin);
        const Xyz xyz = xyzFromLinearRgba(linearRgba);

        const Offset[] offsets = adjacencyMartixHolder.getOffsets();
        const BitMap equalityMasks = xyz.makeEqualityMasks(kernelMargin, 0.08, offsets);

        Offset[] csvOffsetList = [];

        foreach (record; csvReader!(Tuple!(int, int))(csvOffsets))
        {
            Offset offset = {y:
            record[0], x : record[1]};
            csvOffsetList ~= offset;
        }

        int counter = 0;

        foreach (record; csvReader!(Tuple!(int))(csvString))
        {
            const int yx = counter / (kernelDiameter * kernelDiameter);
            const int csvOffsetIndex = counter % (kernelDiameter * kernelDiameter);
            const Offset csvOffset = csvOffsetList[csvOffsetIndex];
            const int y = yx / 195;
            const int x = yx % 195;

            int theValueFromCsv = record[0];

            Bitmask mask = equalityMasks[y, x];

            int maskOffsetIndex = 0;
            foreach (i; 0 .. offsets.length)
            {
                Offset o = offsets[i];
                if ((o.y == csvOffset.y) && (o.x == csvOffset.x))
                {
                    maskOffsetIndex = to!int(i);
                }
            }

            if (1 == theValueFromCsv)
            {
                isSet(mask, maskOffsetIndex).should.equal(true,
                        format("(%d, %d), csvOffsetIndex = %d, maskOffsetIndex = %d, offset = (%d, %d), mask = %s.",
                            y, x, csvOffsetIndex, maskOffsetIndex, csvOffset.y,
                            csvOffset.x, mask.toBinaryString()));
            }
            else
            {
                isSet(mask, maskOffsetIndex).should.equal(false,
                        format("(%d, %d), csvOffsetIndex = %d, maskOffsetIndex = %d, offset = (%d, %d), mask = %s.",
                            y, x, csvOffsetIndex, maskOffsetIndex, csvOffset.y,
                            csvOffset.x, mask.toBinaryString()));
            }

            counter++;
        }

        counter.should.equal(136 * 195 * kernelDiameter * kernelDiameter);
        writeln("Test - makeEqualityMasks: Ok.");
    }

    unittest
    {
        import std.file;
        import std.zlib;

        const string folder = "samples3";
        (exists(folder) && isDir(folder)).should.equal(true);

        auto decompressor = new UnCompress();
        const(void)[] uncompressed = decompressor.uncompress(read(buildPath(folder,
                "xm20_eq.csv.gz")));
        decompressor.empty.should.equal(true);

        string csvOffsets = to!string(read(buildPath(folder, "xm20_eq_offsets.csv")));

        auto linear = readLinear(buildPath(folder, "xm20.bmp"));

        makeEqualityMasksTest(to!string(uncompressed), csvOffsets, linear);
    }
}
