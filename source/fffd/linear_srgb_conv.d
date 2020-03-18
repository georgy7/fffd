module fffd.linear_srgb_conv;

import std.math;
import mir.ndslice.slice;

private auto srgbToLinear(float cbNumber) @safe
{
    assert(cbNumber >= 0.0);
    assert(cbNumber <= 255.0);

    auto c = cbNumber / 255.0;

    assert(c >= 0.0);
    assert(c <= 1.0);

    auto a = 0.055;
    if (c <= 0.04045)
    {
        return c / 12.92;
    }
    else
    {
        auto result = pow((c + a) / (1 + a), 2.4);

        assert(result >= 0.0);
        assert(result <= 1.0);

        return result;
    }
}

private float floatToByte(float a) @safe
{
    import std.algorithm.comparison;
    return max(min(round(255.0 * a), 255.0), 0.0);
}

float linearToSrgbGammaCorrection(float lin) pure nothrow @safe
{
    auto a = 0.055;
    if (lin <= 0.0031308) {
        return lin * 12.92;
    } else {
        return pow(lin, 1.0 / 2.4) * (1 + a) - a;
    }
}

float linearToSrgb(float lin)
{
    return floatToByte(linearToSrgbGammaCorrection(lin));
}

Slice!(float*, 3) toLinear(Slice!(float*, 3) rgba)
{
    import std.range;

    auto rows = rgba.length!0;
    auto columns = rgba.length!1;
    auto result = repeat(0f, (rows * columns * 4)).array.sliced(rows, columns, 4);

    foreach (i; 0 .. rows)
    foreach (j; 0 .. columns)
    {
        result[i][j][0] = srgbToLinear(rgba[i][j][0]);
        result[i][j][1] = srgbToLinear(rgba[i][j][1]);
        result[i][j][2] = srgbToLinear(rgba[i][j][2]);
        result[i][j][3] = rgba[i][j][3] / 255.0;
    }

    return result;
}

Slice!(float*, 3) fromLinear(Slice!(float*, 3) linearRgba)
{
    import std.range;

    auto rows = linearRgba.length!0;
    auto columns = linearRgba.length!1;
    auto result = repeat(0f, (rows * columns * 4)).array.sliced(rows, columns, 4);

    foreach (i; 0 .. rows)
    foreach (j; 0 .. columns)
    {
        result[i][j][0] = linearToSrgb(linearRgba[i][j][0]);
        result[i][j][1] = linearToSrgb(linearRgba[i][j][1]);
        result[i][j][2] = linearToSrgb(linearRgba[i][j][2]);
        result[i][j][3] = floatToByte(linearRgba[i][j][3]);
    }

    return result;
}
