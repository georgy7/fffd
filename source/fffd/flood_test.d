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

module fffd.flood_test;

version (unittest)
{
    import fffd.flood;
    import fffd.xyz;
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

    LoadFileResult[] loadSamples3()
    {
        import mir.math.sum : sum;
        import std.format;
        import std.path : buildPath;
        import std.file;

        const string folderName = "samples3";
        assert(folderExists(folderName));

        string[] inputList = ["xm50.bmp", "xm20.bmp"];
        string[] outputList = ["xm50_fff_denoise.png", "xm20_fff_denoise.png"];

        LoadFileResult[] diffList = [];

        foreach (i, inputImageFileName; inputList)
        {
            const string inputImagePath = buildPath(folderName, inputImageFileName);

            Slice!(float*, 3) input = fffd.flood.readLinear(inputImagePath);
            BoolMatrix output = fffd.flood.filter(input, 0.08, 4, 0.45, true);

            const string expectedOutputFilename = outputList[i];
            const string expectedOutputImagePath = buildPath(folderName, expectedOutputFilename);

            BoolMatrix expectedOutput = readExpectedResult(expectedOutputImagePath);

            assert(output.length == expectedOutput.length, format("Different shapes: %s, %s.",
            inputImageFileName, expectedOutputFilename));

            long diffCount = sum(output ^ expectedOutput);

            DirEntry inputFile = DirEntry(inputImagePath);
            DirEntry outputFile = DirEntry(expectedOutputImagePath);

            LoadFileResult diff = {
                file: inputFile,
                outputFile : outputFile,
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

        const LoadFileResult[] samples = loadFolder("samples", 0.092);

        {
            foreach (image; samples)
            {
                const double diffPerCent = to!double(image.diffCount) / (image.shapeHeight * image.shapeWidth) * 100;
                assert(diffPerCent < (100 - 90), format("%s %s has %s different pixels (%s%%)",
                        image.file.name, image.outputFile.name, image.diffCount, diffPerCent));
            }

            writeln("Test - test_90: Ok.");
        }

        {
            foreach (image; samples)
            {
                const double diffPerCent = to!double(image.diffCount) / (image.shapeHeight * image.shapeWidth) * 100;
                assert(diffPerCent < (100 - 99), format("%s %s has %s different pixels (%s%%)",
                image.file.name, image.outputFile.name, image.diffCount, diffPerCent));
            }

            writeln("Test - test_99: Ok.");
        }

        {
            foreach (image; samples)
            {
                const double diffPerCent = to!double(image.diffCount) / (image.shapeHeight * image.shapeWidth) * 100;
                assert(diffPerCent < (100 - 99.9), format("%s %s has %s different pixels (%s%%)",
                image.file.name, image.outputFile.name, image.diffCount, diffPerCent));
            }

            writeln("Test - test_999: Ok.");
        }

        {
            foreach (image; samples)
            {
                const double diffPerCent = to!double(image.diffCount) / (image.shapeHeight * image.shapeWidth) * 100;
                assert(0.0 == diffPerCent, format("%s %s has %s different pixels (%s%%)",
                image.file.name, image.outputFile.name, image.diffCount, diffPerCent));
            }

            writeln("Test - test_99_plus_one: Ok.");
        }

        {
            // test_2_q20
        }

        {
            // test_2_q40
        }

        {
            // test_2_q70
        }

        {
            // test_2_q100
        }

        {
            const LoadFileResult[] denoiseSamples = loadSamples3();

            foreach (image; denoiseSamples)
            {
                const double diffPerCent = to!double(image.diffCount) / (image.shapeHeight * image.shapeWidth) * 100;
                assert(0.0 == diffPerCent, format("%s %s has %s different pixels (%s%%)",
                image.file.name, image.outputFile.name, image.diffCount, diffPerCent));
            }

            writeln("Test - test_denoise: Ok.");
        }

    }
}
