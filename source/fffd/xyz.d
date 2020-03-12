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

    BitMap makeEqualityMasks(ubyte kernelMargin, float yThreshold, Offset[] offsets) @safe
    {
        import std.conv;
        import std.algorithm;

        const int h = to!int(this.length!0);
        const int w = to!int(this.length!1);

        BitMap result = new BitMap(h, w, kernelMargin);

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

                    int yToCompare = max(min(0, y + offset.y), (h - 1));
                    int xToCompare = max(min(0, x + offset.x), (w - 1));

                    if (this.eq(y, x, yToCompare, xToCompare, yThreshold))
                    {
                        result.setTrue(y, x, to!int(offsetIndex));
                    }

                }
            }
        }

        return result;
    }

    const bool eq(in int y, in int x, in int y2, in int x2, float yThreshold) @safe
    {
        import std.math;

        const int chromaThresholdFactor = 4;
        const float tf = yThreshold * chromaThresholdFactor;

        const bool yEqual = abs(this.yXYZ[y, x] - this.yXYZ[y2, x2]) < yThreshold;

        const auto xd = abs(this.xXYZ[y, x] - this.xXYZ[y2, x2]);
        const auto zd = abs(this.zXYZ[y, x] - this.zXYZ[y2, x2]);

        return yEqual && (
            (xd < tf && zd < tf)    // Close chroma.
            ||
            (this.yXYZ[y, x] <= (25.0f / 255.0f) || this.yXYZ[y2, x2] <= (25.0f / 255.0f))  // Both too dark.
            ||
            ((this.yXYZ[y, x] > 0.5f || this.yXYZ[y2, x2] > 0.5f) && (xd < tf * 2) && (zd < tf * 2))  // Both bright and a little close chroma.
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
