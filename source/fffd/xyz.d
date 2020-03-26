/*
    fffd - edge bunches detection tool.
    Copyright (C) 2020  Georgy Ustinov  <georgy.ustinov.hello@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

module fffd.xyz;

import fffd.bit_utils;

import std.bitmanip;
import mir.ndslice;
import fffd.adjacent_matrix_holder : Offset;
import std.typecons;

alias BoolMatrix = Slice!(immutable(bool)*, 2);

class Xyz
{
    private const Nullable!(BoolMatrix) boolLightness;
    private const Nullable!(Slice!(immutable(float)*, 2)) yXYZ;
    private const Nullable!(Slice!(immutable(float)*, 2)) xXYZ;
    private const Nullable!(Slice!(immutable(float)*, 2)) zXYZ;

    this(BoolMatrix boolLightness) @safe
    {
        this.boolLightness = boolLightness;
        this.yXYZ = Nullable!(Slice!(immutable(float)*, 2)).init;
        this.xXYZ = Nullable!(Slice!(immutable(float)*, 2)).init;
        this.zXYZ = Nullable!(Slice!(immutable(float)*, 2)).init;
    }

    this(Slice!(float*, 2) yXYZ, Slice!(float*, 2) xXYZ, Slice!(float*, 2) zXYZ) @safe
    {
        this.boolLightness = Nullable!(BoolMatrix).init;
        this.yXYZ = yXYZ.idup;
        this.xXYZ = xXYZ.idup;
        this.zXYZ = zXYZ.idup;
    }

    ~this()
    {
    }

    const @property @safe size_t length(size_t dimension)()
    {
        if (this.yXYZ.isNull)
        {
            return this.boolLightness.get.length!dimension;
        }
        else
        {
            return this.yXYZ.get.length!dimension;
        }
    }

    private const immutable(Tuple!(int, Offset, int, Offset))[] makeOffsetsWithReverse(immutable Tuple!(int, Offset)[] iOffsets)
    {
        import std.algorithm;
        import std.array : array;

        immutable(Tuple!(int, Offset, int, Offset))[] result = [];

        foreach (a; iOffsets)
        {
            auto reverseOffset = iOffsets.filter!(r => (a[1].y == -r[1].y) && (a[1].x == -r[1].x)).array[0];
            result ~= immutable(Tuple!(int, Offset, int, Offset))(a[0], a[1], reverseOffset[0], reverseOffset[1]);
        }

        return result;
    }

    const BitMap makeEqualityMasks(in ubyte kernelMargin, in float yThreshold, in Offset[] offsets)
    {
        import std.conv;
        import std.algorithm;

        import mir.algorithm.iteration;
        import std.math;
        import std.parallelism;
        import std.range : iota, enumerate;
        import std.array : array;

        const int h = to!int(this.length!0);
        const int w = to!int(this.length!1);

        BitMap result = new BitMap(h, w, kernelMargin);

        immutable Tuple!(int, Offset)[] iOffsets = offsets.enumerate
                .filter!(iOffset => (0 != iOffset[1].y) || (0 != iOffset[1].x))
                .map!(iOffset => immutable(Tuple!(int, Offset))(to!int(iOffset[0]), iOffset[1]))
                .array;

        const auto xThreshold1 = min(kernelMargin + 1, w);
        const auto xThreshold2 = max(xThreshold1, w - 1 - kernelMargin);

        foreach (y; parallel(iota(0, h)))
        {
            if ((y <= kernelMargin) || (y >= h - 1 - kernelMargin))
            {
                foreach (x; 0 .. w)
                {
                    foreach (iOffset; iOffsets)
                    {
                        const int outboundY2 = y - iOffset[1].y;
                        const int outboundX2 = x - iOffset[1].x;

                        const int yToCompare = min(max(0, outboundY2), (h - 1));
                        const int xToCompare = min(max(0, outboundX2), (w - 1));

                        const bool invertLightness = (outboundY2 != yToCompare) != (outboundX2 != xToCompare); // logical XOR

                        if (this.eq(y, x, yToCompare, xToCompare, yThreshold, invertLightness))
                        {
                            result.setTrue(y, x, iOffset[0]);
                        }
                    }
                }
            }
            else
            {
                foreach (x; 0 .. xThreshold1)
                {
                    foreach (iOffset; iOffsets)
                    {
                        const int yToCompare = y - iOffset[1].y;
                        const int outboundX2 = x - iOffset[1].x;

                        const int xToCompare = min(max(0, outboundX2), (w - 1));
                        const bool invertLightness = (outboundX2 != xToCompare);

                        if (this.eq(y, x, yToCompare, xToCompare, yThreshold, invertLightness))
                        {
                            result.setTrue(y, x, iOffset[0]);
                        }

                    }
                }

                foreach (x; xThreshold1 .. xThreshold2)
                {
                    foreach (iOffset; iOffsets)
                    {
                        const int yToCompare = y - iOffset[1].y;
                        const int xToCompare = x - iOffset[1].x;

                        if (this.eq(y, x, yToCompare, xToCompare, yThreshold, false))
                        {
                            result.setTrue(y, x, iOffset[0]);
                        }
                    }
                }

                foreach (x; xThreshold2 .. w)
                {
                    foreach (iOffset; iOffsets)
                    {
                        const int yToCompare = y - iOffset[1].y;
                        const int outboundX2 = x - iOffset[1].x;

                        const int xToCompare = min(max(0, outboundX2), (w - 1));
                        const bool invertLightness = (outboundX2 != xToCompare);

                        if (this.eq(y, x, yToCompare, xToCompare, yThreshold, invertLightness))
                        {
                            result.setTrue(y, x, iOffset[0]);
                        }

                    }
                }

            }
        }

        version (unittest)
        {
            immutable Tuple!(int, Offset, int, Offset)[] iOffsetsWithReverse = makeOffsetsWithReverse(iOffsets);

            foreach (y; 0 .. h)
            {
                if ((y <= kernelMargin) || (y >= h - 1 - kernelMargin))
                {
                    continue;
                }

                foreach (x; xThreshold1 .. xThreshold2)
                {
                    foreach (iOffsetWithReverse; iOffsetsWithReverse)
                    {
                        const int yToCompare = y - iOffsetWithReverse[1].y;
                        const int xToCompare = x - iOffsetWithReverse[1].x;

                        auto s1 = result[y, x].isSet(iOffsetWithReverse[0]);
                        auto s2 = result[yToCompare, xToCompare].isSet(iOffsetWithReverse[2]);

                        assert(s1 == s2, format("%d %d", y, x));
                    }
                }
            }
        }

        return result;
    }

    const pure bool eq(in int y, in int x, in int y2, in int x2, in float yThreshold,
            in bool invertLightness) @safe nothrow @nogc
    {
        import std.math;

        if (this.yXYZ.isNull)
        {
            if (invertLightness)
            {
                return this.boolLightness[y, x] != this.boolLightness[y2, x2];
            }
            else
            {
                return this.boolLightness[y, x] == this.boolLightness[y2, x2];
            }
        }

        const auto yy = this.yXYZ[y, x];
        const auto yy2 = this.yXYZ[y2, x2];

        const float probablyInvertedLightness = invertLightness ? (-yy2 + 1.0) : yy2;
        const bool yEqual = abs(yy - probablyInvertedLightness) < yThreshold;

        if (!yEqual) {
            return false;
        }

        const auto xx = this.xXYZ[y, x];
        const auto zz = this.zXYZ[y, x];

        const auto xx2 = this.xXYZ[y2, x2];
        const auto zz2 = this.zXYZ[y2, x2];

        const int chromaThresholdFactor = 4;
        const float tf = yThreshold * chromaThresholdFactor;

        const auto xd = abs(xx - xx2);
        const auto zd = abs(zz - zz2);

        return ((xd < tf && zd < tf) // Close chroma.
                 || (yy <= (25.0f / 255.0f) || yy2 <= (25.0f / 255.0f)) // Both too dark.
                 || ((yy > 0.5f || yy2 > 0.5f) && (xd < tf * 2) && (zd < tf * 2)) // Both bright and a little close chroma.
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

    void makeEqualityMasksTest(string csvString, string csvOffsets, Slice!(float*, 3) linearRgba)
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

            assert(maskOffsetIndex >= 0);
            assert(maskOffsetIndex <= 127);

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
