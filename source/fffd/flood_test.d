module fffd.flood_test;

version (unittest)
{
    import fffd.flood;
    import std.file;
    import mir.ndslice;

    bool folderExists(string name)
    {
        return exists(name) && isDir(name);
    }

    struct LoadFileResult
    {
        DirEntry file;
        DirEntry outputFile;
        size_t shapeHeight;
        size_t shapeWidth;
        long diffCount;
    }

    BoolMatrix readExpectedResult(string filePath)
    {
        import dlib.image;

        ImageL8 image = convert!ImageL8(loadImage(filePath));
        auto result = slice!bool(image.height, image.width);

        foreach (x; image.row)
        {
            foreach (y; image.col)
            {
                Color4 color4 = image.getPixel(x, y);
                result[y, x] = color4[0] > 128;
            }
        }

        return result.idup;
    }

    DirEntry[] sortedFiles(string folderName, string pattern)
    {
        import std.algorithm;
        import std.array;

        return dirEntries(folderName, pattern, SpanMode.shallow, false).filter!(a => a.isFile)
            .array
            .sort!((a, b) => a.name < b.name)
            .array;
    }

    LoadFileResult[] loadFolder(string folderName, float yThreshold, bool denoise = false)
    {
        import mir.math.sum : sum;
        import std.format;

        assert(folderExists(folderName));
        DirEntry[] inputList = sortedFiles(folderName, "*_orig.bmp");
        DirEntry[] outputList = sortedFiles(folderName, "*_fff.png");

        LoadFileResult[] diffList = [];

        foreach (i, inputImage; inputList)
        {
            Slice!(float*, 3) input = fffd.flood.readLinear(inputImage.name);
            BoolMatrix output = fffd.flood.filter(input, yThreshold, 4, 0.45, denoise);

            DirEntry expectedOutputFilename = outputList[i];
            BoolMatrix expectedOutput = readExpectedResult(expectedOutputFilename.name);

            assert(output.length == expectedOutput.length, format("Different shapes: %s, %s.",
                    inputImage.name, expectedOutputFilename.name));

            long diffCount = sum(output ^ expectedOutput);

            LoadFileResult diff = {
                file: inputImage,
                outputFile : expectedOutputFilename,
                shapeHeight : input.length!0,
                shapeWidth : input.length!1,
                diffCount : diffCount
            };

            diffList ~= diff;
        }

        return diffList;
    }

    unittest
    {
        import std.conv;
        import std.format;
        import std.stdio;

        LoadFileResult[] samples = loadFolder("samples", 0.092);

        {
            foreach (image; samples)
            {
                double diffPerCent = to!double(image.diffCount) / (image.shapeHeight * image.shapeWidth) * 100;
                assert(diffPerCent < (100 - 90), format("%s %s has %s different pixels (%s%%)",
                        image.file.name, image.outputFile.name, image.diffCount, diffPerCent));
            }

            writeln("Test - test_90: Ok.");
        }

    }
}
