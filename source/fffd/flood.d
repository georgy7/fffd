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
import dlib.image;
import fffd.linear_srgb_conv;
import fffd.xyz;
import fffd.bit_utils;
import fffd.adjacent_matrix_holder;

import std.parallelism;
import std.range : iota;

Slice!(float*, 3) readLinear(string filePath)
{
    ImageRGBA8 image = convert!ImageRGBA8(loadImage(filePath));
    auto im = slice!float(image.height, image.width, 4);

    foreach (y; 0 .. image.height)
    {
        foreach (x; 0 .. image.width)
        {
            const auto index = (y * image.width + x) * 4;
            im[y, x, 0] = image.data()[index];
            im[y, x, 1] = image.data()[index + 1];
            im[y, x, 2] = image.data()[index + 2];
            im[y, x, 3] = image.data()[index + 3];
        }
    }

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

void save(immutable BoolMatrix boolMatrix, in string filename)
{
    import std.conv;

    ImageL8 result = new ImageL8(to!uint(boolMatrix.length!1), to!uint(boolMatrix.length!0));

    foreach (y; 0 .. result.height)
    {
        foreach (x; 0 .. result.width)
        {
            const auto index = (y * result.width + x);

            if (boolMatrix[y, x])
            {
                result.data()[index] = cast(ubyte)255;
            }
            else
            {
                result.data()[index] = cast(ubyte)0;
            }
        }
    }

    saveImage(result, filename);
}
