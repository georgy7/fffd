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

module fffd.linear_srgb_conv;

import std.math;
import mir.ndslice;

import std.parallelism;
import std.range : iota;
import imageformats;

private pure auto srgbToLinear(float cbNumber) @safe nothrow @nogc
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

Slice!(float*, 3) toLinear(IFImage rgba8)
{
    import std.range;

    Slice!(float*, 3) result = slice!float(rgba8.h, rgba8.w, 4);

    foreach (y; parallel(iota(0, rgba8.h)))
    {
        foreach (x; 0 .. rgba8.w)
        {
            const auto index = (y * rgba8.w + x) * 4;
            result[y, x, 0] = srgbToLinear(rgba8.pixels[index]);
            result[y, x, 1] = srgbToLinear(rgba8.pixels[index + 1]);
            result[y, x, 2] = srgbToLinear(rgba8.pixels[index + 2]);
            result[y, x, 3] = rgba8.pixels[index + 3] / 255.0;
        }
    }

    return result;
}

// The interface for tests.
Slice!(float*, 3) toLinear(Slice!(float*, 3) rgba)
{
    import std.conv;

    auto height = to!int(rgba.length!0);
    auto width = to!int(rgba.length!1);

    auto buffer = new ubyte[height * width * 4];

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. width)
        {
            const auto index = (y * width + x) * 4;
            buffer[index] = to!ubyte(rgba[y, x, 0]);
            buffer[index + 1] = to!ubyte(rgba[y, x, 1]);
            buffer[index + 2] = to!ubyte(rgba[y, x, 2]);
            buffer[index + 3] = to!ubyte(rgba[y, x, 3]);
        }
    }

    IFImage image = {
        w      : width,
        h      : height,
        c      : ColFmt.RGBA,
        pixels : buffer,
    };

    return toLinear(image);
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
        result[i, j, 0] = linearToSrgb(linearRgba[i, j, 0]);
        result[i, j, 1] = linearToSrgb(linearRgba[i, j, 1]);
        result[i, j, 2] = linearToSrgb(linearRgba[i, j, 2]);
        result[i, j, 3] = floatToByte(linearRgba[i, j, 3]);
    }

    return result;
}
