module fffd.flood;

import mir.ndslice;
import dlib.image;
import fffd.linear_srgb_conv;
import fffd.xyz;
import fffd.bit_utils;
import fffd.adjacent_matrix_holder;

alias BoolMatrix = Slice!(immutable(bool)*, 2);

Slice!(float*, 3) readLinear(string filePath)
{
    ImageRGBA8 image = convert!ImageRGBA8(loadImage(filePath));
    auto im = slice!float(image.height, image.width, 4);

    foreach (x; image.row)
    {
        foreach (y; image.col)
        {
            Color4 color4 = image.getPixel(x, y);
            im[y, x, 0] = color4[0];
            im[y, x, 1] = color4[1];
            im[y, x, 2] = color4[2];
            im[y, x, 3] = color4[3];
        }
    }

    return toLinear(im);
}

private Slice!(T*, 2) zerosLike(T)(BoolMatrix source) @safe
{
    return slice!T(source.length!0, source.length!1);
}

private Slice!(float*, 2) toFloatMatrix(BoolMatrix matrix) @safe
{
    Slice!(float*, 2) result = zerosLike!float(matrix);
    result[] = matrix;
    return result;
}

private int lrtb(in int coordinate, in int size, in ubyte kernel_margin) @safe
{
    import std.algorithm;

    const int a = max(0, coordinate - kernel_margin);
    const int b = min(size - 1, coordinate + kernel_margin);
    return (1 + b - a);
}

private void filterChunk(in BitMap equalityMasks, in ubyte kernelMargin,
        in AdjacentMatrixHolder adjacencyMartixHolder, in float ratioThreshold,
        Slice!(bool*, 2) result) @safe
{
    import std.conv;

    immutable Bitmask originMask = adjacencyMartixHolder.getOriginMask();
    immutable Bitmask notOriginMask = adjacencyMartixHolder.getOriginMask().not();

    immutable int h = equalityMasks.getH();
    immutable int w = equalityMasks.getW();

    foreach (y; 0 .. h)
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
                    && previousFillingIterationResult.notZero())
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
        ubyte kernelMargin, float ratioThreshold, bool denoise) @safe
{
    Xyz originalImage = xyzFromLinearRgba(linearRgba);
    BoolMatrix firstPass = onePass(originalImage, yThreshold, kernelMargin, ratioThreshold);

    if (denoise)
    {
        Xyz firstPassXyz = new Xyz(toFloatMatrix(firstPass),
                zerosLike!float(firstPass), zerosLike!float(firstPass));
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

BoolMatrix onePass(Xyz xyz, float yThreshold, ubyte kernelMargin, float ratioThreshold) @safe
{
    assert(xyz !is null);

    assert(ratioThreshold > 0.0);
    assert(ratioThreshold < 1.0);

    const AdjacentMatrixHolder adjacencyMartixHolder = new AdjacentMatrixHolder(kernelMargin);

    const BitMap equalityMasks = xyz.makeEqualityMasks(kernelMargin,
            yThreshold, adjacencyMartixHolder.getOffsets());

    Slice!(bool*, 2) floodFillResult = slice!bool(xyz.length!0, xyz.length!1);

    /*
    h, w = original_image.h, original_image.w

    //worker_count = os.cpu_count()
    //if worker_count > 8:
    //    worker_count = worker_count - 2
    //elif worker_count > 4:
    //    worker_count = worker_count - 1

    //if single_thread:
    chunk_size = h;
    chunk_count = 1;
    //else:
    //    chunk_size = int(h / min(worker_count, h))
    //    chunk_count = math.ceil(h / chunk_size)

    input_rows = [
        (
            equality_masks[(chunk * chunk_size):(min(h, ((chunk + 1) * chunk_size)))].copy(),
            h, w,
            (chunk * chunk_size),
            (min(h, ((chunk + 1) * chunk_size))),
            kernel_margin,
            AdjacentMatrixHolder(0, adjacency_martix_holder),
            ratio_threshold
        )
        for chunk in range(chunk_count)
    ];

    //if single_thread:
    filled_rows = list(map(filter_chunk, input_rows));
*/

    filterChunk(equalityMasks, kernelMargin, adjacencyMartixHolder,
            ratioThreshold, floodFillResult);

    /*
    //else:
    //    pool = Pool(worker_count)
    //    filled_rows = pool.imap_unordered(filter_chunk, input_rows)
    //    pool.close()

    for filled_row in filled_rows:
        flood_fill_result[filled_row['min_y']:filled_row['max_y_exclusive'], :] = filled_row['array']
*/

    return floodFillResult.idup;
}

void save(immutable BoolMatrix boolMatrix, in string filename)
{
    import std.conv;

    ImageL8 result = new ImageL8(to!uint(boolMatrix.length!1), to!uint(boolMatrix.length!0));

    foreach (x; result.row)
    {
        foreach (y; result.col)
        {
            if (boolMatrix[y, x])
            {
                result.setPixel(Color4(255, 255, 255, 255), x, y);
            }
            else
            {
                result.setPixel(Color4(0, 0, 0, 255), x, y);
            }
        }
    }

    saveImage(result, filename);
}
