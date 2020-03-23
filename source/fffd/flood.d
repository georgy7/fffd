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

module fffd.flood;

import mir.ndslice;
import imageformats;
import fffd.linear_srgb_conv;
import fffd.xyz;
import fffd.bit_utils;
import fffd.adjacent_matrix_holder;

import std.parallelism;
import std.range : iota;

import std.conv;
import std.algorithm.searching : endsWith;
import std.uni : toLower;

Slice!(float*, 3) readLinear(string filePath)
{
    //import core.time : MonoTime;
    //import std.stdio;
    //import std.format;
    //import std.conv;

    //MonoTime before = MonoTime.currTime;
    IFImage im = read_image(filePath, ColFmt.RGBA);
    //MonoTime after = MonoTime.currTime;
    //writeln(format("Image loaded in %s", to!string(after - before)));

    return toLinear(im);
}

private pure int lrtb(in int coordinate, in int size, in ubyte kernel_margin) @safe
{
    import std.algorithm;

    const int a = max(0, coordinate - kernel_margin);
    const int b = min(size - 1, coordinate + kernel_margin);
    return (1 + b - a);
}

private void filterInner(in BitMap equalityMasks, in ubyte kernelMargin,
        in AdjacentMatrixHolder adjacencyMartixHolder, in float ratioThreshold,
        Slice!(bool*, 2) result)
{
    import std.conv;

    immutable Bitmask originMask = adjacencyMartixHolder.getOriginMask();
    immutable Bitmask notOriginMask = adjacencyMartixHolder.getNotOriginMask();

    immutable int h = equalityMasks.getH();
    immutable int w = equalityMasks.getW();

    foreach (y; parallel(iota(0, h)))
    {
        const int yi = y;

        int tb = lrtb(y, h, kernelMargin);

        foreach (x; 0 .. w)
        {
            int countThreshold = to!int((lrtb(x, w, kernelMargin) * tb - 1) * ratioThreshold);

            Bitmask filledOffsets;
            int filledOffsetsCount = 0;

            Bitmask previousFillingIterationResult = originMask;

            Bitmask eqMask = equalityMasks[yi, x];

            while ((filledOffsetsCount <= countThreshold)
                    && previousFillingIterationResult.nonZero())
            {
                const Bitmask orResult = adjacencyMartixHolder.getOrResult(
                        previousFillingIterationResult);
                const Bitmask whatToFillNext = and(orResult, not(and(notOriginMask, filledOffsets)));

                previousFillingIterationResult = and(whatToFillNext, eqMask);
                filledOffsets = or(filledOffsets, previousFillingIterationResult);
                filledOffsetsCount = bitCount(filledOffsets);
            }

            result[yi, x] = filledOffsetsCount > countThreshold;
        }

    }
}

BoolMatrix filter(Slice!(float*, 3) linearRgba, float yThreshold,
        ubyte kernelMargin, float ratioThreshold, bool denoise)
{
    Xyz originalImage = xyzFromLinearRgba(linearRgba);
    BoolMatrix firstPass = onePass(originalImage, yThreshold, kernelMargin, ratioThreshold);

    if (denoise)
    {
        Xyz firstPassXyz = new Xyz(firstPass);
        BoolMatrix secondPass = onePass(firstPassXyz, 0.08, 4, 0.05);

        Slice!(bool*, 2) result = slice!bool(secondPass.length!0, secondPass.length!1);
        result[] = firstPass | (secondPass.map!"!a");

        return result.idup;
    }
    else
    {
        return firstPass;
    }
}

BoolMatrix onePass(Xyz xyz, float yThreshold, ubyte kernelMargin, float ratioThreshold)
{
    assert(xyz !is null);

    assert(ratioThreshold > 0.0);
    assert(ratioThreshold < 1.0);

    const AdjacentMatrixHolder adjacencyMartixHolder = new AdjacentMatrixHolder(kernelMargin);

    const BitMap equalityMasks = xyz.makeEqualityMasks(kernelMargin,
            yThreshold, adjacencyMartixHolder.getOffsets());

    Slice!(bool*, 2) floodFillResult = slice!bool(xyz.length!0, xyz.length!1);

    filterInner(equalityMasks, kernelMargin, adjacencyMartixHolder,
            ratioThreshold, floodFillResult);

    return floodFillResult.idup;
}

private bool hasExtensionOfSupportedFormatsToWriteInRgbOnly(in string filename)
{
    return filename.toLower().endsWith(".bmp");
}

private bool hasExtensionOfSupportedFormatsToWriteInY(in string filename)
{
    return filename.toLower().endsWith(".tga");
}

private auto buildRgb(immutable BoolMatrix boolMatrix) @safe
{
    auto height = to!int(boolMatrix.length!0);
    auto width = to!int(boolMatrix.length!1);

    auto buffer = new ubyte[height * width * 3];

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. width)
        {
            const auto index = (y * width + x) * 3;

            if (boolMatrix[y, x])
            {
                buffer[index] = cast(ubyte)255;
                buffer[index + 1] = cast(ubyte)255;
                buffer[index + 2] = cast(ubyte)255;
            }
            else
            {
                buffer[index] = cast(ubyte)0;
                buffer[index + 1] = cast(ubyte)0;
                buffer[index + 2] = cast(ubyte)0;
            }
        }
    }

    return buffer;
}

private auto buildY(immutable BoolMatrix boolMatrix) @safe
{
    auto height = to!int(boolMatrix.length!0);
    auto width = to!int(boolMatrix.length!1);

    auto buffer = new ubyte[height * width];

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. width)
        {
            const auto index = y * width + x;

            if (boolMatrix[y, x])
            {
                buffer[index] = cast(ubyte)255;
            }
            else
            {
                buffer[index] = cast(ubyte)0;
            }
        }
    }

    return buffer;
}

void save(immutable BoolMatrix boolMatrix, in string filename)
{
    //import core.time : MonoTime;
    //import std.stdio;
    //import std.format;
    //
    //MonoTime before = MonoTime.currTime;

    auto height = to!int(boolMatrix.length!0);
    auto width = to!int(boolMatrix.length!1);

    if (hasExtensionOfSupportedFormatsToWriteInRgbOnly(filename))
    {
        auto buffer = buildRgb(boolMatrix);
        write_image(filename, width, height, buffer, ColFmt.RGB);
    }
    else if (hasExtensionOfSupportedFormatsToWriteInY(filename))
    {
        auto buffer = buildY(boolMatrix);
        write_image(filename, width, height, buffer, ColFmt.Y);
    }
    else
    {
        // To support files both with extension and without it.
        auto buffer = buildY(boolMatrix);
        write_png(filename, width, height, buffer, ColFmt.Y);
    }

    //MonoTime after = MonoTime.currTime;
    //writeln(format("Image saved in %s", to!string(after - before)));
}
